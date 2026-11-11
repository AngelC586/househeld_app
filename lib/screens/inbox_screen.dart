import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/inbox_message_card.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  // Uncomment this for database integration:
  // final String _currentUserID = '';

  final List<InboxMessage> _messages = [];

  final Map<String, String> _memberNames = const {};

  String _nameFor(String uid) => _memberNames[uid] ?? uid;

  String _namesFor(List<String> uids) {
    if (uids.isEmpty) return 'Anyone';
    return uids.map(_nameFor).join(', ');
  }

  void _toggleRead(InboxMessage message) {
    setState(() {
      final i = _messages.indexWhere((m) => m.messageId == message.messageId);
      _messages[i] = message.copyWith(isRead: !message.isRead);
    });
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showMessageMenu(InboxMessage message) {
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
            ListTile(
              leading: const Icon(
                Icons.mark_email_read_outlined,
                color: AppColors.forest,
              ),
              title: Text(message.isRead ? 'Mark as Unread' : 'Mark as Read'),
              onTap: () {
                Navigator.pop(context);
                _toggleRead(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.clay),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await _confirm(
                  'Delete this message?',
                  'Are you sure you want to delete this message?',
                );
                if (confirmed) {
                  setState(
                    () => _messages.removeWhere(
                      (m) => m.messageId == message.messageId,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSendMessageDialog() async {
    final subjectController = TextEditingController();
    final bodyController = TextEditingController();
    final selected = <String>{};

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Message'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: subjectController,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                TextField(
                  controller: bodyController,
                  maxLength: 500,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Message'),
                ),
                const SizedBox(height: 8),
                Text('Send To (up to 8)', style: AppText.label),
                const SizedBox(height: 6),
                if (_memberNames.isEmpty)
                  Text('No household members found.', style: AppText.bodySoft)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _memberNames.entries.map((entry) {
                      final isSelected = selected.contains(entry.key);
                      return FilterChip(
                        label: Text(entry.value),
                        selected: isSelected,
                        onSelected: (value) {
                          setDialogState(() {
                            if (value) {
                              if (selected.length < 8) selected.add(entry.key);
                            } else {
                              selected.remove(entry.key);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sending messages is not wired up yet.'),
                  ),
                );
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<InboxMessage> messages, {required String emptyText}) {
    if (messages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Center(child: Text(emptyText, style: AppText.bodySoft)),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: messages
          .map(
            (m) => InboxMessageCard(
              message: m,
              sentByName: _nameFor(m.sentByMemberID),
              sentToNames: _namesFor(m.sentToMemberIDs),
              onMenu: () => _showMessageMenu(m),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = _messages.where((m) => !m.isRead).toList();
    final read = _messages.where((m) => m.isRead).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.forestDeep,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Inbox',
                        style: AppText.heading.copyWith(fontSize: 20),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.forestDeep,
                      ),
                      tooltip: 'Send Message',
                      onPressed: _showSendMessageDialog,
                    ),
                  ],
                ),
              ),
              TabBar(
                labelColor: AppColors.forestDeep,
                unselectedLabelColor: AppColors.inkSoft,
                indicatorColor: AppColors.forest,
                tabs: [
                  Tab(text: 'Unread (${unread.length})'),
                  const Tab(text: 'Read'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildList(unread, emptyText: 'No unread messages.'),
                    _buildList(read, emptyText: 'No read messages.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
