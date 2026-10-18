import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';

class TaskRowCard extends StatelessWidget {
  final HouseholdTask task;
  final VoidCallback onToggle;

  final VoidCallback? onMenu;

  const TaskRowCard({
    super.key,
    required this.task,
    required this.onToggle,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onMenu,
      child: Container(
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
                  // DATABASE.md's task schema has no due-date field — only
                  // who created it and (once done) who completed it. Shows
                  // the description if there is one, otherwise falls back
                  // to the creator's UID.
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
            if (onMenu != null)
              IconButton(
                icon: const Icon(Icons.more_vert, size: 20, color: AppColors.inkSoft),
                onPressed: onMenu,
                tooltip: 'Task options',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
      ),
    );
  }
}