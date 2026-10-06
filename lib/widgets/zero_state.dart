import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';

class CelebrateCard extends StatelessWidget {
  final int streakDays;
  final int tasksThisWeek;

  const CelebrateCard({
    super.key,
    required this.streakDays,
    required this.tasksThisWeek,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.okBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCFE0CE)),
          ),
          child: Column(
            children: [
              Text('All caught up', style: AppText.heading.copyWith(fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                'Nothing due today, and nothing running low.',
                style: AppText.bodySoft,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _StreakChip(number: '$streakDays', label: 'day streak'),
            const SizedBox(width: 10),
            _StreakChip(number: '$tasksThisWeek', label: 'tasks this week'),
          ],
        ),
      ],
    );
  }
}

class _StreakChip extends StatelessWidget {
  final String number;
  final String label;
  const _StreakChip({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Text(number, style: AppText.heading.copyWith(fontSize: 20)),
            const SizedBox(height: 2),
            Text(label, style: AppText.bodySoft.copyWith(fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}

class ActivityFeedRow extends StatelessWidget {
  final ActivityEntry entry;
  const ActivityFeedRow({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: entry.isRestock ? const Color(0xFFF3E9D6) : AppColors.okBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              entry.isRestock ? Icons.inventory_2_outlined : Icons.check,
              size: 14,
              color: entry.isRestock ? const Color(0xFF8A6A2C) : AppColors.forestDeep,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.text, style: AppText.body.copyWith(fontSize: 13)),
                Text(entry.time, style: AppText.bodySoft.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
