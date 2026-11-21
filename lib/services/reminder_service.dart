import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';

class ReminderService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  ReminderService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  void _validateID(String id) {
    if (id.isEmpty || id.contains('/')) {
      throw StateError('A valid document ID is required.');
    }
  }

  // Always use the signed-in user's private reminders.
  CollectionReference<Map<String, dynamic>> _reminders(
    String householdID,
  ) {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to access your reminders.');
    }

    _validateID(householdID);

    return _db
        .collection('households')
        .doc(householdID)
        .collection('members')
        .doc(user.uid)
        .collection('reminders');
  }

  void _validateDetails(Reminder reminder) {
    final title = reminder.reminderTitle.trim();

    if (title.isEmpty || title.length > 50) {
      throw StateError('Enter a title between 1 and 50 characters.');
    }

    if (reminder.reminderNotes.trim().length > 250) {
      throw StateError('Notes must be 250 characters or fewer.');
    }

    if (!['low', 'medium', 'high'].contains(reminder.reminderPriority)) {
      throw StateError('Choose Low, Medium, or High priority.');
    }
  }

  // Listen to the user's reminders.
  Stream<List<Reminder>> watchReminders(String householdID) {
    try {
      return _reminders(householdID).snapshots().map(
            (snapshot) => snapshot.docs
                .map((doc) => Reminder.fromMap(doc.id, doc.data()))
                .toList(),
          );
    } catch (error) {
      return Stream<List<Reminder>>.error(error);
    }
  }

  // Create an upcoming reminder.
  Future<void> createReminder({
    required String householdID,
    required Reminder reminder,
  }) async {
    _validateDetails(reminder);

    final data = reminder.toMap();
    data['reminderTitle'] = reminder.reminderTitle.trim();
    data['reminderNotes'] = reminder.reminderNotes.trim();
    data['reminderStatus'] = reminderUpcoming;

    await _reminders(householdID).add(data);
  }

  // Edit details without changing completion status.
  Future<void> updateReminder({
    required String householdID,
    required Reminder reminder,
  }) async {
    _validateID(reminder.reminderID);
    _validateDetails(reminder);

    await _reminders(householdID).doc(reminder.reminderID).update({
      'reminderTitle': reminder.reminderTitle.trim(),
      'reminderNotes': reminder.reminderNotes.trim(),
      'reminderDateTime': Timestamp.fromDate(reminder.reminderDateTime),
      'reminderPriority': reminder.reminderPriority,
    });
  }

  Future<void> markComplete({
    required String householdID,
    required String reminderID,
  }) async {
    _validateID(reminderID);

    await _reminders(householdID).doc(reminderID).update({
      'reminderStatus': reminderComplete,
    });
  }

  // Reopen only a completed reminder, using a future date and time.
  Future<void> reopenReminder({
    required String householdID,
    required String reminderID,
    required DateTime newDateTime,
  }) async {
    _validateID(reminderID);
    final reminderRef = _reminders(householdID).doc(reminderID);

    await _db.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(reminderRef);
      final data = snapshot.data();

      if (data == null) {
        throw StateError('This reminder no longer exists.');
      }

      if (data['reminderStatus'] != reminderComplete) {
        throw StateError('This reminder is already upcoming.');
      }

      if (!newDateTime.isAfter(DateTime.now())) {
        throw StateError('Choose a future date and time.');
      }

      transaction.update(reminderRef, {
        'reminderDateTime': Timestamp.fromDate(newDateTime),
        'reminderStatus': reminderUpcoming,
      });
    });
  }

  Future<void> deleteReminder({
    required String householdID,
    required String reminderID,
  }) async {
    _validateID(reminderID);
    await _reminders(householdID).doc(reminderID).delete();
  }
}