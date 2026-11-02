import 'package:flutter/material.dart';

import '../models.dart';
import '../services/grocery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/grocery_row_card.dart';
import '../widgets/househeld_bottom_nav.dart';
import 'grocery_list_form_screen.dart';
import 'grocery_items_screen.dart';
import 'shopping_screen.dart';
import 'pantry_screen.dart';
import 'stuff_screen.dart';
import 'tasks_screen.dart';

enum _ListSort { name, size }

// Grocery Screen class:
class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key, required this.householdID});
  final String householdID;

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

// State controller class:
class _GroceryScreenState extends State<GroceryScreen> {
  final GroceryService _service = GroceryService();

  late final Stream<List<GroceryList>> _listsStream;

  _ListSort _sort = _ListSort.name;
  bool _ascending = true;

  bool _busy = false;
  bool _resetDialogOpen = false;

  final Map<String, int> _itemCounts = {};

  String? _resetPromptedRevisionKey;

  @override
  void initState() {
    super.initState();
    _listsStream = _service.watchVisibleLists(widget.householdID);
  }

  // Reusable confirmation pop-up UI:
  Future<bool> _confirm(String title, String description) async {
    final value = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return value ?? false;
  }

  // Execution helper method:
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        final detail = e is StateError
            ? e.message.toString()
            : 'Action failed. Please check your connection and permissions.';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(detail)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Method to open the List creation/editing screen:
  Future<void> _openForm({
    GroceryList? existing,
    String? copyFromListID,
  }) async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => GroceryListFormScreen(
          householdID: widget.householdID,
          existingList: existing,
          copyFromListID: copyFromListID,
        ),
      ),
    );
    if (id != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Grocery List saved!')));
    }
  }

  // Method to rename the default Grocery List:
  Future<void> _renameDefault(GroceryList list) async {
    final controller = TextEditingController(text: list.groceryListName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change household Grocery List name'),
        content: TextField(
          controller: controller,
          maxLength: 200,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (newName == null) return;
    await _run(
      () => _service.renameDefaultList(
        householdID: widget.householdID,
        name: newName,
      ),
    );
  }

  // Method for the Grocery List options submenu
  Future<void> _showOptions(GroceryList list) async {
    if (_busy) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!list.isComplete)
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Mark as Complete'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (await _confirm(
                    'Mark as Complete?',
                    'This will mark every item in ${list.groceryListName} as Purchased.',
                  )) {
                    await _run(
                      () => _service.markListComplete(
                        householdID: widget.householdID,
                        groceryListID: list.groceryListID,
                      ),
                    );
                  }
                },
              ),
            if (!list.isDefault && list.isComplete)
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Mark as Incomplete'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (await _confirm(
                    'Mark as Incomplete?',
                    'This will mark every item in ${list.groceryListName} as unpurchased again.',
                  )) {
                    await _run(
                      () => _service.markListIncomplete(
                        householdID: widget.householdID,
                        groceryListID: list.groceryListID,
                      ),
                    );
                  }
                },
              ),
            if (list.isDefault) ...[
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Copy to new list'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openForm(copyFromListID: list.groceryListID);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Change name'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _renameDefault(list);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('Reset list'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (await _confirm(
                    'Reset list?',
                    'Remove all items from the household Grocery List?',
                  )) {
                    await _run(
                      () => _service.resetDefaultList(
                        householdID: widget.householdID,
                      ),
                    );
                  }
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openForm(existing: list);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  if (await _confirm(
                    'Delete list?',
                    'Delete ${list.groceryListName} and all its Grocery Items?',
                  )) {
                    await _run(
                      () => _service.deleteList(
                        householdID: widget.householdID,
                        groceryListID: list.groceryListID,
                      ),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Method for the default list "reset" prompt
  // This asks the user if they want to reset their default Grocery List
  void _promptForDefaultReset(GroceryList? list) {
    if (list == null || list.groceryListStatus != groceryListDefaultComplete) {
      _resetPromptedRevisionKey = null;
      return;
    }
    final key = '${list.groceryListID}:${list.groceryItemsRevision}';
    if (_resetDialogOpen || _resetPromptedRevisionKey == key) return;
    _resetPromptedRevisionKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _resetDialogOpen) return;
      _resetDialogOpen = true;
      try {
        final reset = await _confirm(
          'Grocery List complete!',
          'Your household Grocery List is complete, would you like to reset it?',
        );
        if (!mounted) return;
        if (!reset) {
          await _run(
            () => _service.dismissDefaultResetPrompt(
              householdID: widget.householdID,
            ),
          );
        } else {
          final copy = await _confirm(
            'Save a copy?',
            'Would you like to copy the list first to save it as a Past List?',
          );
          if (!mounted) return;
          if (copy) {
            await _openForm(copyFromListID: 'default');
          } else {
            await _run(
              () => _service.resetDefaultList(householdID: widget.householdID),
            );
          }
        }
      } finally {
        _resetDialogOpen = false;
      }
    });
  }

  // Navigation handling method:
  void _handleNav(int index) {
    if (index == 4) return;

    if (index == 0) {
      Navigator.popUntil(context, (route) => route.isFirst);
      return;
    }

    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TasksScreen(householdID: widget.householdID),
        ),
      );
      return;
    }

    if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantryScreen(householdID: widget.householdID),
        ),
      );
      return;
    }

    if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StuffScreen(householdID: widget.householdID),
        ),
      );
      return;
    }
  }

  // Sorting method:
  void _pickSort(_ListSort sort) {
    setState(() {
      if (_sort == sort) {
        _ascending = !_ascending;
      } else {
        _sort = sort;
        _ascending = true;
      }
    });
  }

  // Logic for displaying Grocery Lists entries from the DB:
  Widget _listCards(List<GroceryList> lists, {required String emptyText}) {
    if (lists.isEmpty) {
      return Center(child: Text(emptyText, style: AppText.bodySoft));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        for (final list in lists) ...[
          if (list.isDefault) ...[
            Text('Household Grocery List', style: AppText.label),
            const SizedBox(height: 8),
          ],
          StreamBuilder<List<GroceryItem>>(
            stream: _service.watchItems(
              householdID: widget.householdID,
              groceryListID: list.groceryListID,
            ),
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              if (snapshot.hasData &&
                  _itemCounts[list.groceryListID] != count) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _itemCounts[list.groceryListID] != count) {
                    setState(() => _itemCounts[list.groceryListID] = count);
                  }
                });
              }
              return GroceryRowCard(
                list: list,
                itemCount: count,
                onMenu: () => _showOptions(list),
                onViewItems: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroceryItemsScreen(
                        householdID: widget.householdID,
                        groceryListID: list.groceryListID,
                      ),
                    ),
                  );
                },
                onShop: () async {
                  if (list.isComplete || count == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Add some items or reopen the list before shopping!',
                        ),
                      ),
                    );
                    return;
                  }

                  final confirmed = await _confirm(
                    'Shopping Trip',
                    'Start shopping for ${list.groceryListName}?',
                  );

                  if (!confirmed || !context.mounted) return;

                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ShoppingScreen(
                        householdID: widget.householdID,
                        groceryListID: list.groceryListID,
                        listName: list.groceryListName,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

  // Actual UI for the Grocery Lists screen:
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroceryList>>(
      stream: _listsStream,
      builder: (context, snapshot) {
        final lists = snapshot.data ?? [];
        final defaultLists = lists.where((l) => l.isDefault).toList();
        _promptForDefaultReset(
          defaultLists.isEmpty ? null : defaultLists.first,
        );
        final customs = lists.where((l) => !l.isDefault).toList();
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              title: const Text('Grocery Lists'),
              actions: [
                PopupMenuButton<_ListSort>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort lists',
                  onSelected: _pickSort,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _ListSort.name,
                      child: Text(
                        'Name ${_sort == _ListSort.name ? (_ascending ? '↑' : '↓') : ''}',
                      ),
                    ),
                    PopupMenuItem(
                      value: _ListSort.size,
                      child: Text(
                        'Size ${_sort == _ListSort.size ? (_ascending ? '↑' : '↓') : ''}',
                      ),
                    ),
                  ],
                ),
              ],
              bottom: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xFFC7D4C9),
                tabs: [
                  Tab(text: 'Active Lists'),
                  Tab(text: 'Past Lists'),
                ],
              ),
            ),
            body: Column(
              children: [
                if (_busy) const LinearProgressIndicator(),
                Expanded(
                  child: snapshot.hasError
                      ? const Center(
                          child: Text(
                            'Unable to load Grocery Lists. Check permissions and try again.',
                          ),
                        )
                      : !snapshot.hasData
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          children: [
                            _sortedListView([
                              ...defaultLists,
                              ...customs.where((l) => !l.isComplete),
                            ], 'No active Grocery Lists.'),
                            _sortedListView(
                              customs.where((l) => l.isComplete).toList(),
                              'No past Grocery Lists yet.',
                            ),
                          ],
                        ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              backgroundColor: AppColors.clay,
              foregroundColor: Colors.white,
              onPressed: _busy ? null : () => _openForm(),
              child: const Icon(Icons.add),
            ),
            bottomNavigationBar: HouseheldBottomNav(
              currentIndex: 4,
              onTap: _handleNav,
            ),
          ),
        );
      },
    );
  }

  // Sorting logic:
  Widget _sortedListView(List<GroceryList> lists, String emptyText) {
    final sorted = [...lists];
    sorted.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      final compare = _sort == _ListSort.name
          ? a.groceryListName.toLowerCase().compareTo(
              b.groceryListName.toLowerCase(),
            )
          : (_itemCounts[a.groceryListID] ?? 0).compareTo(
              _itemCounts[b.groceryListID] ?? 0,
            );
      if (compare != 0) return _ascending ? compare : -compare;
      return a.groceryListName.toLowerCase().compareTo(
        b.groceryListName.toLowerCase(),
      );
    });
    return _listCards(sorted, emptyText: emptyText);
  }
}
