import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import 'reminder_row_card.dart';

class RemindersHomeWindow extends StatelessWidget {
  const RemindersHomeWindow({
    super.key,
    required this.reminders,
    required this.onAdd,
    required this.onViewAll,
  });

  final List<Reminder> reminders;
  final VoidCallback onAdd;
  final VoidCallback onViewAll;

  static const double _listHeight = 230;

  @override
  Widget build(BuildContext context) {
    final sorted = sortRemindersByPriority(reminders);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('REMINDERS', style: AppText.label)),
            IconButton(
              onPressed: onAdd,
              icon: const Icon(Icons.add_circle_outline),
              color: AppColors.forest,
              tooltip: 'New reminder',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),

        const SizedBox(height: 4),

        Container(
          height: _listHeight,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: sorted.isEmpty
              ? Center(
                  child: Text('No upcoming reminders.', style: AppText.bodySoft),
                )
              : ListView(
                  padding: const EdgeInsets.all(10),
                  children: [
                    for (final reminder in sorted)
                      ReminderRowCard(reminder: reminder),
                  ],
                ),
        ),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onViewAll,
            child: const Text('View All →'),
          ),
        ),
      ],
    );
  }
}