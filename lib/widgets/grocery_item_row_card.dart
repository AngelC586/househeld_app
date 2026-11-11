import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

// UI for Grocery Item entries on the Grocery Items screen:
class GroceryItemRowCard extends StatelessWidget {
  const GroceryItemRowCard({
    super.key,
    required this.item,
    required this.onOptions,
    required this.onQuantity,
  });

  final GroceryItem item;
  final VoidCallback? onOptions;
  final VoidCallback? onQuantity;

  @override
  Widget build(BuildContext context) {
    final isPurchased = item.isPurchased;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPurchased ? AppColors.surfaceSunken : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: InkWell(
        onLongPress: onOptions,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Main Grocery Item information.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item name and linked-source indicator
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.groceryItemName,
                            style: AppText.body.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isPurchased
                                  ? AppColors.inkSoft
                                  : AppColors.ink,
                            ),
                          ),
                        ),

                        if (item.hasSource) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'Linked!',
                            child: Icon(
                              Icons.link,
                              size: 17,
                              color: AppColors.forest,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 5),

                    // Item category/type.
                    Text(item.groceryItemType, style: AppText.bodySoft),

                    // Optional description.
                    if (item.groceryItemDescription.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.groceryItemDescription,
                        style: AppText.bodySoft,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Purchased or Unpurchased status.
                    Text(
                      item.displayStatus,
                      style: AppText.body.copyWith(
                        color: isPurchased
                            ? AppColors.inkSoft
                            : AppColors.forest,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Quantity button
              TextButton(
                onPressed: isPurchased ? null : onQuantity,
                child: Text(
                  '${item.groceryItemQuantity}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: isPurchased ? AppColors.inkSoft : AppColors.forest,
                  ),
                ),
              ),

              // Grocery Item options
              if (onOptions != null)
                IconButton(
                  onPressed: onOptions,
                  tooltip: 'Grocery Item options',
                  icon: const Icon(Icons.more_vert, color: AppColors.inkSoft),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
