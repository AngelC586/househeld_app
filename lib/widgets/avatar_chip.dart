import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

const _avatarColors = [AppColors.mustard, AppColors.forest, AppColors.clay];

class AvatarChip extends StatelessWidget {
  final HouseholdMember member;
  final bool showLabel;
  final int colorSeed;

  const AvatarChip({
    super.key,
    required this.member,
    this.showLabel = true,
    this.colorSeed = 0,
  });

  String get _initial {
    final name = member.displayName.trim();

    if (name.isEmpty) return '?';

    return name[0].toUpperCase();
  }

  String get _roleLabel {
    switch (member.memberRole) {
      case 'manager':
        return 'Manager';
      case 'child':
        return 'Child';
      case 'member':
      default:
        return 'Member';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColors[colorSeed % _avatarColors.length];
    final avatar = CircleAvatar(
      radius: 14,
      backgroundColor: color,
      child: Text(
        _initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );

    if (!showLabel) return avatar;

    return Container(
      padding: const EdgeInsets.only(left: 4, right: 10, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          avatar,
          const SizedBox(width: 6),
          Text(
            '${member.displayName} · $_roleLabel',
            style: AppText.body.copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
