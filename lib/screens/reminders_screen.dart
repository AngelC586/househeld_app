import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/reminder_form_dialog.dart';
import '../widgets/reminder_row_card.dart';

enum _ReminderSortField { title, date, priority }

enum _SortDirection { asc, desc }

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  _ReminderSortField _sortField = _ReminderSortField.priority;
  _SortDirection _sortDirection = _SortDirection.asc;

  final List<Reminder> _reminders = [];


  int _compareTitles(Reminder a, Reminder b) =>
      a.reminderTitle.toLowerCase().compareTo(b.reminderTitle.toLowerCase());

  List<Reminder> _sorted(List<Reminder> items) {
    final sorted = [...items];

    switch (_sortField) {
      case _ReminderSortField.title:
        sorted.sort(_compareTitles);
        break;

      case _ReminderSortField.date:
        sorted.sort((a, b) {
          final byDate = a.reminderDateTime.compareTo(b.reminderDateTime);
          return byDate != 0 ? byDate : _compareTitles(a, b);
        });
        break;

      case _ReminderSortField.priority:
        sorted.sort((a, b) {
          final byPriority = a.priorityRank.compareTo(b.priorityRank);
          return byPriority != 0 ? byPriority : _compareTitles(a, b);
        });
        break;
    }

    return _sortDirection == _SortDirection.asc
        ? sorted
        : sorted.reversed.toList();
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

  // Create new reminder:
  Future<void> _openCreate() async {
    final result = await showReminderFormDialog(context);

    if (result == null) return;
  }

  // Edit existing reminder:
  Future<void> _openEdit(Reminder reminder) async {
    final result = await showReminderFormDialog(context, existing: reminder);

    if (result == null) return;
  }

  Future<void> _markComplete(Reminder reminder) async {
    final confirmed = await _confirm(
      'Confirm',
      'Are you sure you want to mark ${reminder.reminderTitle} as complete?',
    );

    if (!confirmed) return;
  }

  Future<void> _delete(Reminder reminder) async {
    final confirmed = await _confirm(
      'Confirm',
      'Are you sure you want to delete ${reminder.reminderTitle}?',
    );

    if (!confirmed) return;
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
    }
  }


  Widget _reminderList(List<Reminder> items, {required String emptyText}) {
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
          onPressed: _openCreate,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}