import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/grocery_service.dart';
import '../services/pantry_service.dart';
import '../services/stuff_service.dart';

// UI and logic for adding/editing a Grocery Item:
class GroceryItemFormScreen extends StatefulWidget {
  const GroceryItemFormScreen({
    super.key,
    required this.householdID,
    required this.groceryListID,
    this.item,
    this.addExisting = false,
  });

  final String householdID;
  final String groceryListID;
  final GroceryItem? item;
  final bool addExisting;

  @override
  State<GroceryItemFormScreen> createState() => _GroceryItemFormScreenState();
}

class _GroceryItemFormScreenState extends State<GroceryItemFormScreen> {
  final GroceryService _groceryService = GroceryService();
  final PantryService _pantryService = PantryService();
  final StuffService _stuffService = StuffService();

  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _quantityController;

  late final Stream<List<PantryItem>> _pantryStream;
  late final Stream<List<StuffItem>> _stuffStream;

  final Set<String> _selectedPantryIDs = <String>{};
  final Set<String> _selectedStuffIDs = <String>{};

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.item != null;

  bool get _isAddingExisting => widget.addExisting;

  @override
  void initState() {
    super.initState();

    final item = widget.item;

    _nameController = TextEditingController(text: item?.groceryItemName ?? '');

    _typeController = TextEditingController(text: item?.groceryItemType ?? '');

    _descriptionController = TextEditingController(
      text: item?.groceryItemDescription ?? '',
    );

    _quantityController = TextEditingController(
      text: '${item?.groceryItemQuantity ?? 1}',
    );

    _pantryStream = _pantryService.watchPantryItems(widget.householdID);

    _stuffStream = _stuffService.watchItems(
      householdID: widget.householdID,
      listType: 'household',
    );
  }

  // Resource clean-up:
  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();

