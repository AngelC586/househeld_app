import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dart:async';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/inbox_message_card.dart';
import '../services/inbox_service.dart';
import '../services/household_service.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.householdID});

  final String householdID;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final InboxService _inboxService = InboxService();
  StreamSubscription<List<InboxMessage>>? _messagesSubscription;

  bool _isLoading = true;
  String? _loadError;

  final List<InboxMessage> _messages = [];

  final Map<String, String> _memberNames = {};
  final HouseholdService _householdService = HouseholdService();

  StreamSubscription<List<HouseholdMember>>? _membersSubscription;

  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _messagesSubscription = _inboxService
        .watchMessages(widget.householdID)
        .listen(
          (messages) {
            if (!mounted) return;

            setState(() {
              _messages
                ..clear()
                ..addAll(messages);
              _isLoading = false;
              _loadError = null;
            });
          },
          onError: (error) {
            debugPrint('Loading Inbox failed: $error');
            if (!mounted) return;

            setState(() {
              _messages.clear();
              _isLoading = false;
              _loadError = 'Unable to load youre messages. Please try again.';
            });
          },
        );

    _membersSubscription = _householdService
        .watchMembers(widget.householdID)
        .listen(
          (members) {
            if (!mounted) return;

            final userID = FirebaseAuth.instance.currentUser?.uid;
            String? role;

            for (final member in members) {
              if (member.userID == userID) {
                role = member.memberRole;
              }
            }

            setState(() {
              _memberNames
                ..clear()
                ..addEntries(
                  members.map(
                    (member) => MapEntry(
                      member.userID,
                      member.displayName.trim().isEmpty
                          ? 'Household member'
                          : member.displayName,
                    ),
                  ),
                );

              _canSend = role == 'manager' || role == 'member';
            });
          },
          onError: (Object error) {
            debugPrint('Loading Inbox members failed: $error');
            if (!mounted) return;

            setState(() {
              _memberNames.clear();
              _canSend = false;
            });
          },
        );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _membersSubscription?.cancel();
    super.dispose();
  }

  String _nameFor(String uid) => _memberNames[uid] ?? uid;

  String _namesFor(List<String> uids) {
    if (uids.isEmpty) return 'Anyone';
    return uids.map(_nameFor).join(', ');
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update your Inbox. Please try again.'),
        ),
      );
      debugPrint('Inbox action failed: $error');
    }
  }

  Future<void> _toggleRead(InboxMessage message) async {
    await _runAction(
      () => _inboxService.setRead(
        householdID: widget.householdID,
        messageID: message.messageId,
        isRead: !message.isRead,
      ),
    );
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

  Future<void> _openMessage(InboxMessage message) async {
    final dialog = showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(message.subject),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'From: ${_nameFor(message.sentByMemberID)}',
                style: AppText.bodySoft,
              ),
              const SizedBox(height: 4),
              Text(
                'To: ${_namesFor(message.sentToMemberIDs)}',
                style: AppText.bodySoft,
              ),
              const SizedBox(height: 4),
              Text(formatMessageTime(message.sentAt), style: AppText.bodySoft),
              const SizedBox(height: 16),
              SelectableText(message.body, style: AppText.body),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (!message.isRead) {
      await _runAction(
        () => _inboxService.setRead(
          householdID: widget.householdID,
          messageID: message.messageId,
          isRead: true,
        ),
      );
    }

    await dialog;
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

                if (!mounted || !confirmed) return;

                await _runAction(
                  () => _inboxService.deleteMessage(
                    householdID: widget.householdID,
                    messageID: message.messageId,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSendMessageDialog() async {
    if (!_canSend) return;

    final subjectController = TextEditingController();
    final bodyController = TextEditingController();
    final selected = <String>{};
    final memberNames = Map<String, String>.from(_memberNames);

    bool isSending = false;
    String? errorMessage;

    final sent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final everyoneSelected =
              memberNames.isNotEmpty &&
              memberNames.keys.every(selected.contains);

          return PopScope(
            canPop: !isSending,
            child: AlertDialog(
              title: const Text('New Message'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: subjectController,
                      enabled: !isSending,
                      maxLength: 50,
                      decoration: const InputDecoration(labelText: 'Subject'),
                    ),
                    TextField(
                      controller: bodyController,
                      enabled: !isSending,
                      maxLength: 500,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Message'),
                    ),
                    const SizedBox(height: 8),
                    Text('Send To (up to 8)', style: AppText.label),
                    const SizedBox(height: 6),
                    if (memberNames.isEmpty)
                      Text(
                        'No household members found.',
                        style: AppText.bodySoft,
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Everyone'),
                            selected: everyoneSelected,
                            onSelected: isSending
                                ? null
                                : (value) {
                                    setDialogState(() {
                                      selected.clear();
                                      if (value) {
                                        selected.addAll(memberNames.keys);
                                      }
                                    });
                                  },
                          ),
                          for (final entry in memberNames.entries)
                            FilterChip(
                              label: Text(entry.value),
                              selected: selected.contains(entry.key),
                              onSelected: isSending
                                  ? null
                                  : (value) {
                                      setDialogState(() {
                                        if (value) {
                                          if (selected.length < 8) {
                                            selected.add(entry.key);
                                          }
                                        } else {
                                          selected.remove(entry.key);
                                        }
                                      });
                                    },
                            ),
                        ],
                      ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          if (!_canSend) {
                            setDialogState(() {
                              errorMessage = 'You no longer have permission to send messages.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSending = true;
                            errorMessage = null;
                          });

                          try {
                            await _inboxService.sendMessage(
                              householdID: widget.householdID,
                              subject: subjectController.text,
                              body: bodyController.text,
                              recipientIDs: selected.toList(),
                            );
                          } catch (error) {
                            debugPrint('Sending Inbox message failed: $error');
                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              isSending = false;
                              errorMessage = error is StateError
                                  ? error.message.toString()
                                  : 'Unable to send your message. Please try again.';
                            });
                            return;
                          }

                          if (!dialogContext.mounted) return;

                          setDialogState(() {
                            isSending = false;
                          });

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          });
                        },
                  child: Text(isSending ? 'Sending...' : 'Send'),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Dispose after the dialog's closing animation finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      subjectController.dispose();
      bodyController.dispose();
    });

    if (!mounted || sent != true) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Message sent!')));
  }

  Widget _buildList(List<InboxMessage> messages, {required String emptyText}) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: AppText.bodySoft,
          ),
        ),
      );
    }

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
              onOpen: () => _openMessage(m),
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
                    if (_canSend)
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
