import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/task_row_card.dart';
import '../widgets/househeld_bottom_nav.dart';
import 'task_form_screen.dart';

enum _SortField { title, assignee }

enum _SortDirection { asc, desc }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final String _currentUserRole = 'member';
  final String _currentUserID = 'u2';

  List<HouseholdTask> _tasks = [];

  _SortField _sortField = _SortField.title;
  _SortDirection _sortDirection = _SortDirection.asc;

  bool get _canCreateTasks =>
      _currentUserRole == 'manager' || _currentUserRole == 'member';

  List<HouseholdTask> _sorted(List<HouseholdTask> list) {
    final sorted = [...list];
    switch (_sortField) {
      case _SortField.title:
        sorted.sort((a, b) => a.taskName.toLowerCase().compareTo(b.taskName.toLowerCase()));
        break;
      case _SortField.assignee:
        sorted.sort((a, b) => a.createdByMemberID.compareTo(b.createdByMemberID));
        break;
    }
    return _sortDirection == _SortDirection.asc ? sorted : sorted.reversed.toList();
  }

  void _pickSort(_SortField field) {
    setState(() {
      if (_sortField == field) {
        _sortDirection =
            _sortDirection == _SortDirection.asc ? _SortDirection.desc : _SortDirection.asc;
      } else {
        _sortField = field;
        _sortDirection = _SortDirection.asc;
      }
    });
  }

  void _toggleTask(HouseholdTask task) {
    setState(() {
      final i = _tasks.indexWhere((t) => t.taskId == task.taskId);
      _tasks[i] = task.isCompleted
          ? task.copyWith(taskStatus: 'pending', completedByMemberID: null)
          : task.copyWith(taskStatus: 'completed', completedByMemberID: _currentUserID);
    });
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _openCreateTask() async {
    final result = await Navigator.push<HouseholdTask>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(currentUserID: _currentUserID),
      ),
    );
    if (result != null) {
      setState(() => _tasks.add(result));
    }
  }

  Future<void> _openEditTask(HouseholdTask task) async {
    final result = await Navigator.push<HouseholdTask>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(currentUserID: _currentUserID, existingTask: task),
      ),
    );
    if (result != null) {
      setState(() {
        final i = _tasks.indexWhere((t) => t.taskId == task.taskId);
        _tasks[i] = result;
      });
    }
  }

  void _showTaskMenu(HouseholdTask task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                task.isCompleted ? Icons.undo : Icons.check_circle_outline,
                color: AppColors.forest,
              ),
              title: Text(task.isCompleted ? 'Mark Incomplete' : 'Mark Completed'),
              onTap: () async {
                Navigator.pop(context); // close the sheet first
                final confirmed = await _confirm(
                  task.isCompleted ? 'Mark incomplete?' : 'Mark completed?',
                  task.isCompleted
                      ? 'This will move "${task.taskName}" back to pending.'
                      : 'This will mark "${task.taskName}" as done.',
                );
                if (confirmed) _toggleTask(task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.forest),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _openEditTask(task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.clay),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await _confirm(
                  'Delete this task?',
                  'This will permanently remove "${task.taskName}".',
                );
                if (confirmed) {
                  setState(() => _tasks.removeWhere((t) => t.taskId == task.taskId));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------
  // Tab contents
  // --------------------------------------------------------------------

  Widget _taskList(List<HouseholdTask> tasks, {required String emptyText}) {
    final sorted = _sorted(tasks);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(emptyText, style: AppText.bodySoft),
          )
        else
          ...sorted.map(
            (t) => TaskRowCard(
              task: t,
              onToggle: () => _toggleTask(t),
              onMenu: () => _showTaskMenu(t),
            ),
          ),
        if (!_canCreateTasks) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceSunken,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Text('Only Managers & Members can add tasks.', style: AppText.bodySoft),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = _tasks;
    // "Assigned" is approximated as "created by you" — same approximation
    // the Assignee sort uses, since there's no real assignee field yet.
    final assignedTasks = _tasks.where((t) => t.createdByMemberID == _currentUserID).toList();
    final finishedTasks = _tasks.where((t) => t.isCompleted).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Tasks & Chores'),
          actions: [
            PopupMenuButton<_SortField>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort',
              onSelected: _pickSort,
              itemBuilder: (context) => [
                 _sortMenuItem(_SortField.title, 'Title'),
                 _sortMenuItem(_SortField.assignee, 'Assignee'),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () {
                // TODO: wire up whatever the top-level menu should contain
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
        body: TabBarView(
          children: [
            _taskList(allTasks, emptyText: 'No tasks right now.'),
            _taskList(assignedTasks, emptyText: 'Nothing assigned to you.'),
            _taskList(finishedTasks, emptyText: 'Nothing finished yet.'),
          ],
        ),
        floatingActionButton: _canCreateTasks
            ? FloatingActionButton(
                backgroundColor: AppColors.clay,
                onPressed: _openCreateTask,
                child: const Icon(Icons.add, color: Colors.white),
              )
            : null,
        bottomNavigationBar: HouseheldBottomNav(
          currentIndex: 1,
          onTap: (i) {
            if (i == 1) return; // already on Tasks
            if (i == 0) {
              Navigator.pop(context); // back to Home
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
        style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }
}