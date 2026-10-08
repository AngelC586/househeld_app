import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HouseheldBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const HouseheldBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    ('Home', Icons.home_outlined),
    ('Tasks', Icons.check_circle_outline),
    ('Food', Icons.set_meal_outlined),
    ('Personal', Icons.face_outlined),
    ('Grocery', Icons.list_alt_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 14, left: 4, right: 4),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (i) {
          final selected = i == currentIndex;
          final (label, icon) = _items[i];
          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? AppColors.forestDeep : AppColors.inkSoft,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.forestDeep : AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
