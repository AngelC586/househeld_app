import 'package:flutter/material.dart';

import '../models.dart';
import '../services/grocery_service.dart';
import '../theme/app_theme.dart';

enum ShoppingItemSort { name, type, quantity }

// Shopping screen class:
class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({
    super.key,
    required this.householdID,
    required this.groceryListID,
    required this.listName,
  });

  final String householdID;
  final String groceryListID;
  final String listName;

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

// State controlling class:
class _ShoppingScreenState extends State<ShoppingScreen> {
  final GroceryService _groceryService = GroceryService();

  late final Stream<List<GroceryItem>> _itemsStream;

  final Set<String> _checkedIDs = <String>{};

  ShoppingItemSort _sort = ShoppingItemSort.name;

  bool _ascending = true;
  bool _isSaving = false;
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();

    _itemsStream = _groceryService.watchItems(
      householdID: widget.householdID,
      groceryListID: widget.groceryListID,
    );
  }

  String _errorMessage(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    return error.toString();
  }

  void _showError(Object error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
  }

  // Sorting items method:
  List<GroceryItem> _sortItems(List<GroceryItem> items) {
    final sorted = List<GroceryItem>.from(items);

    sorted.sort((a, b) {
      final int comparison;

      switch (_sort) {
        case ShoppingItemSort.name:
          comparison = a.groceryItemName.toLowerCase().compareTo(
            b.groceryItemName.toLowerCase(),
          );
          break;

        case ShoppingItemSort.type:
          comparison = a.groceryItemType.toLowerCase().compareTo(
            b.groceryItemType.toLowerCase(),
          );
          break;

        case ShoppingItemSort.quantity:
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

  // Method for checking which items have been checked off:
  List<String> _newlyCheckedIDs(List<GroceryItem> items) {
    return items
        .where(
          (item) =>
              !item.isPurchased && _checkedIDs.contains(item.groceryItemID),
        )
        .map((item) => item.groceryItemID)
        .toList();
  }

  void _closeScreen() {
    if (!mounted) return;

    setState(() {
      _isLeaving = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  // Method for displaying exit dialogs:
  Future<String?> _showExitOptions({
    required int purchaseCount,
    required List<GroceryItem> uncheckedItems,
  }) {
    final uncheckedNames = uncheckedItems
        .map((item) => item.groceryItemName)
        .join('\n');

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('End Shopping Trip?'),
          content: SingleChildScrollView(
            child: Text(
              purchaseCount == 0
                  ? 'No new items have been checked off. '
                        'Would you like to leave this Shopping Trip?'
                  : uncheckedItems.isEmpty
                  ? 'All items have been checked off! '
                        'Save your $purchaseCount new purchase(s)?'
                  : '$purchaseCount new item(s) will be purchased.\n\n'
                        'But the following items have not been checked off:\n\n'
                        '$uncheckedNames',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, 'cancel');
              },
              child: const Text('Continue Shopping'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, 'discard');
              },
              child: const Text('Leave Without Saving'),
            ),
            if (purchaseCount > 0)
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, 'save');
                },
                child: const Text('Save Purchases'),
              ),
          ],
        );
      },
    );
  }

  // Method for ending a Shopping Trip:
  Future<void> _endShopping(List<GroceryItem> items) async {
    if (_isSaving || _isLeaving) return;

    final selectedIDs = _newlyCheckedIDs(items);

    final uncheckedItems =
        items
            .where(
              (item) =>
                  !item.isPurchased &&
                  !_checkedIDs.contains(item.groceryItemID),
            )
            .toList()
          ..sort(
            (a, b) => a.groceryItemName.toLowerCase().compareTo(
              b.groceryItemName.toLowerCase(),
            ),
          );

    final choice = await _showExitOptions(
      purchaseCount: selectedIDs.length,
      uncheckedItems: uncheckedItems,
    );

    if (!mounted || choice == null || choice == 'cancel') {
      return;
    }

    if (choice == 'discard') {
      _closeScreen();
      return;
    }

    if (choice != 'save' || selectedIDs.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _groceryService.purchaseSelectedItems(
        householdID: widget.householdID,
        groceryListID: widget.groceryListID,
        itemIDs: selectedIDs,
      );

      if (!mounted) return;

      _closeScreen();
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // UI for the Shopping Trip items:
  Widget _buildShoppingItem(GroceryItem item) {
    final isChecked =
        item.isPurchased || _checkedIDs.contains(item.groceryItemID);

    final quantity = item.isPurchased
        ? item.groceryItemPurchasedQuantity
        : item.groceryItemQuantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: item.isPurchased ? AppColors.surfaceSunken : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: CheckboxListTile(
        value: isChecked,
        enabled: !item.isPurchased && !_isSaving,
        activeColor: AppColors.forest,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: item.isPurchased || _isSaving
            ? null
            : (checked) {
                setState(() {
                  if (checked == true) {
                    _checkedIDs.add(item.groceryItemID);
                  } else {
                    _checkedIDs.remove(item.groceryItemID);
                  }
                });
              },
        title: Text(
          item.groceryItemName,
          style: AppText.body.copyWith(
            fontWeight: FontWeight.w700,
            color: item.isPurchased ? AppColors.inkSoft : AppColors.ink,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(item.groceryItemType, style: AppText.bodySoft),
            if (item.groceryItemDescription.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.groceryItemDescription, style: AppText.bodySoft),
            ],
            if (item.isPurchased) ...[
              const SizedBox(height: 4),
              const Text(
                'Already Purchased',
                style: TextStyle(
                  color: AppColors.forest,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        secondary: Text(
          '$quantity',
          style: AppText.body.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // Actual Shopping Trip UI:
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GroceryItem>>(
      stream: _itemsStream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        final sortedItems = _sortItems(items);

        final selectedCount = _newlyCheckedIDs(items).length;

        final remainingCount = items.where((item) => !item.isPurchased).length;

        return PopScope(
          canPop: _isLeaving && !_isSaving,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop || _isSaving || _isLeaving) {
              return;
            }

            _endShopping(items);
          },
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              title: Text('Shopping: ${widget.listName}'),
              actions: [
                PopupMenuButton<ShoppingItemSort>(
                  icon: const Icon(Icons.sort),
                  tooltip: 'Sort Shopping Items',
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
                      value: ShoppingItemSort.name,
                      child: Text('Name'),
                    ),
                    PopupMenuItem(
                      value: ShoppingItemSort.type,
                      child: Text('Type'),
                    ),
                    PopupMenuItem(
                      value: ShoppingItemSort.quantity,
                      child: Text('Quantity'),
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                if (_isSaving) const LinearProgressIndicator(),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$selectedCount items marked',
                        style: AppText.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$remainingCount remaining',
                        style: AppText.bodySoft,
                      ),
                    ],
                  ),
                ),

                Expanded(child: _buildItemList(snapshot, sortedItems)),
              ],
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: _isSaving || !snapshot.hasData
                      ? null
                      : () => _endShopping(items),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isSaving ? 'Saving Purchases...' : 'End Shopping Trip',
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Method for displaying Shopping Trip items:
  Widget _buildItemList(
    AsyncSnapshot<List<GroceryItem>> snapshot,
    List<GroceryItem> items,
  ) {
    if (snapshot.hasError) {
      return const Center(
        child: Text(
          'Unable to load Shopping Items. '
          'Please check your connection or permissions.',
        ),
      );
    }

    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return const Center(child: Text('This Grocery List has no items.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildShoppingItem(items[index]);
      },
    );
  }
}
