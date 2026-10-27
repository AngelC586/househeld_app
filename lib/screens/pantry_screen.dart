import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import '../models.dart';
import '../services/pantry_service.dart';
import '../theme/app_theme.dart';
import '../widgets/househeld_bottom_nav.dart';
import '../widgets/pantry_row_card.dart';
import 'pantry_form_screen.dart';
import 'tasks_screen.dart';
import 'stuff_screen.dart';

// Sorting options:
enum _PantrySortField { name, type, quantity }

enum _SortDirection { asc, desc }

// Pantry screen class:
class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key, required this.householdID});

  final String householdID;

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

// Pantry screen state class:
class _PantryScreenState extends State<PantryScreen> {
  final PantryService _pantryService = PantryService();

  _PantrySortField _sortField = _PantrySortField.name;

  _SortDirection _sortDirection = _SortDirection.asc;

  bool _busy = false;

  // Put pantry items in a list to sort them:
  List<PantryItem> _sorted(List<PantryItem> items) {
    final sorted = [...items];

    switch (_sortField) {
      case _PantrySortField.name:
        sorted.sort(
          (a, b) =>
              a.foodName.toLowerCase().compareTo(b.foodName.toLowerCase()),
        );
        break;

      case _PantrySortField.type:
        sorted.sort(
          (a, b) =>
              a.foodType.toLowerCase().compareTo(b.foodType.toLowerCase()),
        );
        break;

      case _PantrySortField.quantity:
        sorted.sort((a, b) => a.foodQuantity.compareTo(b.foodQuantity));
        break;
    }

    return _sortDirection == _SortDirection.asc
        ? sorted
        : sorted.reversed.toList();
  }

  // Decide sorting type and direction:
  void _pickSort(_PantrySortField field) {
    setState(() {
      if (_sortField == field) {
        _sortDirection = _sortDirection == _SortDirection.asc
            ? _SortDirection.desc
            : _SortDirection.asc;
      } else {
        _sortField = field;
        _sortDirection = _SortDirection.asc;
      }
    });
  }

