import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import 'reminder_row_card.dart';


Future<Reminder?> showReminderFormDialog(
  BuildContext context, {
  Reminder? existing,
}) {
  return showDialog<Reminder>(
    context: context,
    builder: (_) => _ReminderFormDialog(existing: existing),
  );
}

class _ReminderFormDialog extends StatefulWidget {
  const _ReminderFormDialog({this.existing});

  final Reminder? existing;

  @override
  State<_ReminderFormDialog> createState() => _ReminderFormDialogState();
}

class _ReminderFormDialogState extends State<_ReminderFormDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;

  DateTime? _date;
  TimeOfDay? _time;
  late String _priority;

  String? _titleError;
  String? _dateError;
  String? _timeError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _titleController = TextEditingController(
      text: existing?.reminderTitle ?? '',
    );
    _notesController = TextEditingController(
      text: existing?.reminderNotes ?? '',
    );

    final dateTime = existing?.reminderDateTime;
    _date = dateTime == null
        ? null
        : DateTime(dateTime.year, dateTime.month, dateTime.day);
    _time = dateTime == null ? null : TimeOfDay.fromDateTime(dateTime);

    _priority = existing?.reminderPriority ?? reminderPriorityMedium;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Calendar pop-up:
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final earliest = DateTime(now.year - 1);
    final current = _date ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: current.isBefore(earliest) ? current : earliest,
      lastDate: DateTime(now.year + 10),
    );

    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _dateError = null;
      });
    }
  }

  // Clock pop-up:
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      setState(() {
        _time = picked;
        _timeError = null;
      });
    }
  }

  void _save() {
    final title = _titleController.text.trim();

    setState(() {
      _titleError = title.isEmpty ? 'Please enter a title.' : null;
      _dateError = _date == null ? 'Please pick a date.' : null;
      _timeError = _time == null ? 'Please pick a time.' : null;
    });

    if (_titleError != null || _dateError != null || _timeError != null) {
      return;
    }

    final date = _date!;
    final time = _time!;

    Navigator.pop(
      context,
      Reminder(
        reminderID: widget.existing?.reminderID ?? '',
        reminderTitle: title,
        reminderNotes: _notesController.text.trim(),
        reminderDateTime: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
        reminderStatus: widget.existing?.reminderStatus ?? reminderUpcoming,
        reminderPriority: _priority,
      ),
    );
  }

  Widget _pickerField({
    required String label,
    required String? value,
    required IconData icon,
    required VoidCallback onTap,
    String? errorText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: errorText,
          suffixIcon: Icon(icon, color: AppColors.inkSoft),
        ),
        child: Text(
          value ?? 'Select',
          style: AppText.body.copyWith(
            color: value == null ? AppColors.inkSoft : AppColors.ink,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Reminder' : 'New Reminder'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                autofocus: !_isEditing,
                maxLength: reminderTitleMaxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: const OutlineInputBorder(),
                  errorText: _titleError,
                ),
                onChanged: (_) {
                  if (_titleError != null) {
                    setState(() => _titleError = null);
                  }
                },
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _notesController,
                maxLength: reminderNotesMaxLength,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 8),

              _pickerField(
                label: 'Date',
                value: _date == null ? null : formatReminderDate(_date!),
                icon: Icons.calendar_today_outlined,
                onTap: _pickDate,
                errorText: _dateError,
              ),

              const SizedBox(height: 14),

              _pickerField(
                label: 'Time',
                value: _time?.format(context),
                icon: Icons.access_time,
                onTap: _pickTime,
                errorText: _timeError,
              ),

              const SizedBox(height: 16),

              Text('PRIORITY', style: AppText.label),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    for (final priority in reminderPriorities)
                      ButtonSegment(
                        value: priority,
                        label: Text(
                          priority[0].toUpperCase() + priority.substring(1),
                        ),
                      ),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (selection) {
                    setState(() => _priority = selection.first);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}