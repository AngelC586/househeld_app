import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CelebrateCard extends StatelessWidget {
  const CelebrateCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'No pending tasks and nothing is out of stock.',
            style: AppText.bodySoft,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
