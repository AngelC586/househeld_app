import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/stuff_item_row.dart';
import '../widgets/househeld_bottom_nav.dart';
import 'tasks_screen.dart';
import 'pantry_screen.dart';
import 'stuff_item_form_screen.dart';

enum _ListType { household, private }

class StuffScreen extends StatefulWidget {
  const StuffScreen({super.key, required this.householdID});

  final String householdID;

  @override
  State<StuffScreen> createState() => _StuffScreenState();
}

class _StuffScreenState extends State<StuffScreen> {
  final String _currentUserID = 'u2';

  _ListType _listType = _ListType.household;
  bool _sortAscending = true;

  final List<StuffItem> _items = [];

  String get _listTypeString =>
      _listType == _ListType.household ? 'household' : 'private';

  void _updateStatus(StuffItem item, String newStatus) {
    setState(() {
      final i = _items.indexWhere((x) => x.itemId == item.itemId);
      _items[i] = item.copyWith(itemStatus: newStatus);
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

  Future<void> _openAddItem() async {
    final result = await Navigator.push<StuffItem>(
      context,
      MaterialPageRoute(
        builder: (_) => StuffItemFormScreen(
          currentUserID: _currentUserID,
          listType: _listTypeString,
        ),
      ),
    );
    if (result != null) {
      setState(() => _items.add(result));
    }
  }

  Future<void> _openEditItem(StuffItem item) async {
    final result = await Navigator.push<StuffItem>(
      context,
      MaterialPageRoute(
        builder: (_) => StuffItemFormScreen(
          currentUserID: _currentUserID,
          listType: item.listType,
          existingItem: item,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        final i = _items.indexWhere((x) => x.itemId == item.itemId);
        _items[i] = result;
      });
    }
  }

  void _showItemMenu(StuffItem item) {
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
              leading: const Icon(Icons.edit_outlined, color: AppColors.forest),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _openEditItem(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.clay),
              title: const Text('Delete'),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await _confirm(
                  'Delete this item?',
                  'This will permanently remove "${item.itemName}".',
                );
                if (confirmed) {
                  setState(() {
                    _items.removeWhere((x) => x.itemId == item.itemId);
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Screen navigation:
  void _handleNav(int index) {
    if (index == 3) return;

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

    if (index == 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grocery List - Coming Soon!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        _items.where((i) {
          if (_listType == _ListType.household) {
            return i.listType == 'household';
          }
          return i.listType == 'private' && i.ownerMemberID == _currentUserID;
        }).toList()..sort(
          (a, b) =>
              a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()),
        );

    final sorted = _sortAscending ? visible : visible.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Stuff'),
        actions: [
          IconButton(
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            tooltip: _sortAscending ? 'Sort: A to Z' : 'Sort: Z to A',
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () {
              // TODO: wire up whatever the top-level menu should contain
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Menu — not built yet')),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _toggleButton(
                      label: 'Household',
                      selected: _listType == _ListType.household,
                      onTap: () =>
                          setState(() => _listType = _ListType.household),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _toggleButton(
                      label: 'Private (yours)',
                      selected: _listType == _ListType.private,
                      onTap: () =>
                          setState(() => _listType = _ListType.private),
                    ),
                  ),
                ],
              ),
            ),
            if (_listType == _ListType.private)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSunken,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    'Private items are only visible on your device.',
                    style: AppText.bodySoft,
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  if (sorted.isEmpty)
                    Text('Nothing here yet.', style: AppText.bodySoft)
                  else
                    ...sorted.map(
                      (item) => StuffItemRow(
                        item: item,
                        onStatusChange: (status) => _updateStatus(item, status),
                        onMenu: () => _showItemMenu(item),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.clay,
        onPressed: _openAddItem,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: HouseheldBottomNav(
        currentIndex: 3,
        onTap: _handleNav,
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.line,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
