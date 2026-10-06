import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_chip.dart';
import '../widgets/househeld_bottom_nav.dart';
import '../widgets/low_stock_row.dart';
import '../widgets/stat_card.dart';
import '../widgets/task_row_card.dart';
import '../widgets/zero_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title, required this.onLogout});

  final String title;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  
  //sample data to show what the home screen will look like


  final List<DisplayMember> _members = const [
    DisplayMember(
      profile: UserProfile(uid: 'u1', username: 'ana', email: 'ana@example.com', displayName: 'Ana'),
      membership: HouseholdMember(userID: 'u1', householdID: 'demo-household', memberRole: 'manager'),
    ),
    DisplayMember(
      profile: UserProfile(uid: 'u2', username: 'alex', email: 'alex@example.com', displayName: 'Alex'),
      membership: HouseholdMember(userID: 'u2', householdID: 'demo-household', memberRole: 'member'),
    ),
    DisplayMember(
      profile: UserProfile(uid: 'u3', username: 'mira', email: 'mira@example.com', displayName: 'Mira'),
      membership: HouseholdMember(userID: 'u3', householdID: 'demo-household', memberRole: 'child'),
    ),
  ];

  List<HouseholdTask> _tasks = [
    const HouseholdTask(
      taskId: 't1',
      taskName: 'Take out recycling',
      taskStatus: 'completed',
      createdByMemberID: 'u1',
      completedByMemberID: 'u2',
    ),
    const HouseholdTask(
      taskId: 't2',
      taskName: 'Water the plants',
      taskStatus: 'pending',
      createdByMemberID: 'u1',
    ),
    const HouseholdTask(
      taskId: 't3',
      taskName: 'Vacuum living room',
      taskStatus: 'pending',
      createdByMemberID: 'u2',
    ),
  ];

  final List<LowStockItem> _lowStock = const [
    LowStockItem(name: 'Eggs', category: 'Food'),
    LowStockItem(name: 'Dish soap', category: 'Personal'),
  ];

  final List<ActivityEntry> _activity = const [
    ActivityEntry(text: 'Alex completed Take out recycling', time: '2hrs ago'),
    ActivityEntry(text: 'Ana restocked Milk', time: 'yesterday', isRestock: true),
  ];

  

  void _toggleTask(HouseholdTask task) {
    setState(() {
      final i = _tasks.indexWhere((t) => t.taskId == task.taskId);
      _tasks[i] = task.isCompleted
          ? task.copyWith(taskStatus: 'pending', completedByMemberID: null)
          : task.copyWith(taskStatus: 'completed', completedByMemberID: 'u1' /* */);
    });
  }

  void _addToGroceryList(LowStockItem item) {
    setState(() {
      _lowStock.remove(item);
      _activity.insert(
        0,
        ActivityEntry(text: 'Marked ${item.name} empty', time: 'just now', isRestock: true),
      );
    });
  }

  bool get _allCaughtUp =>
      _tasks.every((t) => t.isCompleted) && _lowStock.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _allCaughtUp ? _buildZeroState() : _buildNormalState(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: HouseheldBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }

  Widget _buildHeader() {
  final name = _members.first.profile.displayName;
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
              Text('Welcome home,', style: AppText.body.copyWith(color: const Color(0xFFC7D4C9), fontSize: 13)),
              const SizedBox(height: 2),
              Text(name, style: AppText.heading.copyWith(color: Colors.white, fontSize: 24)),
            ],
          ),
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

  Widget _buildNormalState() {
    final dueCount = _tasks.where((t) => !t.isCompleted).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatCard(number: '$dueCount', label: 'tasks due today'),
            const SizedBox(width: 10),
            StatCard(number: '${_lowStock.length}', label: 'items low'),
          ],
        ),
        const SizedBox(height: 22),
        Text('HOUSEHOLD', style: AppText.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _members.length; i++)
              AvatarChip(member: _members[i], colorSeed: i),
          ],
        ),
        const SizedBox(height: 22),
        Text('DUE TODAY', style: AppText.label),
        const SizedBox(height: 8),
        ..._tasks
            .where((t) => !t.isCompleted)
            .take(3)
            .map((t) => TaskRowCard(task: t, onToggle: () => _toggleTask(t))),
        if (_tasks.where((t) => !t.isCompleted).isEmpty)
          Text('No tasks due today.', style: AppText.bodySoft),
        const SizedBox(height: 14),
        Text('RUNNING LOW', style: AppText.label),
        const SizedBox(height: 8),
        ..._lowStock.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LowStockRow(item: item, onAdd: () => _addToGroceryList(item)),
          ),
        ),
        if (_lowStock.isEmpty)
          Text('Nothing running low.', style: AppText.bodySoft),
      ],
    );
  }

  Widget _buildZeroState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CelebrateCard(
          streakDays: 4,
          tasksThisWeek: _tasks.where((t) => t.isCompleted).length,
        ),
        const SizedBox(height: 18),
        Text('RECENT ACTIVITY', style: AppText.label),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: _activity
                .take(5)
                .map((a) => ActivityFeedRow(entry: a))
                .toList(),
          ),
        ),
      ],
    );
  }
}
