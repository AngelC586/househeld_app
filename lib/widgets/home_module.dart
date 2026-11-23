import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// This widget is the template for all home screen modules

class HomeModule extends StatelessWidget {
  const HomeModule({
    super.key,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.onAdd,
    this.onViewAll,
    this.boxed = true,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final VoidCallback? onAdd;
  final VoidCallback? onViewAll;
  final bool boxed;

  static const double listHeight = 230;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 21,
                      color: AppColors.mustard,
                    ),
                    const SizedBox(width: 5),
                    Text(title, style: AppText.label),
                  ],
                ),
              ),
            ),
            const Spacer(),
            if (expanded && onAdd != null)
              IconButton(
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.forest,
                tooltip: 'Add to $title',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),

        if (expanded) ...[
          const SizedBox(height: 5),

          if (boxed)
            Container(
              height: listHeight,
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: child,
            )
          else
            child,

          if (onViewAll != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onViewAll,
                child: const Text('View All →'),
              ),
            ),
        ],
      ],
    );
  }
}
