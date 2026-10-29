import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

String stuffStatusLabel(String status) {
  switch (status) {
    case 'low':
      return 'Low';
    case 'out_of_stock':
      return 'Out of Stock';
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
    default:
      return AppColors.forest;
  }
}

const _allStatuses = ['available', 'low', 'out_of_stock'];

class StuffItemRow extends StatelessWidget {
  const StuffItemRow({
    super.key,
    required this.item,
    required this.onStatusChange,
    this.onMenu,
    this.canEdit = true,
  });

  final StuffItem item;
  final ValueChanged<String> onStatusChange;
  final VoidCallback? onMenu;
  final bool canEdit;

  void _pickStatus(BuildContext context) {
    if (!canEdit) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (sheetContext) => SafeArea(
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
                  Navigator.pop(sheetContext);

                  if (status != item.itemStatus) {
                    onStatusChange(status);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = stuffStatusColor(item.itemStatus);

    return GestureDetector(
      onLongPress: canEdit ? onMenu : null,
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
                    style: AppText.body.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.itemDescription.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.itemDescription,
                      style: AppText.bodySoft,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: canEdit ? () => _pickStatus(context) : null,
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      stuffStatusLabel(item.itemStatus),
                      style: AppText.body.copyWith(
                        color: statusColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (canEdit)
                      Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: statusColor,
                      ),
                  ],
                ),
              ),
            ),
            if (onMenu != null && canEdit)
              IconButton(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.inkSoft,
                ),
                tooltip: 'Item options',
                onPressed: onMenu,
              ),
          ],
        ),
      ),
    );
  }
}