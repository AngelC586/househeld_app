import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../navigation/househeld_navigation.dart';
import '../services/grocery_service.dart';
import '../services/household_service.dart';
import '../services/inbox_service.dart';
import '../services/pantry_service.dart';
import '../services/reminder_service.dart';
import '../services/stuff_service.dart';
import '../services/task_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_chip.dart';
import '../widgets/home_module.dart';
import '../widgets/househeld_bottom_nav.dart';
import '../widgets/low_stock_row.dart';
import '../widgets/task_quick_add_dialog.dart';
import '../widgets/reminder_form_dialog.dart';
import '../widgets/reminder_row_card.dart';
import '../widgets/inbox_message_card.dart';
import '../widgets/stat_card.dart';
import '../widgets/task_row_card.dart';
import '../widgets/zero_state.dart';

import 'inbox_screen.dart';
import 'reminders_screen.dart';

// Home screen class:
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

// Home screen state class:
class _HomeScreenState extends State<HomeScreen> {
  static const int _navIndex = 0;

  static const List<String> _defaultOrder = [
    'household',
    'reminders',
    'tasks',
    'pantry',
    'stuff',
    'grocery',
  ];

  static const Map<String, String> _moduleTitles = {
    'household': 'Household',
    'reminders': 'Reminders',
    'tasks': 'Pending Tasks',
    'pantry': 'Out of Stock - Pantry',
    'stuff': 'Out of Stock - Stuff',
    'grocery': 'Active Grocery Lists',
  };

  // Home screen module order uses local storage:
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  List<String> _moduleOrder = List.from(_defaultOrder);

  Map<String, bool> _expanded = {for (final id in _defaultOrder) id: true};

  bool _preferencesReady = false;
  bool _savingLayout = false;

  int _preferencesLoadVersion = 0;

  Future<void> _pendingPreferenceWrites = Future<void>.value();

  String _orderPreferenceKey(String uid) => 'househeld.home.order.$uid';

  String _expandedPreferenceKey(String uid, String moduleID) =>
      'househeld.home.expanded.$uid.$moduleID';

  final _householdService = HouseholdService();
  final _taskService = TaskService();
  final _pantryService = PantryService();
  final _stuffService = StuffService();
  final _groceryService = GroceryService();
  final _reminderService = ReminderService();

  Stream<List<HouseholdMember>>? _membersStream;
  Stream<List<PantryItem>>? _pantryStream;
  Stream<List<StuffItem>>? _sharedStuffStream;
  Stream<List<StuffItem>>? _privateStuffStream;
  Stream<List<GroceryList>>? _groceryStream;
  Stream<List<Reminder>>? _remindersStream;

  final Map<String, Stream<List<HouseholdTask>>> _taskStreams = {};

  bool _savingReminder = false;
  bool _savingTask = false;

  @override
  void initState() {
    super.initState();
    _configureStreams();
    _loadHomePreferences();
  }

  // Get live data for all modules:
  void _configureStreams() {
    final householdID = widget.userProfile.householdID;

    _taskStreams.clear();

    if (householdID == null || householdID.isEmpty) {
      _membersStream = null;
      _pantryStream = null;
      _sharedStuffStream = null;
      _privateStuffStream = null;
      _groceryStream = null;
      _remindersStream = null;
      return;
    }

    _membersStream = _householdService.watchMembers(householdID);
    _pantryStream = _pantryService.watchPantryItems(householdID);

    _sharedStuffStream = _stuffService.watchItems(
      householdID: householdID,
      listType: 'household',
    );

    _privateStuffStream = _stuffService.watchItems(
      householdID: householdID,
      listType: 'private',
    );

    _groceryStream = _groceryService.watchVisibleLists(householdID);

    _remindersStream = _reminderService.watchReminders(householdID);
  }

