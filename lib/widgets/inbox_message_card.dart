import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';

String formatMessageTime(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${months[dt.month - 1]} ${dt.day}, $hour12:$minute $ampm';
}

class InboxMessageCard extends StatelessWidget {
  final InboxMessage message;
  final String sentByName;
  final String sentToNames; 

  
  final VoidCallback? onMenu;

  const InboxMessageCard({
    super.key,
    required this.message,
    required this.sentByName,
    required this.sentToNames,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !message.isRead;
    return GestureDetector(
      onLongPress: onMenu,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceSunken,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: unread ? AppColors.forest : AppColors.line, width: unread ? 1.4 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              unread ? Icons.mark_email_unread_outlined : Icons.drafts_outlined,
              size: 22,
              color: unread ? AppColors.forest : AppColors.inkSoft,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.subject,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(message.bodyPreview, style: AppText.bodySoft, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(formatMessageTime(message.sentAt), style: AppText.bodySoft.copyWith(fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('To: $sentToNames', style: AppText.bodySoft.copyWith(fontSize: 11), overflow: TextOverflow.ellipsis),
                  Text('From: $sentByName', style: AppText.bodySoft.copyWith(fontSize: 11)),
                ],
              ),
            ),
            if (onMenu != null)
              IconButton(
                icon: const Icon(Icons.more_vert, size: 20, color: AppColors.inkSoft),
                onPressed: onMenu,
                tooltip: 'Message options',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
      ),
    );
  }
}