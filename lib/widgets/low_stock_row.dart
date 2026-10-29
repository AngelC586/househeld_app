import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

class LowStockRow extends StatelessWidget {
  final String name;
  final String category;
  final VoidCallback onOpen;

  LowStockRow({super.key, required PantryItem item, required this.onOpen})
      : name = item.foodName,
        category = item.foodType;

  LowStockRow.stuff({super.key, required StuffItem item, required this.onOpen})
      : name = item.itemName,
        category = item.isPrivate ? 'Personal' : 'Household';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$category · out of stock',
                  style: AppText.bodySoft,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onOpen,
            style: TextButton.styleFrom(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: const BorderSide(color: AppColors.line),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(
              'View →',
              style: AppText.body.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
