import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/household_service.dart';
import '../services/task_service.dart';
import '../theme/app_theme.dart';
import '../widgets/househeld_bottom_nav.dart';
import '../widgets/task_row_card.dart';
import 'task_form_screen.dart';

enum _SortField { title, assignee }

enum _SortDirection { asc, desc }

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.householdID,
  });

  final String householdID;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _householdService = HouseholdService();
  final _taskService = TaskService();

  StreamSubscription<List<HouseholdMember>>? _membersSubscription;
  StreamSubscription<List<HouseholdTask>>? _tasksSubscription;

  String _currentUserID = '';
  String _currentUserRole = '';

  List<HouseholdMember> _members = [];
  List<HouseholdTask> _tasks = [];

  bool _membersLoading = true;
  bool _tasksLoading = true;
  bool _busy = false;

  String? _membersError;
  String? _tasksError;

  // Ignore callbacks from an old task listener after a role change.
  int _taskListenerVersion = 0;

  _SortField _sortField = _SortField.title;
  _SortDirection _sortDirection = _SortDirection.asc;

  bool get _canManageTasks =>
      _currentUserRole == 'manager' || _currentUserRole == 'member';

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _membersLoading = false;
      _membersError = 'Please sign in to view household tasks.';
      return;
    }

    _currentUserID = user.uid;

    _membersSubscription = _householdService
        .watchMembers(widget.householdID)
        .listen(
          _receiveMembers,
          onError: (Object error) {
            if (!mounted) return;

            _stopTaskListener();

            setState(() {
              _membersLoading = false;
              _members = [];
              _currentUserRole = '';
              _membersError = 'Unable to load household members.';
            });
          },
        );
  }

  void _receiveMembers(List<HouseholdMember> members) {
    if (!mounted) return;

    HouseholdMember? currentMember;

    for (final member in members) {
      if (member.userID == _currentUserID) {
        currentMember = member;
        break;
      }
    }

    final role = currentMember?.memberRole;

    if (!['manager', 'member', 'child'].contains(role)) {
      _stopTaskListener();

      setState(() {
        _membersLoading = false;
        _members = [];
        _currentUserRole = '';
        _membersError = 'Your household membership could not be verified.';
      });
      return;
    }

    final roleChanged = role != _currentUserRole;

    setState(() {
      _membersLoading = false;
      _membersError = null;
      _members = members;
      _currentUserRole = role!;
    });

    if (roleChanged || _tasksSubscription == null) {
      _listenToTasks();
    }
  }

  void _stopTaskListener() {
    _taskListenerVersion++;
    _tasksSubscription?.cancel();
    _tasksSubscription = null;
    _tasks = [];
  }

  void _listenToTasks() {
    _stopTaskListener();
    final version = _taskListenerVersion;

    setState(() {
      _tasksLoading = true;
      _tasksError = null;
    });

    _tasksSubscription = _taskService
        .watchTasks(
          householdID: widget.householdID,
          memberRole: _currentUserRole,
        )
        .listen(
          (tasks) {
            if (!mounted || version != _taskListenerVersion) return;

            setState(() {
              _tasks = tasks;
              _tasksLoading = false;
              _tasksError = null;
            });
          },
          onError: (Object error) {
            if (!mounted || version != _taskListenerVersion) return;

            setState(() {
              _tasks = [];
              _tasksLoading = false;
              _tasksError =
                  'Unable to load tasks. Check your connection and '
                  'the published task rules.';
            });
          },
        );
  }

  @override
  void dispose() {
    _membersSubscription?.cancel();
    _tasksSubscription?.cancel();
    super.dispose();
  }

  String _memberName(String memberID) {
    for (final member in _members) {
      if (member.userID == memberID) {
        return member.displayName.trim().isEmpty
            ? 'Member ($memberID)'
            : member.displayName;
      }
    }

    return 'Unavailable member ($memberID)';
  }

  String _assignmentLabel(HouseholdTask task) {
    if (task.isAssignedToAnyone) return 'Anyone';

    final names = task.taskAssignedMemberIDs.map(_memberName).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return names.join(', ');
  }

  List<HouseholdTask> _sorted(List<HouseholdTask> tasks) {
    final sorted = [...tasks];

    sorted.sort((a, b) {
      final left = _sortField == _SortField.title
          ? a.taskName
          : _assignmentLabel(a);
      final right = _sortField == _SortField.title
          ? b.taskName
          : _assignmentLabel(b);

      final comparison = left.toLowerCase().compareTo(right.toLowerCase());

      return comparison != 0
          ? comparison
          : a.taskId.compareTo(b.taskId);
    });

    return _sortDirection == _SortDirection.asc
        ? sorted
        : sorted.reversed.toList();
  }

  void _pickSort(_SortField field) {
    setState(() {
      if (_sortField == field) {
        _sortDirection = _sortDirection == _SortDirection.asc
            ? _SortDirection.desc
            : _SortDirection.asc;
      } else {
        _sortField = field;
        _sortDirection = _SortDirection.asc;
      }
    });
  }

  // Prevent repeated actions and display saving errors.
  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      if (FirebaseAuth.instance.currentUser?.uid != _currentUserID) {
        throw StateError('Your sign-in changed. Please reopen Tasks.');
      }

      await action();
    } catch (error) {
      if (!mounted) return;

      final message = error is StateError
          ? error.message.toString()
          : 'The action could not be completed. '
              'Check your connection and try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _openCreateTask() async {
    if (!_canManageTasks) return;

    await _runAction(() async {
      final result = await Navigator.push<HouseholdTask>(
        context,
        MaterialPageRoute(
          builder: (_) => TaskFormScreen(
            currentUserID: _currentUserID,
            members: _members,
          ),
        ),
      );

      if (!mounted || result == null) return;

      await _taskService.createTask(
        householdID: widget.householdID,
        name: result.taskName,
        description: result.taskDescription,
        assignedMemberIDs: result.taskAssignedMemberIDs,
      );
    });
  }

  Future<void> _openEditTask(HouseholdTask task) async {
    if (!_canManageTasks) return;

    await _runAction(() async {
      final result = await Navigator.push<HouseholdTask>(
        context,
        MaterialPageRoute(
          builder: (_) => TaskFormScreen(
            currentUserID: _currentUserID,
            existingTask: task,
            members: _members,
          ),
        ),
      );

      if (!mounted || result == null) return;

      await _taskService.updateTask(
        householdID: widget.householdID,
        taskID: task.taskId,
        name: result.taskName,
        description: result.taskDescription,
        assignedMemberIDs: task.canChangeAssignees(_currentUserID)
            ? result.taskAssignedMemberIDs
            : null,
      );
    });
  }

  Future<void> _completeTask(HouseholdTask task) async {
    if (!task.canComplete(_currentUserID)) return;

    await _runAction(() async {
      final confirmed = await _confirm(
        'Mark completed?',
        'This will mark "${task.taskName}" as done for everyone.',
      );

      if (!mounted || !confirmed) return;

      await _taskService.completeTask(
        householdID: widget.householdID,
        taskID: task.taskId,
      );
    });
  }

  Future<void> _deleteTask(HouseholdTask task) async {
    if (!_canManageTasks) return;

    await _runAction(() async {
      final confirmed = await _confirm(
        'Delete this task?',
        'This will permanently remove "${task.taskName}".',
      );

      if (!mounted || !confirmed) return;

      await _taskService.deleteTask(
        householdID: widget.householdID,
        taskID: task.taskId,
      );
    });
  }

  void _showTaskMenu(HouseholdTask task) {
    if (_busy) return;

    final canComplete = task.canComplete(_currentUserID);
    if (!canComplete && !_canManageTasks) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canComplete)
              ListTile(
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.forest,
                ),
                title: const Text('Mark Completed'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _completeTask(task);
                },
              ),
            if (_canManageTasks) ...[
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.forest,
                ),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openEditTask(task);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.clay,
                ),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteTask(task);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _taskList(List<HouseholdTask> tasks, {required String emptyText}) {
    final sorted = _sorted(tasks);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(emptyText, style: AppText.bodySoft),
          ),
        for (final task in sorted) ...[
          TaskRowCard(
            task: task,
            creatorName: _members
              .where((member) => member.userID == task.createdByMemberID)
              .map((member) => member.displayName.trim())
              .where((name) => name.isNotEmpty)
              .firstOrNull,
            onToggle: () => _completeTask(task),
            onMenu: () => _showTaskMenu(task),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Assigned to: ${_assignmentLabel(task)}',
              style: AppText.bodySoft,
            ),
          ),
        ],
        if (!_canManageTasks)
          Text(
            'Only Managers & Members can create, edit, or delete tasks.',
            style: AppText.bodySoft,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_membersLoading || _membersError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tasks & Chores')),
        body: Center(
          child: _membersLoading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '$_membersError\nGo back and reopen Tasks to try again.',
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      );
    }

    // "Assigned" means explicitly assigned to the signed-in member.
    // Anyone tasks remain available in "All Tasks".
    final assignedTasks = _tasks
        .where((task) => task.isAssignedTo(_currentUserID))
        .toList();
    final finishedTasks = _tasks.where((task) => task.isCompleted).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          title: const Text('Tasks & Chores'),
          actions: [
            PopupMenuButton<_SortField>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort',
              onSelected: _pickSort,
              itemBuilder: (_) => [
                _sortMenuItem(_SortField.title, 'Title'),
                _sortMenuItem(_SortField.assignee, 'Assignee'),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Menu — not built yet')),
                );
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFC7D4C9),
            tabs: [
              Tab(text: 'All Tasks'),
              Tab(text: 'Assigned'),
              Tab(text: 'Finished'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            Expanded(
              child: _tasksLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _tasksError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _tasksError!,
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: _listenToTasks,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : TabBarView(
                          children: [
                            _taskList(
                              _tasks,
                              emptyText: 'No tasks right now.',
                            ),
                            _taskList(
                              assignedTasks,
                              emptyText: 'Nothing assigned to you.',
                            ),
                            _taskList(
                              finishedTasks,
                              emptyText: 'Nothing finished yet.',
                            ),
                          ],
                        ),
            ),
          ],
        ),
        floatingActionButton: _canManageTasks &&
                !_tasksLoading &&
                _tasksError == null
            ? FloatingActionButton(
                backgroundColor: AppColors.clay,
                onPressed: _busy ? null : _openCreateTask,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
        bottomNavigationBar: HouseheldBottomNav(
          currentIndex: 1,
          onTap: (i) {
            if (i == 1) return;
            if (i == 0) {
              Navigator.pop(context);
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon')),
            );
          },
        ),
      ),
    );
  }

  PopupMenuItem<_SortField> _sortMenuItem(_SortField field, String label) {
    final isActive = _sortField == field;
    final arrow = !isActive
        ? ''
        : (_sortDirection == _SortDirection.asc ? ' ↑' : ' ↓');

    return PopupMenuItem(
      value: field,
      child: Text(
        '$label$arrow',
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}