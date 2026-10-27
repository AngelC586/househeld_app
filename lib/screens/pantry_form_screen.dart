import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme/app_theme.dart';

class PantryFormScreen extends StatefulWidget {
  const PantryFormScreen({super.key, this.existingItem});

  final PantryItem? existingItem;

  bool get isEditing => existingItem != null;

  @override
  State<PantryFormScreen> createState() => _PantryFormScreenState();
}

class _PantryFormScreenState extends State<PantryFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _descriptionController;

  late String _selectedType;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final item = widget.existingItem;

    _nameController = TextEditingController(text: item?.foodName ?? '');

    _quantityController = TextEditingController(
      text: '${item?.foodQuantity ?? 1}',
    );

    _descriptionController = TextEditingController(
      text: item?.foodDescription ?? '',
    );

    _selectedType = item?.foodType ?? pantryFoodTypes.first;
  }

  // Resource cleanup:
  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim());

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a name for the item.';
      });
      return;
    }

    if (quantity == null || quantity < 0) {
      setState(() {
        _errorMessage = 'Quantity must be 0 or greater.';
      });
      return;
    }

    // When editing an item, this fills in the fields with the old data:
    final result = widget.isEditing
        ? widget.existingItem!.copyWith(
            foodName: name,
            foodType: _selectedType,
            foodQuantity: quantity,
            foodDescription: description,
          )
        : PantryItem(
            foodItemID: '',
            foodName: name,
            foodType: _selectedType,
            foodQuantity: quantity,
            foodStockStatus: PantryItem.stockStatusForQuantity(quantity),
            foodDescription: description,
          );

    Navigator.pop(context, result);
  }

  // Add/Edit Pantry Item UI:
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.forestDeep,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    widget.isEditing ? 'Edit Pantry Item' : 'Add Pantry Item',
                    style: AppText.heading.copyWith(fontSize: 20),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Text('Name', style: AppText.label),
              const SizedBox(height: 6),

              TextField(
                controller: _nameController,
                autofocus: !widget.isEditing,
                decoration: const InputDecoration(
                  hintText: 'e.g. Milk',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 18),

              Text('Type', style: AppText.label),
              const SizedBox(height: 6),

              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: pantryFoodTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedType = value;
                    });
                  }
                },
              ),

              const SizedBox(height: 18),

              Text('Quantity', style: AppText.label),
              const SizedBox(height: 6),

              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: 'How many?',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 18),

              Text('Description (Optional)', style: AppText.label),
              const SizedBox(height: 6),

              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. brand or location',
                  border: OutlineInputBorder(),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],

              const Spacer(),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(widget.isEditing ? 'Update' : 'Add'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
