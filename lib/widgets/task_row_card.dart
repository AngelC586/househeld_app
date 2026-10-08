import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';

class TaskRowCard extends StatelessWidget {
  final HouseholdTask task;
  final VoidCallback onToggle;

  const TaskRowCard({super.key, required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: task.isCompleted ? AppColors.forest : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.forest, width: 2),
              ),
              child: task.isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.taskName,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: task.isCompleted ? AppColors.inkSoft : AppColors.ink,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  task.taskDescription.isNotEmpty
                      ? task.taskDescription
                      : 'Created by ${task.createdByMemberID}',
                  style: AppText.bodySoft,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