  // Load a user's saved module order and collapse states:
  Future<void> _loadHomePreferences() async {
    final uid = widget.userProfile.uid;
    final loadVersion = ++_preferencesLoadVersion;

    try {
      final savedOrder = await _preferences.getStringList(
        _orderPreferenceKey(uid),
      );

      final restoredOrder = <String>[];

      if (savedOrder != null) {
        for (final id in savedOrder) {
          if (_defaultOrder.contains(id) && !restoredOrder.contains(id)) {
            restoredOrder.add(id);
          }
        }
      }

      for (final id in _defaultOrder) {
        if (!restoredOrder.contains(id)) {
          restoredOrder.add(id);
        }
      }

      final restoredExpanded = <String, bool>{};

      for (final id in _defaultOrder) {
        restoredExpanded[id] =
            await _preferences.getBool(_expandedPreferenceKey(uid, id)) ?? true;
      }

      if (!mounted ||
          uid != widget.userProfile.uid ||
          loadVersion != _preferencesLoadVersion) {
        return;
      }

      setState(() {
        _moduleOrder = restoredOrder;
        _expanded = restoredExpanded;
        _preferencesReady = true;
      });
    } catch (error) {
      debugPrint('Loading Home Screen preferences failed: $error');

      if (!mounted ||
          uid != widget.userProfile.uid ||
          loadVersion != _preferencesLoadVersion) {
        return;
      }

      setState(() {
        _moduleOrder = List.from(_defaultOrder);
        _expanded = {for (final id in _defaultOrder) id: true};
        _preferencesReady = true;
      });
    }
  }

  // Queue local preferences in the requested order:
  void _queuePreferenceWrite(Future<void> Function() write) {
    _pendingPreferenceWrites = _pendingPreferenceWrites
        .then((_) => write())
        .catchError((Object error) {
          debugPrint('Saving home screen preferences failed: $error');
        });
  }

  // Checks for changes in user or household and reloads things accordingly:
  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final userChanged = oldWidget.userProfile.uid != widget.userProfile.uid;

    final householdChanged =
        oldWidget.userProfile.householdID != widget.userProfile.householdID;

    if (userChanged || householdChanged) {
      _configureStreams();
    }

