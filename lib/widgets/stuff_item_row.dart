import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

String stuffStatusLabel(String status) {
  switch (status) {
    case 'low':
      return 'Low';
    case 'out_of_stock':
      return 'Out of Stock';
    case 'available':
    default:
      return 'Available';
  }
}

Color stuffStatusColor(String status) {
  switch (status) {
    case 'low':
      return AppColors.mustard;
    case 'out_of_stock':
      return AppColors.clay;
    case 'available':
    default:
      return AppColors.forest;
  }
}

const _allStatuses = ['available', 'low', 'out_of_stock'];

class StuffItemRow extends StatelessWidget {
  final StuffItem item;

  /// Tapping the status chip opens a picker; selecting one calls this.
  final ValueChanged<String> onStatusChange;

  /// Optional: three-dot button + long-press, same pattern as TaskRowCard.
  final VoidCallback? onMenu;

  const StuffItemRow({
    super.key,
    required this.item,
    required this.onStatusChange,
    this.onMenu,
  });

  void _pickStatus(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final status in _allStatuses)
              ListTile(
                leading: Icon(
                  Icons.circle,
                  size: 12,
                  color: stuffStatusColor(status),
                ),
                title: Text(stuffStatusLabel(status)),
                trailing: item.itemStatus == status
                    ? const Icon(Icons.check, color: AppColors.forest)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  onStatusChange(status);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = stuffStatusColor(item.itemStatus);
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
                    item.itemName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  if (item.itemDescription.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.itemDescription,
                      style: AppText.bodySoft,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _pickStatus(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stuffStatusLabel(item.itemStatus),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 16, color: color),
                  ],
                ),
              ),
            ),
            if (onMenu != null)
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  size: 20,
                  color: AppColors.inkSoft,
                ),
                onPressed: onMenu,
                tooltip: 'Item options',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
      ),
    );
  }
}