  // Action failure handling:
  Future<bool> _runAction(Future<void> Function() action) async {
    if (_busy) return false;

    setState(() => _busy = true);

    try {
      await action();
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to complete that action. Please try again.'),
          ),
        );
      }

      return false;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  // Create new pantry item:
  Future<void> _openCreateItem() async {
    final result = await Navigator.push<PantryItem>(
      context,
      MaterialPageRoute(builder: (_) => const PantryFormScreen()),
    );

    if (result == null) return;

    final succeeded = await _runAction(() async {
      await _pantryService.createPantryItem(
        householdID: widget.householdID,
        foodName: result.foodName,
        foodType: result.foodType,
        foodQuantity: result.foodQuantity,
        foodDescription: result.foodDescription,
      );
    });

    if (!succeeded) return;
  }

  // Edit existing pantry item:
  Future<void> _openEditItem(PantryItem item) async {
    final result = await Navigator.push<PantryItem>(
      context,
      MaterialPageRoute(builder: (_) => PantryFormScreen(existingItem: item)),
    );

    if (result == null) return;

    final becameOutOfStock = item.foodQuantity > 0 && result.foodQuantity == 0;

    final succeeded = await _runAction(() async {
      await _pantryService.updatePantryItem(
        householdID: widget.householdID,
        item: result,
      );
    });

    if (!succeeded) return;

    if (becameOutOfStock && mounted) {
      await _askAddToGrocery(result);
    }
  }

  // UI for quick updating an item's quantity:
  Future<void> _showQuantityDialog(PantryItem item) async {
    final controller = TextEditingController(text: '${item.foodQuantity}');

    final quantity = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        String? error;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Quantity'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'New Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = int.tryParse(controller.text.trim());

                    if (value == null || value < 0) {
                      setDialogState(() {
                        error = 'Quantity must be 0 or greater.';
                      });
                      return;
                    }

                    Navigator.pop(dialogContext, value);
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (quantity == null || quantity == item.foodQuantity) {
      return;
    }

    final becameOutOfStock = item.foodQuantity > 0 && quantity == 0;

    final succeeded = await _runAction(() async {
      await _pantryService.updateQuantity(
        householdID: widget.householdID,
        foodItemID: item.foodItemID,
        quantity: quantity,
      );
    });

    if (!succeeded) return;

    if (becameOutOfStock && mounted) {
      await _askAddToGrocery(item.copyWith(foodQuantity: quantity));
    }
  }

  // Reusable confirmation dialog UI:
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

  // Method for marking an item as Out of Stock:
  Future<void> _markOutOfStock(PantryItem item) async {
    if (!item.isInStock) return;

    final confirmed = await _confirm(
      'Confirm',
      'Are you sure you want to mark ${item.foodName} as Out of Stock?',
    );

    if (!confirmed) return;

    final succeeded = await _runAction(() async {
      await _pantryService.markOutOfStock(
        householdID: widget.householdID,
        foodItemID: item.foodItemID,
      );
    });

    if (!succeeded) return;
    if (!mounted) return;

    await _askAddToGrocery(item.copyWith(foodQuantity: 0));
  }

  // Ask user if they want to add empty item to grocery list:
  Future<void> _askAddToGrocery(PantryItem item) async {
    final add = await _confirm(
      'Replenish',
      'Would you like to add ${item.foodName} to a Grocery List?',
    );

    if (!add || !mounted) return;

    await _askGroceryQuantity(item);
  }

  // UI for adding a pantry item to a grocery list:
  Future<void> _askGroceryQuantity(PantryItem item) async {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });

    if (quantity == null) return;

    final succeeded = await _runAction(() async {
      await _pantryService.addToDefaultGroceryList(
        householdID: widget.householdID,
        pantryItem: item,
        quantity: quantity,
      );
    });

    if (!succeeded || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${item.foodName} added to Grocery List.')),
    );
  }

  // Logic for deleting a pantry item:
  Future<void> _deleteItem(PantryItem item) async {
    final confirmed = await _confirm(
      'Confirm',
      'Are you sure you want to delete ${item.foodName}?',
    );

    if (!confirmed) return;

    final succeeded = await _runAction(() async {
      await _pantryService.deletePantryItem(
        householdID: widget.householdID,
        foodItemID: item.foodItemID,
      );
    });

    if (!succeeded) return;
  }

  // Pantry item options menu UI:
  void _showItemMenu(PantryItem item) {
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
                Icons.remove_shopping_cart_outlined,
                color: AppColors.forest,
              ),
              title: const Text('Mark Out of Stock'),
              enabled: item.isInStock,
              onTap: item.isInStock
                  ? () {
                      Navigator.pop(context);
                      _markOutOfStock(item);
                    }
                  : null,
            ),

            ListTile(
              leading: const Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.forest,
              ),
              title: const Text('Add to Grocery List'),
              onTap: () {
                Navigator.pop(context);
                _askAddToGrocery(item);
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

  // Display pantry items for each tab:
  Widget _itemList(List<PantryItem> items, {required String emptyText}) {
    final sorted = _sorted(items);

    if (sorted.isEmpty) {
      return Center(child: Text(emptyText, style: AppText.bodySoft));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        ...sorted.map(
          (item) => PantryRowCard(
            item: item,
            onQuantityTap: () => _showQuantityDialog(item),
            onMenu: () => _showItemMenu(item),
          ),
        ),
      ],
    );
  }

  // Screen navigation
  void _handleNav(int index) {
    if (index == 2) return; // Already on Pantry

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

    if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StuffScreen(householdID: widget.householdID),
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

  // Main Pantry Screen UI:
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PantryItem>>(
      stream: _pantryService.watchPantryItems(widget.householdID),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Pantry')),
            body: const Center(child: Text('Unable to load Pantry Items...')),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final items = snapshot.data!;

        final inStock = items.where((item) => item.isInStock).toList();

        final outOfStock = items.where((item) => !item.isInStock).toList();

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text('Pantry'),
              actions: [
                PopupMenuButton<_PantrySortField>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort',
                  onSelected: _pickSort,
                  itemBuilder: (_) => [
                    _sortMenuItem(_PantrySortField.name, 'Name'),
                    _sortMenuItem(_PantrySortField.type, 'Type'),
                    _sortMenuItem(_PantrySortField.quantity, 'Quantity'),
                  ],
                ),

                IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip: 'Menu',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Menu - Coming Soon!')),
                    );
                  },
                ),
              ],
              bottom: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xFFC7D4C9),
                tabs: [
                  Tab(text: 'In Stock'),
                  Tab(text: 'Out of Stock'),
                ],
              ),
            ),

            body: Column(
              children: [
                if (_busy) const LinearProgressIndicator(),

                Expanded(
                  child: TabBarView(
                    children: [
                      _itemList(
                        inStock,
                        emptyText: 'The kitchen seems a bit empty...',
                      ),
                      _itemList(
                        outOfStock,
                        emptyText: 'Nothing is out of stock yet!',
                      ),
                    ],
                  ),
                ),
              ],
            ),

            floatingActionButton: FloatingActionButton(
              backgroundColor: AppColors.clay,
              onPressed: _busy ? null : _openCreateItem,
              child: const Icon(Icons.add, color: Colors.white),
            ),

            bottomNavigationBar: HouseheldBottomNav(
              currentIndex: 2,
              onTap: _handleNav,
            ),
          ),
        );
      },
    );
  }

  // Sorting menu UI:
  PopupMenuItem<_PantrySortField> _sortMenuItem(
    _PantrySortField field,
    String label,
  ) {
    final isActive = _sortField == field;

    final arrow = !isActive
        ? ''
        : (_sortDirection == _SortDirection.asc ? ' ↑' : ' ↓');

    return PopupMenuItem(
      value: field,
      child: Text(
        '$label$arrow',
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
