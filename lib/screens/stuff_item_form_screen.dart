import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';


class StuffItemFormScreen extends StatefulWidget {
  const StuffItemFormScreen({
    super.key,
    required this.currentUserID,
    required this.listType, // 'household' | 'private'
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existingItem?.itemName ?? '');
    _descriptionController =
        TextEditingController(text: widget.existingItem?.itemDescription ?? '');
    _status = widget.existingItem?.itemStatus ?? 'available';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String get _listLabel => widget.listType == 'household' ? 'Household Item' : 'Personal Item';

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final description = _descriptionController.text.trim();

    final result = widget.isEditing
        ? widget.existingItem!.copyWith(
            itemName: name,
            itemDescription: description,
            itemStatus: _status,
          )
        : StuffItem(
            itemId: 'local-${DateTime.now().millisecondsSinceEpoch}',
            itemName: name,
            itemDescription: description,
            itemStatus: _status,
            listType: widget.listType,
            ownerMemberID: widget.currentUserID,
          );

    Navigator.pop(context, result);
  }

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
                    icon: const Icon(Icons.arrow_back, color: AppColors.forestDeep),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    widget.isEditing ? 'Edit $_listLabel' : 'Add $_listLabel',
                    style: AppText.heading.copyWith(fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Item Name', style: AppText.label),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                autofocus: !widget.isEditing,
                decoration: InputDecoration(
                  hintText: 'e.g. Dish soap',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Item Description (optional)', style: AppText.label),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: ' ',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Item Status (optional)', style: AppText.label),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'available', child: Text('Available')),
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'out_of_stock', child: Text('Out of Stock')),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'available'),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      child: Text('Cancel', style: AppText.body),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(widget.isEditing ? 'Save' : 'Add'),
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