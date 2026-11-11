import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models.dart';
import '../services/grocery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/grocery_item_row_card.dart';

import 'grocery_item_form_screen.dart';
import 'shopping_screen.dart';

import 'dart:async';

enum GroceryItemSort { name, type, quantity }

// Grocery Items screen class:
class GroceryItemsScreen extends StatefulWidget {
  const GroceryItemsScreen({
    super.key,
    required this.householdID,
    required this.groceryListID,
  });

  final String householdID;
  final String groceryListID;

  @override
  State<GroceryItemsScreen> createState() => _GroceryItemsScreenState();
}

// State controller class:
class _GroceryItemsScreenState extends State<GroceryItemsScreen> {
  final GroceryService _groceryService = GroceryService();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _membershipSubscription;

  String? _memberRole;

  String get _currentUserID => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _canEditListItems(GroceryList list) {
    return list.canEditItems(
      memberID: _currentUserID,
      memberRole: _memberRole ?? '',
    );
  }

  late final Stream<GroceryList?> _listStream;
  late final Stream<List<GroceryItem>> _itemsStream;

  GroceryItemSort _sort = GroceryItemSort.name;
  bool _ascending = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _listStream = _groceryService.watchList(
      householdID: widget.householdID,
      groceryListID: widget.groceryListID,
    );

    _itemsStream = _groceryService.watchItems(
      householdID: widget.householdID,
      groceryListID: widget.groceryListID,
    );

    final userID = _currentUserID;
    if (userID.isEmpty) return;

    _membershipSubscription = FirebaseFirestore.instance
        .collection('households')
        .doc(widget.householdID)
        .collection('members')
        .doc(userID)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;

