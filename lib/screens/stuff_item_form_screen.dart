import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

class StuffItemFormScreen extends StatefulWidget {
  const StuffItemFormScreen({
    super.key,
    required this.currentUserID,
    required this.listType,
    this.existingItem,
  });

  final String currentUserID;
  final String listType;
  final StuffItem? existingItem;

  bool get isEditing => existingItem != null;

  @override
  State<StuffItemFormScreen> createState() => _StuffItemFormScreenState();
}

class _StuffItemFormScreenState extends State<StuffItemFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  late String _status;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    final item = widget.existingItem;

    _nameController = TextEditingController(
      text: item?.itemName ?? '',
    );

    _descriptionController = TextEditingController(
      text: item?.itemDescription ?? '',
    );

    _status = item?.itemStatus ?? 'available';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty || name.length > 200) {
      setState(() {
        _errorMessage = 'Item names must be between 1 and 200 characters.';
      });
      return;
    }

    final result = widget.isEditing
        ? widget.existingItem!.copyWith(
            itemName: name,
            itemDescription: description,
            itemStatus: _status,
          )
        : StuffItem(
            itemId: '',
            itemName: name,
            itemDescription: description,
            itemStatus: _status,
            listType: widget.listType,
            ownerMemberID:
                widget.listType == 'private' ? widget.currentUserID : '',
          );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final listLabel =
        widget.listType == 'private' ? 'Personal Item' : 'Household Item';

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
                  Expanded(
                    child: Text(
                      widget.isEditing
                          ? 'Edit $listLabel'
                          : 'Add $listLabel',
                      style: AppText.heading.copyWith(fontSize: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name', style: AppText.label),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameController,
                        autofocus: !widget.isEditing,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Dish soap',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('Status', style: AppText.label),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'available',
                            child: Text('Available'),
                          ),
                          DropdownMenuItem(
                            value: 'low',
                            child: Text('Low'),
                          ),
                          DropdownMenuItem(
                            value: 'out_of_stock',
                            child: Text('Out of Stock'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _status = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Description (Optional)',
                        style: AppText.label,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'e.g. brand or location',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
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
              ),
              const SizedBox(height: 16),
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