import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

class PantryRowCard extends StatelessWidget {
  const PantryRowCard({
    super.key,
    required this.item,
    required this.onQuantityTap,
    required this.onMenu,
  });

  final PantryItem item;
  final VoidCallback onQuantityTap;
  final VoidCallback onMenu;

  // UI for Pantry Item entries on the Pantry Screen:
  @override
  Widget build(BuildContext context) {
    final stockColor = item.isInStock ? AppColors.forest : AppColors.clay;

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.foodName,
                    style: AppText.body.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  if (item.foodDescription.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.foodDescription,
                      style: AppText.bodySoft,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 6),

                  Text(item.foodType, style: AppText.bodySoft),

                  const SizedBox(height: 6),

                  Text(
                    item.displayStockStatus,
                    style: AppText.body.copyWith(
                      color: stockColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            InkWell(
              onTap: onQuantityTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  item.displayQuantity,
                  style: AppText.heading.copyWith(fontSize: 18),
                ),
              ),
            ),

            IconButton(
              icon: const Icon(Icons.more_vert, color: AppColors.inkSoft),
              tooltip: 'Pantry item options',
              onPressed: onMenu,
            ),
          ],
        ),
      ),
    );
  }
}