    super.dispose();
  }

  String get _screenTitle {
    if (_isAddingExisting) {
      return 'Add Existing Items';
    }

    if (_isEditing) {
      return 'Edit Grocery Item';
    }

    return 'Add Grocery Item';
  }

  String get _buttonLabel {
    if (_isSaving) {
      return 'Saving...';
    }

    if (_isEditing) {
      return 'Update';
    }

    if (_isAddingExisting) {
      return 'Add Selected Items';
    }

    return 'Add';
  }

  String _getErrorMessage(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    return error.toString();
  }

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      _errorMessage = message;
    });
  }

  // Method for adding/saving an item to the list:
  Future<void> _save() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    final type = _typeController.text.trim();
    final description = _descriptionController.text.trim();

    final quantity = int.tryParse(_quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      _showError('Please enter a quantity greater than 0.');
      return;
    }

    if (_isAddingExisting) {
      if (_selectedPantryIDs.isEmpty && _selectedStuffIDs.isEmpty) {
        _showError('Please select at least one Pantry or Household item.');
        return;
      }
    } else {
      if (name.isEmpty || name.length > 200) {
        _showError('Item names must be between 1 and 200 characters.');
        return;
      }

      if (type.isEmpty) {
        _showError('Please enter an item type.');
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_isAddingExisting) {
        await _addExistingItems(quantity);
      } else if (_isEditing) {
        await _groceryService.updateItem(
          householdID: widget.householdID,
          groceryListID: widget.groceryListID,
          groceryItemID: widget.item!.groceryItemID,
          name: name,
          type: type,
          description: description,
          quantity: quantity,
        );
      } else {
        await _groceryService.createItem(
          householdID: widget.householdID,
          groceryListID: widget.groceryListID,
          name: name,
          type: type,
          description: description,
          quantity: quantity,
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (error) {
      _showError(_getErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Helper for adding existing Pantry or Stuff Items:
  Future<void> _addExistingItems(int quantity) async {
    for (final foodItemID in _selectedPantryIDs.toList()) {
      await _groceryService.addPantryItem(
        householdID: widget.householdID,
        groceryListID: widget.groceryListID,
        foodItemID: foodItemID,
        quantity: quantity,
      );

      if (mounted) {
        setState(() {
          _selectedPantryIDs.remove(foodItemID);
        });
      }
    }

    for (final stuffItemID in _selectedStuffIDs.toList()) {
      await _groceryService.addHouseholdStuffItem(
        householdID: widget.householdID,
        groceryListID: widget.groceryListID,
        stuffItemID: stuffItemID,
        quantity: quantity,
      );

      if (mounted) {
        setState(() {
          _selectedStuffIDs.remove(stuffItemID);
        });
      }
    }
  }

  // Fillable fields UI:
  Widget _buildManualFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          enabled: !_isSaving,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Item Name',
            hintText: 'e.g. Milk, Ibuprofen, Toothpase, etc.',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 16),

        TextField(
          controller: _typeController,
          enabled: !_isSaving,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Item Type',
            hintText: 'e.g. Food, Medicine, Toiletry, etc.',
            border: OutlineInputBorder(),
          ),
        ),

        const SizedBox(height: 16),

        TextField(
          controller: _descriptionController,
          enabled: !_isSaving,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'e.g. Brand, Size, or other information',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  // UI for adding existing Patnry Items:
  Widget _buildPantrySelection() {
    return ExpansionTile(
      title: const Text('Pantry Items'),
      leading: const Icon(Icons.kitchen_outlined),
      initiallyExpanded: true,
      children: [
        StreamBuilder<List<PantryItem>>(
          stream: _pantryStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const ListTile(
                title: Text('Unable to load Pantry items.'),
              );
            }

            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final items = List<PantryItem>.from(snapshot.data!)
              ..sort(
                (a, b) => a.foodName.toLowerCase().compareTo(
                  b.foodName.toLowerCase(),
                ),
              );

            if (items.isEmpty) {
              return const ListTile(title: Text('No Pantry items available.'));
            }

            return Column(
              children: [
                for (final item in items)
                  CheckboxListTile(
                    title: Text(item.foodName),
                    subtitle: Text(item.foodType),
                    value: _selectedPantryIDs.contains(item.foodItemID),
                    onChanged: _isSaving
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedPantryIDs.add(item.foodItemID);
                              } else {
                                _selectedPantryIDs.remove(item.foodItemID);
                              }
                            });
                          },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  // UI for adding existing Stuff Items:
  Widget _buildStuffSelection() {
    return ExpansionTile(
      title: const Text('Household Items'),
      leading: const Icon(Icons.inventory_2_outlined),
      children: [
        StreamBuilder<List<StuffItem>>(
          stream: _stuffStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const ListTile(
                title: Text('Unable to load Household items.'),
              );
            }

            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final items = List<StuffItem>.from(snapshot.data!)
              ..sort(
                (a, b) => a.itemName.toLowerCase().compareTo(
                  b.itemName.toLowerCase(),
                ),
              );

            if (items.isEmpty) {
              return const ListTile(
                title: Text('No Household items available.'),
              );
            }

            return Column(
              children: [
                for (final item in items)
                  CheckboxListTile(
                    title: Text(item.itemName),
                    subtitle: item.itemDescription.isEmpty
                        ? null
                        : Text(item.itemDescription),
                    value: _selectedStuffIDs.contains(item.itemId),
                    onChanged: _isSaving
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedStuffIDs.add(item.itemId);
                              } else {
                                _selectedStuffIDs.remove(item.itemId);
                              }
                            });
                          },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  // Method for selecting existing Items:
  Widget _buildExistingItemFields() {
    final selectedCount = _selectedPantryIDs.length + _selectedStuffIDs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select items to add to your Grocery List.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),

        const SizedBox(height: 12),

        Text(
          '$selectedCount item(s) selected',
          style: Theme.of(context).textTheme.titleSmall,
        ),

        const SizedBox(height: 12),

        _buildPantrySelection(),

        _buildStuffSelection(),

        const SizedBox(height: 16),
      ],
    );
  }

  // UI for the quantity field:
  Widget _buildQuantityField() {
    return TextField(
      controller: _quantityController,
      enabled: !_isSaving,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: _isAddingExisting ? 'Quantity Per Item' : 'Quantity',
        hintText: 'Enter a quantity',
        border: const OutlineInputBorder(),
      ),
    );
  }

  // Actual form screen UI:
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_screenTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_isAddingExisting)
                    _buildExistingItemFields()
                  else
                    _buildManualFields(),

                  _buildQuantityField(),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),

                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_buttonLabel),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