    if (userChanged) {
      _moduleOrder = List.from(_defaultOrder);
      _expanded = {for (final id in _defaultOrder) id: true};

      _preferencesReady = false;

      _loadHomePreferences();
    }
  }

  // Get user role, primarily for tasks:
  Stream<List<HouseholdTask>> _tasksForRole(String role) {
    return _taskStreams.putIfAbsent(role, () {
      return _taskService.watchTasks(
        householdID: widget.userProfile.householdID!,
        memberRole: role,
      );
    });
  }

  // Navigation method:
  void _handleNav(int index) {
    if (index == 0) return;

    final householdID = widget.userProfile.householdID;

    if (householdID == null || householdID.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No household is currently available.')),
      );
      return;
    }

    HouseheldNavigation.navigate(
      context: context,
      householdID: householdID,
      currentIndex: 0,
      destinationIndex: index,
    );
  }

  // Collapse/expand modules (preferences are saved locally):
  void _toggleModule(String id) {
    if (!_preferencesReady || !_defaultOrder.contains(id)) {
      return;
    }

    final uid = widget.userProfile.uid;
    final nextExpanded = !(_expanded[id] ?? true);

    setState(() {
      _expanded[id] = nextExpanded;
    });

    _queuePreferenceWrite(
      () => _preferences.setBool(_expandedPreferenceKey(uid, id), nextExpanded),
    );
  }

  bool _isExpanded(String id) => _expanded[id] ?? true;

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

  // Something went wrong...
  Widget _loadError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.bodySoft,
        ),
      ),
    );
  }

  // Loading...
  Widget _loading() {
    return const Center(child: CircularProgressIndicator());
  }

  // Empty text:
  Widget _empty(String message) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppText.bodySoft,
      ),
    );
  }

  // Row cards for module entries:
  Widget _cards(List<Widget> children, {required String emptyText}) {
    if (children.isEmpty) {
      return _empty(emptyText);
    }

    return ListView(padding: EdgeInsets.zero, children: children);
  }

  // Add new reminder:
  Future<void> _openAddReminder() async {
    if (_savingReminder) return;

    final householdID = widget.userProfile.householdID;
    final userID = widget.userProfile.uid;

    if (householdID == null || householdID.isEmpty) return;

    setState(() => _savingReminder = true);

    try {
      final result = await showReminderFormDialog(context);

      if (!mounted || result == null) return;

      if (widget.userProfile.uid != userID ||
          widget.userProfile.householdID != householdID) {
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

  // Go to Reminders Screen:
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

  // Add new task:
  Future<void> _openAddTask(List<HouseholdMember> members) async {
    if (_savingTask) return;

    final householdID = widget.userProfile.householdID;
    final userID = widget.userProfile.uid;

    if (householdID == null || householdID.isEmpty) return;

    // Only Managers and Members can create tasks:
    final currentMember = _findCurrentMember(members);

    if (currentMember == null ||
        (currentMember.memberRole != 'manager' &&
            currentMember.memberRole != 'member')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Managers and Members can create tasks.'),
        ),
      );
      return;
    }

    setState(() => _savingTask = true);

    try {
      final result = await showTaskQuickAddDialog(context, members: members);

      if (!mounted || result == null) return;

      if (widget.userProfile.uid != userID ||
          widget.userProfile.householdID != householdID) {
        return;
      }

      await _taskService.createTask(
        householdID: householdID,
        name: result.name,
        description: result.description,
        assignedMemberIDs: result.assignedMemberIDs,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created successfully!')),
      );
    } catch (error) {
      debugPrint('Task could not be created: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : error is ArgumentError
                ? error.message?.toString() ?? 'Invalid task information.'
                : 'Unable to create task. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingTask = false);
      }
    }
  }

  // Inbox preview:
  Future<void> _openInboxMessage(
    String householdID,
    InboxMessage message,
    List<HouseholdMember> members,
  ) async {
    final sender =
        _memberName(members, message.sentByMemberID) ?? 'Unknown member';

    final recipients = message.sentToMemberIDs
        .map((id) => _memberName(members, id) ?? 'Unknown member')
        .join(', ');

    final dialog = showDialog<void>(
      context: context,
      builder: (messageContext) => AlertDialog(
        title: Text(message.subject),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('From: $sender', style: AppText.bodySoft),
              const SizedBox(height: 4),
              Text('To: $recipients', style: AppText.bodySoft),
              const SizedBox(height: 4),
              Text(formatMessageTime(message.sentAt), style: AppText.bodySoft),
              const SizedBox(height: 16),
              SelectableText(message.body, style: AppText.body),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(messageContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    bool readFailed = false;

    if (!message.isRead) {
      try {
        await InboxService().setRead(
          householdID: householdID,
          messageID: message.messageId,
          isRead: true,
        );
      } catch (error) {
        debugPrint('Failed to mark message as read: $error');
        readFailed = true;
      }
    }

    await dialog;

    if (!mounted || !readFailed) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to mark message as read.')),
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
                      'Unable to load your messages. '
                      'Please try again.',
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
                            onTap: () => _openInboxMessage(
                              householdID,
                              message,
                              members,
                            ),
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
                              'From: '
                              '${_memberName(members, message.sentByMemberID) ?? 'Unknown member'}'
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
      MaterialPageRoute<void>(
        builder: (_) => InboxScreen(householdID: householdID),
      ),
    );
  }

  // Sign out confirmation dialog:
  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out of HouseHeld?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    widget.onLogout();
  }

  // Top banner:
  Widget _buildHeader() {
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
                  widget.userProfile.displayName,
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
            onPressed: _confirmSignOut,
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Log out',
          ),
        ],
      ),
    );
  }

  // Edit home screen dialog:
  Future<void> _editHomeScreen() async {
    if (!_preferencesReady || _savingLayout) return;

    final uid = widget.userProfile.uid;

    final draftOrder = List<String>.from(_moduleOrder);

    final result = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, updateDialog) {
            return AlertDialog(
              title: const Text('Edit Home Screen'),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Drag the modules to change the layout of your home screen.',
                      style: AppText.bodySoft,
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: ReorderableListView(
                        buildDefaultDragHandles: false,
                        padding: EdgeInsets.zero,
                        onReorderItem: (oldIndex, newIndex) {
                          updateDialog(() {
                            final moved = draftOrder.removeAt(oldIndex);
                            draftOrder.insert(newIndex, moved);
                          });
                        },
                        children: [
                          for (var i = 0; i < draftOrder.length; i++)
                            Card(
                              key: ValueKey(draftOrder[i]),
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 0,
                              color: AppColors.surfaceSunken,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: AppColors.line),
                              ),
                              child: ListTile(
                                dense: true,
                                title: Text(
                                  _moduleTitles[draftOrder[i]] ?? draftOrder[i],
                                  style: AppText.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.drag_handle,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    List<String>.from(draftOrder),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;

    if (uid != widget.userProfile.uid) return;

    setState(() => _savingLayout = true);

    try {
      await _preferences.setStringList(_orderPreferenceKey(uid), result);

      if (!mounted || uid != widget.userProfile.uid) return;

      setState(() {
        _moduleOrder = List<String>.from(result);
      });
    } catch (error) {
      debugPrint('Saving Home Screen layout failed: $error');

      if (!mounted || uid != widget.userProfile.uid) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to save your Home Screen layout. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingLayout = false);
      }
    }
  }

  // HOUSEHOLD (Members) Module:
  Widget _householdModule(List<HouseholdMember> members) {
    return HomeModule(
      title: 'HOUSEHOLD',
      expanded: _isExpanded('household'),
      onToggle: () => _toggleModule('household'),
      boxed: false,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < members.length; i++)
            AvatarChip(
              key: ValueKey(members[i].userID),
              member: members[i],
              colorSeed: i,
            ),
        ],
      ),
    );
  }

  // REMINDERS Module:
  Widget _remindersModule() {
    return HomeModule(
      title: 'REMINDERS',
      expanded: _isExpanded('reminders'),
      onToggle: () => _toggleModule('reminders'),
      onAdd: _savingReminder ? null : _openAddReminder,
      onViewAll: _openRemindersScreen,
      child: StreamBuilder<List<Reminder>>(
        stream: _remindersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _loadError('Unable to load your reminders.');
          }

          if (!snapshot.hasData) return _loading();

          final upcoming = sortRemindersByPriority(
            snapshot.data!.where((reminder) => !reminder.isCompleted).toList(),
          );

          return _cards([
            for (final reminder in upcoming)
              ReminderRowCard(
                key: ValueKey(reminder.reminderID),
                reminder: reminder,
              ),
          ], emptyText: 'No upcoming reminders!');
        },
      ),
    );
  }

  // PENDING TASKS Module:
  Widget _tasksModule(
    List<HouseholdTask> tasks,
    List<HouseholdMember> members,
  ) {
    final pending = tasks.where((task) => !task.isCompleted).toList()
      ..sort((a, b) {
        final byName = a.taskName.toLowerCase().compareTo(
          b.taskName.toLowerCase(),
        );

        return byName != 0 ? byName : a.taskId.compareTo(b.taskId);
      });

    final currentMember = _findCurrentMember(members);

    final canCreateTask =
        currentMember?.memberRole == 'manager' ||
        currentMember?.memberRole == 'member';

    return HomeModule(
      title: 'PENDING TASKS',
      expanded: _isExpanded('tasks'),
      onToggle: () => _toggleModule('tasks'),
      onAdd: canCreateTask && !_savingTask ? () => _openAddTask(members) : null,
      onViewAll: () => _handleNav(1),
      // Quick-create Task button added in Batch 2.
      child: _cards([
        for (final task in pending)
          TaskRowCard(
            key: ValueKey(task.taskId),
            task: task,
            creatorName: _memberName(members, task.createdByMemberID),
            showCheckbox: false,
            onToggle: null,
          ),
      ], emptyText: 'No pending tasks!'),
    );
  }

  // OUT OF STOCK PANTRY Module:
  Widget _pantryModule(List<PantryItem> pantryItems) {
    final outOfStock = pantryItems.where((item) => !item.isInStock).toList()
      ..sort(
        (a, b) => a.foodName.toLowerCase().compareTo(b.foodName.toLowerCase()),
      );

    return HomeModule(
      title: 'OUT OF STOCK - PANTRY',
      expanded: _isExpanded('pantry'),
      onToggle: () => _toggleModule('pantry'),
      onViewAll: () => _handleNav(2),
      child: _cards([
        for (final item in outOfStock)
          Padding(
            key: ValueKey(item.foodItemID),
            padding: const EdgeInsets.only(bottom: 10),
            child: LowStockRow(
              item: item,
              onOpen: () => _handleNav(2),
              showViewButton: false,
            ),
          ),
      ], emptyText: 'All stocked up!'),
    );
  }

  // OUT OF STOCK STUFF Module:
  Widget _stuffModule(List<StuffItem> stuffItems) {
    final outOfStock = stuffItems.where((item) => item.isOutOfStock).toList()
      ..sort((a, b) {
        final byName = a.itemName.toLowerCase().compareTo(
          b.itemName.toLowerCase(),
        );

        return byName != 0 ? byName : a.itemId.compareTo(b.itemId);
      });

    return HomeModule(
      title: 'OUT OF STOCK - STUFF',
      expanded: _isExpanded('stuff'),
      onToggle: () => _toggleModule('stuff'),
      onViewAll: () => _handleNav(3),
      child: _cards([
        for (final item in outOfStock)
          Padding(
            key: ValueKey('${item.listType}:${item.itemId}'),
            padding: const EdgeInsets.only(bottom: 10),
            child: LowStockRow.stuff(
              item: item,
              onOpen: () => _handleNav(3),
              showViewButton: false,
            ),
          ),
      ], emptyText: 'All stocked up!'),
    );
  }

  // Grocery row card for the Grocery module:
  Widget _groceryCard(GroceryList list) {
    final isPrivateList =
        list.groceryListVisibility == 'restricted' &&
        list.ownerMemberID == widget.userProfile.uid &&
        list.visibleMemberIDs.isEmpty;

    return Container(
      key: ValueKey(list.groceryListID),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (list.isDefault) ...[
                const Icon(
                  Icons.home_outlined,
                  color: AppColors.forest,
                  size: 20,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  list.groceryListName,
                  style: AppText.heading.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          if (list.groceryListDescription.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              list.groceryListDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodySoft,
            ),
          ],
          const SizedBox(height: 7),
          Text(
            isPrivateList ? 'Active · Private' : 'Active',
            style: AppText.bodySoft.copyWith(color: AppColors.forest),
          ),
        ],
      ),
    );
  }

  // ACTIVE GROCERY LISTS Module:
  Widget _groceryModule(AsyncSnapshot<List<GroceryList>> snapshot) {
    Widget content;

    if (snapshot.hasError) {
      content = _loadError('Unable to load Grocery Lists.');
    } else if (!snapshot.hasData) {
      content = _loading();
    } else {
      final active = snapshot.data!.where((list) => !list.isComplete).toList();

      content = _cards([
        for (final list in active) _groceryCard(list),
      ], emptyText: 'Nothing left to buy!');
    }

    return HomeModule(
      title: 'ACTIVE GROCERY LISTS',
      expanded: _isExpanded('grocery'),
      onToggle: () => _toggleModule('grocery'),
      onViewAll: () => _handleNav(4),
      child: content,
    );
  }

  // Build Home Screen Dashboard:
  Widget _buildDashboard({
    required List<HouseholdMember> members,
    required List<HouseholdTask> tasks,
    required List<PantryItem> pantryItems,
    required List<StuffItem> sharedStuff,
    required List<StuffItem> privateStuff,
    required AsyncSnapshot<List<GroceryList>> grocerySnapshot,
  }) {
    final pendingCount = tasks.where((task) => !task.isCompleted).length;

    final outPantryCount = pantryItems.where((item) => !item.isInStock).length;

    final allStuff = [...sharedStuff, ...privateStuff];

    final outStuffCount = allStuff.where((item) => item.isOutOfStock).length;

    final totalOut = outPantryCount + outStuffCount;

    Widget moduleFor(String id) {
      switch (id) {
        case 'household':
          return _householdModule(members);
        case 'reminders':
          return _remindersModule();
        case 'tasks':
          return _tasksModule(tasks, members);
        case 'pantry':
          return _pantryModule(pantryItems);
        case 'stuff':
          return _stuffModule(allStuff);
        case 'grocery':
          return _groceryModule(grocerySnapshot);
        default:
          return const SizedBox.shrink();
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatCard(number: '$pendingCount', label: 'tasks pending'),
              const SizedBox(width: 10),
              StatCard(number: '$totalOut', label: 'items out'),
            ],
          ),

          if (pendingCount == 0 && totalOut == 0) ...[
            const SizedBox(height: 18),
            const CelebrateCard(),
          ],

          const SizedBox(height: 22),

          for (final id in _moduleOrder) ...[
            KeyedSubtree(key: ValueKey('module-$id'), child: moduleFor(id)),
            const SizedBox(height: 18),
          ],

          const SizedBox(height: 4),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _preferencesReady && !_savingLayout
                  ? _editHomeScreen
                  : null,
              icon: const Icon(Icons.tune),
              label: Text(
                _savingLayout ? 'Saving Home Layout...' : 'Edit Home Screen',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.forest,
                side: const BorderSide(color: AppColors.forest),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Data streams & the actual home screen UI:
  @override
  Widget build(BuildContext context) {
    final householdID = widget.userProfile.householdID;

    if (householdID == null || householdID.isEmpty) {
      return Scaffold(
        body: _loadError('Unable to load household data.'),
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
              child: !_preferencesReady
                  ? _loading()
                  : StreamBuilder<List<HouseholdMember>>(
                      stream: _membersStream,
                      builder: (context, membersSnapshot) {
                        if (membersSnapshot.hasError) {
                          return _loadError(
                            'Unable to load household members.',
                          );
                        }

                        if (!membersSnapshot.hasData) return _loading();

                        final members = membersSnapshot.data!;
                        final currentMember = _findCurrentMember(members);

                        if (currentMember == null) {
                          return _loadError(
                            'Your household membership could not be verified.',
                          );
                        }

                        return StreamBuilder<List<HouseholdTask>>(
                          key: ValueKey(currentMember.memberRole),
                          stream: _tasksForRole(currentMember.memberRole),
                          builder: (context, tasksSnapshot) {
                            if (tasksSnapshot.hasError) {
                              return _loadError(
                                'Unable to load household tasks.',
                              );
                            }

                            if (!tasksSnapshot.hasData) return _loading();

                            return StreamBuilder<List<PantryItem>>(
                              stream: _pantryStream,
                              builder: (context, pantrySnapshot) {
                                if (pantrySnapshot.hasError) {
                                  return _loadError(
                                    'Unable to load Pantry items.',
                                  );
                                }

                                if (!pantrySnapshot.hasData) {
                                  return _loading();
                                }

                                return StreamBuilder<List<StuffItem>>(
                                  stream: _sharedStuffStream,
                                  builder: (context, sharedSnapshot) {
                                    if (sharedSnapshot.hasError) {
                                      return _loadError(
                                        'Unable to load household Stuff.',
                                      );
                                    }

                                    if (!sharedSnapshot.hasData) {
                                      return _loading();
                                    }

                                    return StreamBuilder<List<StuffItem>>(
                                      stream: _privateStuffStream,
                                      builder: (context, privateSnapshot) {
                                        if (privateSnapshot.hasError) {
                                          return _loadError(
                                            'Unable to load private Stuff.',
                                          );
                                        }

                                        if (!privateSnapshot.hasData) {
                                          return _loading();
                                        }

                                        return StreamBuilder<List<GroceryList>>(
                                          stream: _groceryStream,
                                          builder: (context, grocerySnapshot) {
                                            return _buildDashboard(
                                              members: members,
                                              tasks: tasksSnapshot.data!,
                                              pantryItems: pantrySnapshot.data!,
                                              sharedStuff: sharedSnapshot.data!,
                                              privateStuff:
                                                  privateSnapshot.data!,
                                              grocerySnapshot: grocerySnapshot,
                                            );
                                          },
                                        );
                                      },
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
}
