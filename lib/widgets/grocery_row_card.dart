import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

// UI for Grocery Lists entries on the Grocery Lists Screen:
class GroceryRowCard extends StatelessWidget {
  const GroceryRowCard({
    super.key,
    required this.list,
    required this.itemCount,
    required this.onViewItems,
    this.onShop,
    required this.onMenu,
  });

  final GroceryList list;
  final int itemCount;
  final VoidCallback onViewItems;
  final VoidCallback? onShop;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onMenu,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (list.isDefault) ...[
                  const Icon(Icons.home_outlined, color: AppColors.forest),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    list.groceryListName,
                    style: AppText.heading.copyWith(fontSize: 18),
                  ),
                ),
                if (onMenu != null) 
                  IconButton(
                    onPressed: onMenu,
                    tooltip: 'Grocery List options',
                    icon: const Icon(Icons.more_vert),
                  ),
              ],
            ),
            if (list.groceryListDescription.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(list.groceryListDescription, style: AppText.bodySoft),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              children: [
                Text(
                  list.isComplete ? 'Complete' : 'Incomplete',
                  style: AppText.body.copyWith(
                    color: list.isComplete ? AppColors.forest : AppColors.clay,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text('Items: $itemCount', style: AppText.bodySoft),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onViewItems,
                    child: const Text('View Items'),
                  ),
                ),
                if (!list.isComplete && onShop != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onShop,
                      child: const Text('Shop This List'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
