import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';

const _avatarColors = [
  AppColors.mustard,
  AppColors.forest,
  AppColors.clay,
];

class AvatarChip extends StatelessWidget {
  final DisplayMember member;
  final bool showLabel;


  final int colorSeed;

  const AvatarChip({
    super.key,
    required this.member,
    this.showLabel = true,
    this.colorSeed = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = _avatarColors[colorSeed % _avatarColors.length];
    final avatar = CircleAvatar(
      radius: 14,
      backgroundColor: color,
      child: Text(
        member.initial,
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
            '${member.profile.displayName} · ${member.membership.memberRole}',
            style: AppText.body.copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
