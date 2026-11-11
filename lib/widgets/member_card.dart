import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

const _avatarColors = [AppColors.mustard, AppColors.forest, AppColors.clay];

String memberRoleLabel(String role) {
  switch (role) {
    case 'manager':
      return 'Manager';
    case 'child':
      return 'Child';
    case 'member':
    default:
      return 'Member';
  }
}

class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.member,
    this.onMenu,
    this.onChangeRole,
    this.colorSeed = 0,
  });

  final HouseholdMember member;
  final VoidCallback? onMenu;
  final VoidCallback? onChangeRole;
  final int colorSeed;

  @override
  Widget build(BuildContext context) {
    final defaultColor = _avatarColors[colorSeed % _avatarColors.length];

    final color = member.avatarColor == null
        ? defaultColor
        : Color(member.avatarColor!);

    final name = member.displayName.trim().isEmpty
        ? member.userID
        : member.displayName.trim();

    final customSymbol = member.avatarSymbol;

    final symbol = customSymbol != null && customSymbol.trim().isNotEmpty
        ? customSymbol
        : name[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color,
            child: Text(
              symbol,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  memberRoleLabel(member.memberRole),
                  style: AppText.bodySoft,
                ),

                if (onChangeRole != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onChangeRole,
                    child: const Text('Change Role'),
                  ),
                ],
              ],
            ),
          ),

          if (onMenu != null)
            IconButton(
              icon: const Icon(Icons.more_vert, color: AppColors.inkSoft),
              onPressed: onMenu,
              tooltip: 'Member options',
            ),
        ],
      ),
    );
  }
}