            setState(() {
              _memberRole = snapshot.data()?['memberRole'] as String?;
            });
          },
          onError: (Object error) {
            if (!mounted) return;

            setState(() {
              _memberRole = null;
            });
          },
        );
  }

  @override
  void dispose() {
    _membershipSubscription?.cancel();
    super.dispose();
  }

  String _errorMessage(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    return error.toString();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Reuasable confirmation dialog method:
  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
  }) async {
    if (!mounted) return false;

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // Reusable method for execution:
  Future<void> _runAction(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await action();

      if (successMessage != null) {
        _showMessage(successMessage);
      }
    } catch (error) {
      _showMessage(_errorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Method for opening Grocery Item add/edit screen:
  Future<void> _openItemForm({
    GroceryItem? item,
    bool addExisting = false,
  }) async {
    if (_isSaving) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GroceryItemFormScreen(
          householdID: widget.householdID,
          groceryListID: widget.groceryListID,
          item: item,
          addExisting: addExisting,
        ),
      ),
    );
  }

  // Method for quick-changing quantity:
  Future<int?> _askQuantity({
    required int currentQuantity,
    required bool allowZero,
    String title = 'Change Quantity',
  }) async {
    final controller = TextEditingController(text: '$currentQuantity');

    try {
      return await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Quantity',
                helperText: allowZero
                    ? 'Enter 0 to purchase or delete the item.'
                    : 'Enter a quantity greater than 0.',
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final quantity = int.tryParse(controller.text.trim());

                  if (quantity == null ||
                      quantity < 0 ||
                      (!allowZero && quantity == 0)) {
                    return;
                  }

                  Navigator.pop(dialogContext, quantity);
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      );
    } finally {
      Future<void>.delayed(
        const Duration(milliseconds: 350),
        controller.dispose,
      );
    }
  }

  // Method for marking an item as 'purchased':
  Future<void> _markPurchased(
    GroceryList list,
    GroceryItem item,
    List<GroceryItem> allItems,
  ) async {
    if (_isSaving || list.isComplete || item.isPurchased) {
      return;
    }

    final remainingCount = allItems
        .where((groceryItem) => !groceryItem.isPurchased)
        .length;

    final isFinalItem = remainingCount == 1;

    // If it's the final item in the list, the list will be marked 'compelte':
    final message = isFinalItem
        ? 'Purchasing ${item.groceryItemName} will also '
              'complete ${list.groceryListName}. Continue?'
        : 'Mark ${item.groceryItemName} as purchased?';

    final confirmed = await _confirm(
      title: 'Purchase Item',
      message: message,
      confirmLabel: 'Purchase',
    );

    if (!confirmed) return;

    await _runAction(
      () => _groceryService.markItemPurchased(
        householdID: widget.householdID,
        groceryListID: widget.groceryListID,
        groceryItemID: item.groceryItemID,
      ),
      successMessage: 'Item marked as purchased.',
    );
  }

  // Method for marking an item as 'unpurchased':
  Future<void> _markUnpurchased(GroceryList list, GroceryItem item) async {
    if (_isSaving || !item.isPurchased) return;

    // If all items are purchased, 'unpurchasing' one will reopen the list
    if (list.isComplete) {
      final confirmed = await _confirm(
        title: 'Reopen Grocery List?',
        message:
            'Marking this item as unpurchased '
            'will reopen ${list.groceryListName}. '
            'Previously purchased inventory will not '
            'be subtracted from Pantry or Stuff.',
        confirmLabel: 'Yes',
      );

      if (!confirmed) return;
    }

    final suggestedQuantity = item.groceryItemPurchasedQuantity > 0
        ? item.groceryItemPurchasedQuantity
        : 1;

    final quantity = await _askQuantity(
      currentQuantity: suggestedQuantity,
      allowZero: false,
      title: 'New Shopping Quantity',
    );

    if (quantity == null) return;

    await _runAction(
      () => _groceryService.markItemUnpurchased(
        householdID: widget.householdID,
        groceryListID: widget.groceryListID,
        groceryItemID: item.groceryItemID,
        quantity: quantity,
      ),
      successMessage: 'Item marked as unpurchased.',
    );
  }

  // Method for deleting an item:
  Future<void> _deleteItem(GroceryItem item) async {
    if (_isSaving) return;

    final confirmed = await _confirm(
      title: 'Delete Grocery Item?',
      message:
          'Delete ${item.groceryItemName} '
          'from this Grocery List?',
      confirmLabel: 'Delete',
    );

    if (!confirmed) return;

    await _runAction(
      () => _groceryService.deleteItem(
        householdID: widget.householdID,
        groceryListID: widget.groceryListID,
        groceryItemID: item.groceryItemID,
      ),
      successMessage: 'Grocery Item deleted.',
    );
  }

  // Method for updating an item's quantity:
  Future<void> _changeQuantity(
    GroceryList list,
    GroceryItem item,
    List<GroceryItem> allItems,
  ) async {
    if (_isSaving || list.isComplete || item.isPurchased) {
      return;
    }

    final quantity = await _askQuantity(
      currentQuantity: item.groceryItemQuantity,
      allowZero: true,
    );

    if (!mounted || quantity == null) return;

    if (quantity == 0) {
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Quantity is Zero'),
            content: const Text(
              'Would you like to mark this item as purcahsed '
              'or delete it from the list?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, 'delete');
                },
                child: const Text('Delete'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, 'purchase');
                },
                child: const Text('Purchase'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      if (choice == 'purchase') {
        await _markPurchased(list, item, allItems);
      } else if (choice == 'delete') {
        await _deleteItem(item);
      }

      return;
    }

    await _runAction(
      () => _groceryService.updateItemQuantity(
        householdID: widget.householdID,
        groceryListID: widget.groceryListID,
        groceryItemID: item.groceryItemID,
        quantity: quantity,
      ),
      successMessage: 'Quantity updated.',
    );
  }

  // Method for showing item options submenu:
  Future<void> _showItemOptions(
    GroceryList list,
    GroceryItem item,
    List<GroceryItem> allItems,
  ) async {
    if (_isSaving) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final canEdit = !list.isComplete && !item.isPurchased;
        final canDelete = !list.isComplete;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  item.isPurchased ? Icons.undo : Icons.check_circle_outline,
                ),
                title: Text(
                  item.isPurchased
                      ? 'Mark as Unpurchased'
                      : 'Mark as Purchased',
                ),
                enabled: item.isPurchased || !list.isComplete,
                onTap: () {
                  Navigator.pop(sheetContext);

                  if (item.isPurchased) {
                    _markUnpurchased(list, item);
                  } else {
                    _markPurchased(list, item, allItems);
                  }
                },
              ),

              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Item'),
                enabled: canEdit,
                onTap: canEdit
                    ? () {
                        Navigator.pop(sheetContext);
                        _openItemForm(item: item);
                      }
                    : null,
              ),

              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete Item'),
                enabled: canDelete,
                onTap: canDelete
                    ? () {
                        Navigator.pop(sheetContext);
                        _deleteItem(item);
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  // Method for showing the options for adding a new Grocery Item:
  Future<void> _showAddOptions() async {
    if (_isSaving) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Create New Item'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openItemForm();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Add Existing Item'),
                subtitle: const Text('From Pantry or Stuff'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openItemForm(addExisting: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Method for starting a Shopping Trip
  Future<void> _startShopping(GroceryList list, List<GroceryItem> items) async {
    if (_isSaving || list.isComplete || items.isEmpty) {
      return;
    }

    final confirmed = await _confirm(
      title: 'Shopping Trip',
      message: 'Start shopping for ${list.groceryListName}?',
      confirmLabel: 'Yes',
    );

    if (!confirmed || !mounted) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ShoppingScreen(
          householdID: widget.householdID,
          groceryListID: widget.groceryListID,
          listName: list.groceryListName,
        ),
      ),
    );
  }

  // Sorting method:
  List<GroceryItem> _sortItems(List<GroceryItem> items) {
    final sorted = List<GroceryItem>.from(items);

    sorted.sort((a, b) {
      final int comparison;

      switch (_sort) {
        case GroceryItemSort.name:
          comparison = a.groceryItemName.toLowerCase().compareTo(
            b.groceryItemName.toLowerCase(),
          );
          break;

        case GroceryItemSort.type:
          comparison = a.groceryItemType.toLowerCase().compareTo(
            b.groceryItemType.toLowerCase(),
          );
          break;

        case GroceryItemSort.quantity:
          comparison = a.groceryItemQuantity.compareTo(b.groceryItemQuantity);
          break;
      }

      if (comparison != 0) {
        return _ascending ? comparison : -comparison;
      }

      return a.groceryItemID.compareTo(b.groceryItemID);
    });

    return sorted;
  }

  // Actual UI for Grocery Items screen:
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<GroceryList?>(
      stream: _listStream,
      builder: (context, listSnapshot) {
        if (listSnapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Unable to access this Grocery List.')),
          );
        }

        if (listSnapshot.connectionState == ConnectionState.waiting &&
            !listSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final list = listSnapshot.data;

        if (list == null) {
          return const Scaffold(
            body: Center(child: Text('This Grocery List no longer exists.')),
          );
        }

        return StreamBuilder<List<GroceryItem>>(
          stream: _itemsStream,
          builder: (context, itemsSnapshot) {
            final allItems = itemsSnapshot.data ?? [];
            final sortedItems = _sortItems(allItems);

            return Scaffold(
              appBar: AppBar(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                title: Text(list.groceryListName),
                actions: [
                  PopupMenuButton<GroceryItemSort>(
                    icon: const Icon(Icons.sort),
                    tooltip: 'Sort Grocery Items',
                    onSelected: (selectedSort) {
                      setState(() {
                        if (_sort == selectedSort) {
                          _ascending = !_ascending;
                        } else {
                          _sort = selectedSort;
                          _ascending = true;
                        }
                      });
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: GroceryItemSort.name,
                        child: Text('Name'),
                      ),
                      PopupMenuItem(
                        value: GroceryItemSort.type,
                        child: Text('Type'),
                      ),
                      PopupMenuItem(
                        value: GroceryItemSort.quantity,
                        child: Text('Quantity'),
                      ),
                    ],
                  ),
                ],
              ),
              body: Column(
                children: [
                  if (_isSaving) const LinearProgressIndicator(),

                  if (list.isComplete)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: AppColors.okBg,
                      child: const Text(
                        'This Grocery List is complete. '
                        'Reopen it to add or edit items.',
                      ),
                    ),

                  Expanded(
                    child: _buildItemList(
                      itemsSnapshot,
                      sortedItems,
                      list,
                      allItems,
                    ),
                  ),

                  if (_canEditListItems(list) &&
                      !list.isComplete &&
                      allItems.isNotEmpty)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(80, 8, 80, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () => _startShopping(list, allItems),
                            icon: const Icon(Icons.shopping_cart_checkout),
                            label: const Text('Shop This List'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              floatingActionButton: list.isComplete || !_canEditListItems(list)
                  ? null
                  : FloatingActionButton(
                      onPressed: _isSaving ? null : _showAddOptions,
                      backgroundColor: AppColors.forest,
                      foregroundColor: Colors.white,
                      child: const Icon(Icons.add),
                    ),
            );
          },
        );
      },
    );
  }

  // Method for displaying Grocery Items:
  Widget _buildItemList(
    AsyncSnapshot<List<GroceryItem>> snapshot,
    List<GroceryItem> sortedItems,
    GroceryList list,
    List<GroceryItem> allItems,
  ) {
    if (snapshot.hasError) {
      return const Center(
        child: Text(
          'Unable to load Grocery Items. '
          'Please check your connection or permissions.',
        ),
      );
    }

    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (sortedItems.isEmpty) {
      return const Center(
        child: Text(
          'This list is looking a bit empty...',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: sortedItems.length,
      itemBuilder: (context, index) {
        final item = sortedItems[index];

        return GroceryItemRowCard(
          item: item,
          onOptions: _canEditListItems(list) && !_isSaving
              ? () => _showItemOptions(list, item, allItems)
              : null,
          onQuantity: _canEditListItems(list) && !list.isComplete && !_isSaving
              ? () => _changeQuantity(list, item, allItems)
              : null,
        );
      },
    );
  }
}
