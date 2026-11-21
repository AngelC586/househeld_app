import 'package:flutter/material.dart';

import 'dart:async';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/reminder_form_dialog.dart';
import '../widgets/reminder_row_card.dart';
import '../services/reminder_service.dart';

enum _ReminderSortField { title, date, priority }

enum _SortDirection { asc, desc }

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, required this.householdID});

  final String householdID;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  _ReminderSortField _sortField = _ReminderSortField.priority;
  _SortDirection _sortDirection = _SortDirection.asc;

  final List<Reminder> _reminders = [];

  final ReminderService _service = ReminderService();
  StreamSubscription<List<Reminder>>? _reminderSubscription;
  Timer? _overdueTimer;

  bool _loading = true;
  String? _loadError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _reminderSubscription = _service
        .watchReminders(widget.householdID)
        .listen(
          (reminders) {
            if (!mounted) return;

            setState(() {
              _reminders
                ..clear()
                ..addAll(reminders);
              _loading = false;
              _loadError = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;

            setState(() {
              _loading = false;
              _loadError = 'Unable to load your reminders. Please try again.';
            });
          },
        );

    _overdueTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _reminderSubscription?.cancel();
    _overdueTimer?.cancel();
    super.dispose();
  }

  int _compareTitles(Reminder a, Reminder b) =>
      a.reminderTitle.toLowerCase().compareTo(b.reminderTitle.toLowerCase());

  List<Reminder> _sorted(List<Reminder> items) {
    final sorted = [...items];
    final now = DateTime.now();

    sorted.sort((a, b) {
      final aOverdue = !a.isCompleted && a.reminderDateTime.isBefore(now);
      final bOverdue = !b.isCompleted && b.reminderDateTime.isBefore(now);

      // Overdue reminders stay first in either sort direction.
      if (aOverdue != bOverdue) {
        return aOverdue ? -1 : 1;
      }

      int comparison;

      switch (_sortField) {
        case _ReminderSortField.title:
          comparison = _compareTitles(a, b);
          break;

        case _ReminderSortField.date:
          comparison = a.reminderDateTime.compareTo(b.reminderDateTime);
          break;

        case _ReminderSortField.priority:
          comparison = a.priorityRank.compareTo(b.priorityRank);
          break;
      }

      if (comparison != 0) {
        return _sortDirection == _SortDirection.asc ? comparison : -comparison;
      }

      // Keep equal dates or priorities alphabetical.
      final byTitle = _compareTitles(a, b);
      if (byTitle != 0) return byTitle;

      return a.reminderID.compareTo(b.reminderID);
    });

    return sorted;
  }

  void _pickSort(_ReminderSortField field) {
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
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (!mounted || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      await action();
    } catch (error) {
      debugPrint('Reminder action failed: $error');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'Unable to save your changes. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // Create new reminder:
  Future<void> _openCreate() async {
    if (_isSaving) return;

    final result = await showReminderFormDialog(context);
    if (!mounted || result == null) return;

    await _runAction(
      () => _service.createReminder(
        householdID: widget.householdID,
        reminder: result,
      ),
    );
  }

  // Edit existing reminder:
  Future<void> _openEdit(Reminder reminder) async {
    if (_isSaving) return;

    final result = await showReminderFormDialog(context, existing: reminder);
    if (!mounted || result == null) return;

    await _runAction(
      () => _service.updateReminder(
        householdID: widget.householdID,
        reminder: result,
      ),
    );
  }

  Future<void> _markComplete(Reminder reminder) async {
    if (_isSaving) return;

    final confirmed = await _confirm(
      'Confirm',
      'Are you sure you want to mark ${reminder.reminderTitle} as complete?',
    );
    if (!mounted || !confirmed) return;

    await _runAction(
      () => _service.markComplete(
        householdID: widget.householdID,
        reminderID: reminder.reminderID,
      ),
    );
  }

  Future<void> _delete(Reminder reminder) async {
    if (_isSaving) return;

    final confirmed = await _confirm(
      'Confirm',
      'Are you sure you want to delete ${reminder.reminderTitle}?',
    );
    if (!mounted || !confirmed) return;

    await _runAction(
      () => _service.deleteReminder(
        householdID: widget.householdID,
        reminderID: reminder.reminderID,
      ),
    );
  }

  Future<void> _reopen(Reminder reminder) async {
    if (_isSaving) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final date = await showDatePicker(
      context: context,
      helpText: 'Choose a new reminder date',
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(now.year + 10, 12, 31),
    );

    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      helpText: 'Choose a new reminder time',
      initialTime: TimeOfDay.fromDateTime(
        DateTime.now().add(const Duration(hours: 1)),
      ),
    );

    if (!mounted || time == null) return;

    final newDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!newDateTime.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a future date and time.')),
      );
      return;
    }

    await _runAction(
      () => _service.reopenReminder(
        householdID: widget.householdID,
        reminderID: reminder.reminderID,
        newDateTime: newDateTime,
      ),
    );
  }

  void _handleMenu(Reminder reminder, ReminderMenuAction action) {
    switch (action) {
      case ReminderMenuAction.complete:
        _markComplete(reminder);
        break;
      case ReminderMenuAction.edit:
        _openEdit(reminder);
        break;
      case ReminderMenuAction.delete:
        _delete(reminder);
        break;
      case ReminderMenuAction.reopen:
        _reopen(reminder);
        break;
    }
  }

  Widget _reminderList(List<Reminder> items, {required String emptyText}) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: AppText.bodySoft,
          ),
        ),
      );
    }

    final sorted = _sorted(items);

    if (sorted.isEmpty) {
      return Center(child: Text(emptyText, style: AppText.bodySoft));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        for (final reminder in sorted)
          ReminderRowCard(
            reminder: reminder,
            onMenuSelected: (action) => _handleMenu(reminder, action),
          ),
      ],
    );
  }

  PopupMenuItem<_ReminderSortField> _sortMenuItem(
    _ReminderSortField field,
    String label,
  ) {
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

  @override
  Widget build(BuildContext context) {
    final upcoming = _reminders.where((r) => !r.isCompleted).toList();
    final completed = _reminders.where((r) => r.isCompleted).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          title: const Text('Reminders'),
          actions: [
            PopupMenuButton<_ReminderSortField>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort',
              onSelected: _pickSort,
              itemBuilder: (_) => [
                _sortMenuItem(_ReminderSortField.title, 'Title'),
                _sortMenuItem(_ReminderSortField.date, 'Date'),
                _sortMenuItem(_ReminderSortField.priority, 'Priority'),
              ],
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFC7D4C9),
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
            ],
          ),
        ),

        body: TabBarView(
          children: [
            _reminderList(upcoming, emptyText: 'No upcoming reminders.'),
            _reminderList(completed, emptyText: 'No completed reminders yet.'),
          ],
        ),

        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.clay,
          onPressed: _isSaving ? null : _openCreate,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
