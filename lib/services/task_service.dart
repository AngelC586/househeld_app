import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

class TaskService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  TaskService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  Future<String> createTask({
    required String householdID,
    required String name,
    String description = '',
    List<String> assignedMemberIDs = const [],
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in before creating a task.');
    }

    if (householdID.isEmpty || householdID.contains('/')) {
      throw StateError('A valid household ID is required.');
    }

    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw StateError('Please enter a task name.');
    }

    if (trimmedName.length > 200) {
      throw StateError('Task names cannot exceed 200 characters.');
    }

    //Remove duplicate selections.
    final assignees = assignedMemberIDs.toSet().toList();

    if (assignees.length > 8) {
      throw StateError('You can assign a task to up to 8 people.');
    }

    if (assignees.any((id) => id.isEmpty || id.contains('/'))) {
      throw StateError('An assigned member ID is invalid.');
    }

    final householdRef = _db.collection('households').doc(householdID);
    final memberRef = householdRef.collection('members').doc(user.uid);

    // Firestore generatess the task's unique document ID
    final taskRef = householdRef.collection('tasks').doc();

    final task = HouseholdTask(
      taskId: taskRef.id,
      taskName: trimmedName,
      taskDescription: description.trim(),
      taskStatus: 'pending',
      createdByMemberID: user.uid,
      taskAssignedMemberIDs: assignees,
    );

    await _db.runTransaction<void>((transaction) async {
      final memberDocument = await transaction.get(memberRef);
      final membership = memberDocument.data();

      if (membership == null) {
        throw StateError('You are not a member of this household.');
      }

      final role = membership['memberRole'];

      if (role != 'manager' && role != 'member') {
        throw StateError('Only Managers and Members can create tasks.');
      }

      // Confirm every selected person belongs to this household.
      // All reads happen before the write
      for (final memberID in assignees) {
        final assignedMember = await transaction.get(
          householdRef.collection('members').doc(memberID),
        );

        if (!assignedMember.exists) {
          throw StateError(
            'A selected person is no longer in this household. '
            'Please refresh the page and try again.',
          );
        }
      }

      transaction.set(taskRef, task.toCreateMap());
    });

    return taskRef.id;
  }

  Stream<List<HouseholdTask>> watchTasks({
    required String householdID,
    required String memberRole,
  }) {
    final user = _auth.currentUser;

    if (user == null) {
      return Stream<List<HouseholdTask>>.error(
        StateError('Please sign in before viewing tasks.'),
      );
    }

    if (householdID.isEmpty || householdID.contains('/')) {
      return Stream<List<HouseholdTask>>.error(
        StateError('A valid household ID is required.'),
      );
    }

    if (!['manager', 'member', 'child'].contains(memberRole)) {
      return Stream<List<HouseholdTask>>.error(
        StateError('A valid member role is required.'),
      );
    }

    Query<Map<String, dynamic>> query = _db
        .collection('households')
        .doc(householdID)
        .collection('tasks');

    // Managers can view every task in their household.
    // Other members can view Anyone tasks, their own tasks, and tasks assigned to them.
    if (memberRole != 'manager') {
      query = query.where(
        Filter.or(
          Filter('taskAssignedMemberIDs', isEqualTo: <String>[]),
          Filter('createdByMemberID', isEqualTo: user.uid),
          Filter('taskAssignedMemberIDs', arrayContains: user.uid),
        ),
      );
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (document) => HouseholdTask.fromMap(document.id, document.data()),
          )
          .toList(),
    );
  }

  Future<void> completeTask({
    required String householdID,
    required String taskID,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in before completing a task');
    }

    if (householdID.isEmpty || householdID.contains('/')) {
      throw StateError('A valid household ID is required.');
    }

    if (taskID.isEmpty || taskID.contains('/')) {
      throw StateError('A valid task ID is required.');
    }

    final householdRef = _db.collection('households').doc(householdID);
    final memberRef = householdRef.collection('members').doc(user.uid);
    final taskRef = householdRef.collection('tasks').doc(taskID);

    await _db.runTransaction<void>((transaction) async {
      final memberDocument = await transaction.get(memberRef);

      if (!memberDocument.exists) {
        throw StateError('You do not belong to this household.');
      }

      final taskDocument = await transaction.get(taskRef);
      final taskData = taskDocument.data();

      if (taskData == null) {
        throw StateError('This task no longer exists.');
      }

      final task = HouseholdTask.fromMap(taskDocument.id, taskData);

      if (task.isCompleted) {
        throw StateError('This task has already been completed.');
      }

      if (task.taskStatus != 'pending') {
        throw StateError('This task cannot be completed in its current state.');
      }

      if (!task.canComplete(user.uid)) {
        throw StateError(
          'Only a person assigned to this task can complete it.',
        );
      }

      transaction.update(taskRef, {
        'taskStatus': 'completed',
        'completedByMemberID': user.uid,
        'taskCompletionTime': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateTask({
    required String householdID,
    required String taskID,
    required String name,
    required String description,
    List<String>? assignedMemberIDs,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in before editing a task.');
    }

    if (householdID.isEmpty || householdID.contains('/')) {
      throw StateError('A valid household ID is required.');
    }

    if (taskID.isEmpty || taskID.contains('/')) {
      throw StateError('A valid task ID is required.');
    }

    final trimmedName = name.trim();

    if (trimmedName.isEmpty || trimmedName.length > 200) {
      throw StateError('Task names must be between 1 and 200 characters.');
    }

    // Null means keep the current assignment.
    // An empty list means change the assignment to Anyone.
    final assignees = assignedMemberIDs?.toSet().toList();

    if (assignees != null && assignees.length > 8) {
      throw StateError('You can assign a task to up to 8 people.');
    }

    if (assignees != null &&
        assignees.any((id) => id.isEmpty || id.contains('/'))) {
      throw StateError('An assigned member ID is invalid.');
    }

    final householdRef = _db.collection('households').doc(householdID);
    final memberRef = householdRef.collection('members').doc(user.uid);
    final taskRef = householdRef.collection('tasks').doc(taskID);

    await _db.runTransaction<void>((transaction) async {
      final memberDocument = await transaction.get(memberRef);
      final membership = memberDocument.data();

      if (membership == null) {
        throw StateError('You do not belong to this household.');
      }

      final role = membership['memberRole'];

      if (role != 'manager' && role != 'member') {
        throw StateError('Only Managers and Members can edit tasks.');
      }

      final taskDocument = await transaction.get(taskRef);
      final taskData = taskDocument.data();

      if (taskData == null) {
        throw StateError('This task no longer exists.');
      }

      final task = HouseholdTask.fromMap(taskDocument.id, taskData);

      if (!task.canView(memberID: user.uid, memberRole: role as String)) {
        throw StateError('You do not have access to this task.');
      }

      final currentAssignees = task.taskAssignedMemberIDs.toSet();

      final assignmentChanged =
          assignees != null &&
          (assignees.length != currentAssignees.length ||
              !currentAssignees.containsAll(assignees));

      if (assignmentChanged) {
        if (!task.canChangeAssignees(user.uid)) {
          throw StateError(
            'Only the creator can change who is assigned to this task.',
          );
        }

        for (final memberID in assignees) {
          final assignedMember = await transaction.get(
            householdRef.collection('members').doc(memberID),
          );

          if (!assignedMember.exists) {
            throw StateError(
              'A selected person is no longer in this household. '
              'Please refresh your selections.',
            );
          }
        }
      }

      transaction.update(taskRef, {
        'taskName': trimmedName,
        'taskDescription': description.trim(),
        if (assignmentChanged) 'taskAssignedMemberIDs': assignees,
      });
    });
  }

  Future<void> deleteTask({
    required String householdID,
    required String taskID,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in before deleting a task.');
    }

    if (householdID.isEmpty || householdID.contains('/')) {
      throw StateError('A valid household ID is required.');
    }

    if (taskID.isEmpty || taskID.contains('/')) {
      throw StateError('A valid task ID is required.');
    }

    final householdRef = _db.collection('households').doc(householdID);
    final memberRef = householdRef.collection('members').doc(user.uid);
    final taskRef = householdRef.collection('tasks').doc(taskID);

    await _db.runTransaction<void>((transaction) async {
      final memberDocument = await transaction.get(memberRef);
      final membership = memberDocument.data();

      if (membership == null) {
        throw StateError('You do not belong to this household.');
      }

      final role = membership['memberRole'];

      if (role != 'manager' && role != 'member') {
        throw StateError('Only Managers and Members can delete tasks.');
      }

      final taskDocument = await transaction.get(taskRef);
      final taskData = taskDocument.data();

      if (taskData == null) {
        throw StateError('This task no longer exists.');
      }

      final task = HouseholdTask.fromMap(taskDocument.id, taskData);

      if (!task.canView(memberID: user.uid, memberRole: role as String)) {
        throw StateError('You do not have access to this task.');
      }

      transaction.delete(taskRef);
    });
  }
}
