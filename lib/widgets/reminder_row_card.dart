import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatReminderDate(DateTime date) {
  return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
}

String formatReminderDateTime(BuildContext context, DateTime dateTime) {
  final time = TimeOfDay.fromDateTime(dateTime).format(context);
  return '${formatReminderDate(dateTime)} at $time';
}

Color reminderPriorityColor(String priority) {
  switch (priority) {
    case reminderPriorityHigh:
      return AppColors.clay;
    case reminderPriorityMedium:
      return AppColors.mustard;
    default:
      return AppColors.forest;
  }
}

enum ReminderMenuAction { complete, reopen, edit, delete }

class ReminderRowCard extends StatelessWidget {
  const ReminderRowCard({
    super.key,
    required this.reminder,
    this.onMenuSelected,
  });

  final Reminder reminder;

  final ValueChanged<ReminderMenuAction>? onMenuSelected;

  @override
  Widget build(BuildContext context) {
    final priorityColor = reminderPriorityColor(reminder.reminderPriority);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.reminderTitle,
                  style: AppText.body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: reminder.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),

                if (reminder.reminderNotes.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    reminder.reminderNotes,
                    style: AppText.bodySoft,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 8),

                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.event_outlined,
                          size: 14,
                          color: AppColors.inkSoft,
                        ),
                        if (reminder.isOverdue)
                          const Text(
                            'Overdue',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(width: 4),
                        Text(
                          formatReminderDateTime(
                            context,
                            reminder.reminderDateTime,
                          ),
                          style: AppText.bodySoft,
                        ),
                      ],
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        reminder.displayPriority,
                        style: AppText.body.copyWith(
                          color: priorityColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (onMenuSelected != null)
            PopupMenuButton<ReminderMenuAction>(
              icon: const Icon(Icons.more_vert, color: AppColors.inkSoft),
              tooltip: 'Reminder options',
              onSelected: onMenuSelected,
              itemBuilder: (_) => [
                if (!reminder.isCompleted)
                  const PopupMenuItem(
                    value: ReminderMenuAction.complete,
                    child: Text('Mark as Complete'),
                  ),
                if (reminder.isCompleted)
                  const PopupMenuItem(
                    value: ReminderMenuAction.reopen,
                    child: Text('Reopen'),
                  ),
                const PopupMenuItem(
                  value: ReminderMenuAction.edit,
                  child: Text('Edit'),
                ),
                const PopupMenuItem(
                  value: ReminderMenuAction.delete,
                  child: Text('Delete'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
