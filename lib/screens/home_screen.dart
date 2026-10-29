import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_chip.dart';
import '../widgets/househeld_bottom_nav.dart';
import '../widgets/low_stock_row.dart';
import '../widgets/stat_card.dart';
import '../widgets/task_row_card.dart';
import '../widgets/zero_state.dart';
import '../services/household_service.dart';
import '../services/task_service.dart';
import '../services/pantry_service.dart';
import '../services/stuff_service.dart';
import 'tasks_screen.dart';
import 'stuff_screen.dart';
import 'pantry_screen.dart';

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

  // Screen navigation:
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

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TasksScreen(householdID: householdID),
        ),
      );
      return;
    }

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PantryScreen(householdID: householdID),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StuffScreen(householdID: householdID),
        ),
      );
      return;
    }

    if (index == 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grocery List - Coming Soon!')),
      );
    }
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
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Log out',
          ),
        ],
      ),
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
