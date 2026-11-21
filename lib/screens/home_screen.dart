import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../navigation/househeld_navigation.dart';
import '../widgets/avatar_chip.dart';
import '../widgets/househeld_bottom_nav.dart';
import '../widgets/low_stock_row.dart';
import '../widgets/stat_card.dart';
import '../widgets/task_row_card.dart';
import '../widgets/zero_state.dart';
import '../widgets/inbox_message_card.dart';
import '../widgets/reminder_form_dialog.dart';
import '../widgets/reminders_home_window.dart';
import '../services/household_service.dart';
import '../services/task_service.dart';
import '../services/pantry_service.dart';
import '../services/stuff_service.dart';
import '../services/inbox_service.dart';
import '../services/reminder_service.dart';
import 'inbox_screen.dart';
import 'reminders_screen.dart';

//import '../services/grocery_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.title,
    required this.userProfile,
    required this.onLogout,
  });

  final String title;
  final UserProfile userProfile;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int _navIndex = 0;

  final HouseholdService _householdService = HouseholdService();
  final TaskService _taskService = TaskService();
  final PantryService _pantryService = PantryService();
  final StuffService _stuffService = StuffService();

  // Screen navigation method:
  void _handleNav(int index) {
    if (index == 0) return;

    final householdID = widget.userProfile.householdID;

    // Cannot access screens if not signed in:
    if (householdID == null || householdID.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open this feature because no household is available.',
          ),
        ),
      );
      return;
    }

    // Call HouseheldNavigation class to navigate:
    HouseheldNavigation.navigate(
      context: context,
      householdID: householdID,
      currentIndex: 0,
      destinationIndex: index,
    );
  }

  // Get household members:
  HouseholdMember? _findCurrentMember(List<HouseholdMember> members) {
    for (final member in members) {
      if (member.userID == widget.userProfile.uid) {
        return member;
      }
    }

    return null;
  }

  String? _memberName(List<HouseholdMember> members, String memberID) {
    for (final member in members) {
      if (member.userID == memberID) {
        final name = member.displayName.trim();

        return name.isEmpty ? null : name;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final householdID = widget.userProfile.householdID;

    if (householdID == null || householdID.isEmpty) {
      return Scaffold(
        body: const Center(child: Text('Unable to load household data.')),
        bottomNavigationBar: HouseheldBottomNav(
          currentIndex: _navIndex,
          onTap: _handleNav,
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: StreamBuilder<List<HouseholdMember>>(
                stream: _householdService.watchMembers(householdID),
                builder: (context, membersSnapshot) {
                  if (membersSnapshot.hasError) {
                    return _buildLoadError('Unable to load household members.');
                  }

                  if (!membersSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final members = membersSnapshot.data!;

                  final currentMember = _findCurrentMember(members);

                  if (currentMember == null) {
                    return _buildLoadError(
                      'Your household membership could not be verified.',
                    );
                  }

                  return StreamBuilder<List<HouseholdTask>>(
                    stream: _taskService.watchTasks(
                      householdID: householdID,
                      memberRole: currentMember.memberRole,
                    ),
                    builder: (context, tasksSnapshot) {
                      if (tasksSnapshot.hasError) {
                        return _buildLoadError(
                          'Unable to load household tasks.',
                        );
                      }

                      if (!tasksSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return StreamBuilder<List<PantryItem>>(
                        stream: _pantryService.watchPantryItems(householdID),
                        builder: (context, pantrySnapshot) {
                          if (pantrySnapshot.hasError) {
                            return _buildLoadError(
                              'Unable to load Pantry items.',
                            );
                          }

                          if (!pantrySnapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          return StreamBuilder<List<StuffItem>>(
                            stream: _stuffService.watchItems(
                              householdID: householdID,
                              listType: 'household',
                            ),
                            builder: (context, stuffSnapshot) {
                              if (stuffSnapshot.hasError) {
                                return _buildLoadError(
                                  'Unable to load Stuff items.',
                                );
                              }

                              if (!stuffSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              return SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: _buildDashboard(
                                  members: members,
                                  tasks: tasksSnapshot.data!,
                                  pantryItems: pantrySnapshot.data!,
                                  stuffItems: stuffSnapshot.data!,
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: HouseheldBottomNav(
        currentIndex: _navIndex,
        onTap: _handleNav,
      ),
    );
  }

  // Handle build errors:
  Widget _buildLoadError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsGeometry.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.bodySoft,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = widget.userProfile.displayName;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: const BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome home,',
                  style: AppText.body.copyWith(
                    color: const Color(0xFFC7D4C9),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: AppText.heading.copyWith(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showInboxPreview,
            icon: const Icon(Icons.mail_outline, color: Colors.white),
            tooltip: 'Inbox',
          ),
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Log out',
          ),
        ],
      ),
    );
  }

  final ReminderService _reminderService = ReminderService();
  Stream<List<Reminder>>? _remindersStream;
  bool _savingReminder = false;

  @override
  void initState() {
    super.initState();
    _listenToReminders();
  }

  void _listenToReminders() {
    final householdID = widget.userProfile.householdID;

    _remindersStream = householdID == null || householdID.isEmpty
        ? null
        : _reminderService.watchReminders(householdID);
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.userProfile.householdID != widget.userProfile.householdID ||
        oldWidget.userProfile.uid != widget.userProfile.uid) {
      _listenToReminders();
    }
  }

  Future<void> _openAddReminder() async {
    if (_savingReminder) return;

    final householdID = widget.userProfile.householdID;
    final userID = widget.userProfile.uid;
    if (householdID == null || householdID.isEmpty) return;

    setState(() => _savingReminder = true);

    try {
      final result = await showReminderFormDialog(context);

      if (!mounted || result == null) return;

      if (widget.userProfile.householdID != householdID ||
          widget.userProfile.uid != userID) {
        return;
      }

      await _reminderService.createReminder(
        householdID: householdID,
        reminder: result,
      );
    } catch (error) {
      debugPrint('Creating reminder failed: $error');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'Unable to save your reminder. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingReminder = false);
      }
    }
  }

  void _openRemindersScreen() {
    final householdID = widget.userProfile.householdID;
    if (householdID == null || householdID.isEmpty) return;

    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RemindersScreen(householdID: householdID),
      ),
    );
  }

  Future<void> _showInboxPreview() async {
    final householdID = widget.userProfile.householdID;
    if (householdID == null || householdID.isEmpty) return;

    final messagesStream = InboxService().watchMessages(householdID);
    final membersStream = _householdService.watchMembers(householdID);

    final openInbox = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Inbox'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<HouseholdMember>>(
            stream: membersStream,
            builder: (context, membersSnapshot) {
              final members = membersSnapshot.data ?? [];

              return StreamBuilder<List<InboxMessage>>(
                stream: messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Unable to load your messages. Please try again.',
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final recent = snapshot.data!.take(5).toList();

                  if (recent.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('No messages yet.', style: AppText.bodySoft),
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final message in recent)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: !message.isRead
                                ? const Icon(
                                    Icons.circle,
                                    size: 10,
                                    color: AppColors.clay,
                                  )
                                : const SizedBox(width: 10),
                            title: Text(
                              message.subject,
                              style: TextStyle(
                                fontWeight: message.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'From: ${_memberName(members, message.sentByMemberID) ?? 'Unknown member'}'
                              '\n${formatMessageTime(message.sentAt)}',
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('View Inbox →'),
          ),
        ],
      ),
    );

    if (!mounted || openInbox != true) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => InboxScreen(householdID: householdID)),
    );
  }

  Widget _buildDashboard({
    required List<HouseholdMember> members,
    required List<HouseholdTask> tasks,
    required List<PantryItem> pantryItems,
    required List<StuffItem> stuffItems,
  }) {
    final pendingTasks = tasks.where((task) => !task.isCompleted).toList();

    final outOfStockItems = pantryItems
        .where((item) => !item.isInStock)
        .toList();

    final outOfStockStuff = stuffItems
        .where((item) => item.itemStatus == 'out_of_stock')
        .toList();

    final totalItemsOut = outOfStockItems.length + outOfStockStuff.length;
    final allCaughtUp = pendingTasks.isEmpty && totalItemsOut == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatCard(number: '${pendingTasks.length}', label: 'tasks pending'),
            const SizedBox(width: 10),
            StatCard(number: '$totalItemsOut', label: 'items out'),
          ],
        ),

        const SizedBox(height: 22),

        Text('HOUSEHOLD', style: AppText.label),

        const SizedBox(height: 8),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < members.length; i++)
              AvatarChip(member: members[i], colorSeed: i),
          ],
        ),

        const SizedBox(height: 22),

        StreamBuilder<List<Reminder>>(
          key: ValueKey(
            '${widget.userProfile.uid}:${widget.userProfile.householdID}',
          ),
          stream: _remindersStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'Unable to load your reminders. Please try again.',
                style: AppText.bodySoft,
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                if (_savingReminder) const LinearProgressIndicator(),
                AbsorbPointer(
                  absorbing: _savingReminder,
                  child: RemindersHomeWindow(
                    reminders: snapshot.data!
                        .where((reminder) => !reminder.isCompleted)
                        .toList(),
                    onAdd: _openAddReminder,
                    onViewAll: _openRemindersScreen,
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 22),

        if (allCaughtUp) ...[
          const CelebrateCard(),
        ] else ...[
          Text('PENDING TASKS', style: AppText.label),

          const SizedBox(height: 8),

          for (final task in pendingTasks.take(3))
            TaskRowCard(
              task: task,
              creatorName: _memberName(members, task.createdByMemberID),
              onToggle: null,
            ),

          if (pendingTasks.isEmpty)
            Text('No pending tasks.', style: AppText.bodySoft),

          if (pendingTasks.length > 3)
            TextButton(
              onPressed: () => _handleNav(1),
              child: const Text('View all tasks →'),
            ),

          const SizedBox(height: 14),

          Text('OUT OF STOCK', style: AppText.label),

          const SizedBox(height: 8),

          for (final item in outOfStockItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LowStockRow(item: item, onOpen: () => _handleNav(2)),
            ),

          for (final item in outOfStockStuff)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LowStockRow.stuff(item: item, onOpen: () => _handleNav(3)),
            ),

          if (totalItemsOut == 0)
            Text('Nothing is out of stock.', style: AppText.bodySoft),
        ],
      ],
    );
  }
}
