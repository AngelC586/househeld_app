import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/stuff_item_row.dart';
import '../widgets/househeld_bottom_nav.dart';
import '../services/stuff_service.dart';
import 'tasks_screen.dart';
import 'pantry_screen.dart';
import 'stuff_item_form_screen.dart';
import 'dart:async';

enum _ListType { household, private }

class StuffScreen extends StatefulWidget {
  const StuffScreen({super.key, required this.householdID});

  final String householdID;

  @override
  State<StuffScreen> createState() => _StuffScreenState();
}

class _StuffScreenState extends State<StuffScreen> {
  final _stuffService = StuffService();

  String get _currentUserID =>
    FirebaseAuth.instance.currentUser?.uid ?? '';

  StreamSubscription<List<StuffItem>>? _itemsSubscription;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  _ListType _listType = _ListType.household;
  bool _sortAscending = true;

  final List<StuffItem> _items = [];

  String get _listTypeString =>
      _listType == _ListType.household ? 'household' : 'private';
    
  @override
  void initState() {
    super.initState();
    _listenToItems();
  } 

  void _listenToItems() {
    _itemsSubscription?.cancel();

    final selectedList = _listTypeString;

    setState(() {
      _isLoading = true;
      _loadError = null;
      _items.clear();
    });

    _itemsSubscription = _stuffService.watchItems(
      householdID: widget.householdID, 
      listType: selectedList,
      )
      .listen(
        (items) {
          if (!mounted || selectedList != _listTypeString) return;

          setState(() {
            _items
              ..clear()
              ..addAll(items);

            _isLoading = false;
            _loadError = null;
          }); 
          },
          onError: (Object error) {
            if (!mounted || selectedList != _listTypeString) return;

            setState(() {
              _items.clear();
              _isLoading = false;
              _loadError = 'Unable to load your items. Please try again.';
            });
          }
        );
  } 

  void _selectList(_ListType listType) {
    if (_listType == listType) return;

    setState(() {
      _listType = listType;
    });

    _listenToItems();
  }

  @override
  void dispose() {
    _itemsSubscription?.cancel();
    super.dispose();
  }

  // Ask user if they want to add empty item to grocery list:
  Future<void> _askAddToGrocery(StuffItem item) async {
    final add = await _confirm(
      'Replenish',
      item.isPrivate
          ? 'Would you like to add ${item.itemName} to the general '
              'Grocery List? Its name and description will be visible '
              'to your household.'
          : 'Would you like to add ${item.itemName} to a Grocery List?',
    );

    if (!add || !mounted) return;

    await _askGroceryQuantity(item);
  }

  // UI for adding a stuff item to a grocery list:
  Future<void> _askGroceryQuantity(StuffItem item) async {
    final controller = TextEditingController(text: '1');

    final quantity = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('How many do you need to buy?'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());

                if (value != null && value > 0) {
                  Navigator.pop(dialogContext, value);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    // Allow the dialog to finish rebuilding before cleanup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (quantity == null || !mounted) return;

    await _stuffService.addToDefaultGroceryList(
      householdID: widget.householdID,
      item: item,
      quantity: quantity,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.itemName} added to Grocery List.'),
      ),
    );
  }

  Future<void> _updateStatus(
    StuffItem item, 
    String newStatus,
    ) async {
      if (_isSaving || item.itemStatus == newStatus) return;

      setState(() {
        _isSaving = true;
      });

      try {
        final becameOutOfStock = await _stuffService.updateStatus(
          householdID: widget.householdID,
          item: item,
          status: newStatus,
        );

        if (!mounted) return;

        if (becameOutOfStock) {
          await _askAddToGrocery(
           item.copyWith(itemStatus: newStatus),
          );
        }
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item status updated.')),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error is StateError 
        ? error.message.toString()
        : 'Unable to update the item status. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
    
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
    if (_isSaving) return;

    final userID = _currentUserID;

    if (userID.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add items.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });
    
    try {
      final result = await Navigator.push<StuffItem>(
        context,
        MaterialPageRoute(
          builder: (_) => StuffItemFormScreen(
            currentUserID: _currentUserID,
            listType: _listTypeString,
          ),
        ),
      );

      if (!mounted || result == null) return;

      final itemID = await _stuffService.createItem(
        householdID: widget.householdID,
        listType: result.listType,
        name: result.itemName,
        description: result.itemDescription,
        status: result.itemStatus,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added.')),
      );

      if (result.itemStatus == 'out_of_stock') {
        final savedItem = StuffItem(
          itemId: itemID,
          itemName: result.itemName,
          itemDescription: result.itemDescription,
          itemStatus: result.itemStatus,
          listType: result.listType,
          ownerMemberID: result.isPrivate ? userID : '',
        );

        try {
          await _askAddToGrocery(savedItem);
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unable to add the item to the grocery list. Please try again.')),
          );
        }
      }
    } catch (error) {
      if (!mounted) return;
      
      final message = error is StateError
        ? error.message.toString()
        : 'Unable to save the item. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _openEditItem(StuffItem item) async {
    if (_isSaving) return;

    final userID = _currentUserID;

    if (userID.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to edit items.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
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
    if (!mounted || result == null) return;

    await _stuffService.updateItem(
      householdID: widget.householdID,
      item: result,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item updated.')),
    );
    if (item.itemStatus != 'out_of_stock' && 
        result.itemStatus == 'out_of_stock') {
          await _addItemToGroceryAfterEdit(result);
        }
    } catch (error) {
      if (!mounted) return;

      final message = error is StateError 
      ? error.message.toString()
      : 'Unable to update the item. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteItem(StuffItem item) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final confirmed = await _confirm(
        'Delete this item?',
        'This will permanently remove "${item.itemName}" '
        'from your items list.',
      );
      
      if (!mounted || !confirmed) return;

      await _stuffService.deleteItem(
        householdID: widget.householdID,
        item: item,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted.')),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error is StateError 
      ? error.message.toString()
      : 'Unable to delete the item. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
      
  }

  Future<void> _addItemToGroceryListAfterEdit(StuffItem item) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _askAddToGrocery(
        item,
      );
    } catch (error) {
      if (!mounted) return;

      final message = error is StateError 
      ? error.message.toString()
      : 'Unable to add the item to the grocery list. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _addItemToGroceryAfterEdit(StuffItem item) async {
    try {
      await _askAddToGrocery(
        item,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to add the item to the grocery list. Please try again.')),
      );
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
              leading: const Icon(Icons.shopping_cart_outlined, color: AppColors.forest),
              title: const Text('Add to Grocery List'),
              onTap: () {
                Navigator.pop(context);
                _addItemToGroceryListAfterEdit(item);
              },
            ),
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
              onTap: () {
                Navigator.pop(context);
                _deleteItem(item);
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
                          _selectList(_ListType.household),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _toggleButton(
                      label: 'Private (yours)',
                      selected: _listType == _ListType.private,
                      onTap: () =>
                          _selectList(_ListType.private),
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
                    'Private items are only visible to you.',
                    style: AppText.bodySoft,
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_loadError != null)
                    Column(
                      children: [
                        Text(_loadError!, style: AppText.bodySoft),
                        TextButton(
                          onPressed: _listenToItems,
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  else if (sorted.isEmpty)
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
        onPressed: _isSaving ? null : _openAddItem,
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
