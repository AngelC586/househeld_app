import 'package:flutter/material.dart';

import '../models.dart';
import '../services/grocery_service.dart';
import '../services/household_service.dart';
import '../theme/app_theme.dart';

// UI and logic for creating/editing a Grocery List:
class GroceryListFormScreen extends StatefulWidget {
  const GroceryListFormScreen({
    super.key,
    required this.householdID,
    this.existingList,
    this.copyFromListID,
  });

  final String householdID;
  final GroceryList? existingList;
  final String? copyFromListID;

  @override
  State<GroceryListFormScreen> createState() => _GroceryListFormScreenState();
}

class _GroceryListFormScreenState extends State<GroceryListFormScreen> {
  final _grocery = GroceryService();
  final _households = HouseholdService();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final Stream<List<HouseholdMember>> _members;
  late String _visibility;
  late Set<String> _selected;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existingList != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.existingList?.groceryListName ?? '',
    );
    _description = TextEditingController(
      text: widget.existingList?.groceryListDescription ?? '',
    );
    _visibility = widget.existingList?.groceryListVisibility ?? 'restricted';
    _selected = widget.existingList?.visibleMemberIDs.toSet() ?? <String>{};
    _members = _households.watchMembers(widget.householdID);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _selectMembers() async {
    final snapshot = await _members.first;
    if (!mounted) return;
    final selected = Set<String>.from(_selected);
    String? error;
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, change) => AlertDialog(
          title: const Text('Who can view this list?'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select up to 8 household members. The creator always has access.',
                  ),
                  for (final member in snapshot)
                    CheckboxListTile(
                      title: Text(
                        member.displayName.isEmpty
                            ? member.userID
                            : member.displayName,
                      ),
                      value: selected.contains(member.userID),
                      onChanged: (value) => change(() {
                        if (value == true &&
                            selected.length >= 8 &&
                            !selected.contains(member.userID)) {
                          error = 'Select no more than 8 members.';
                          return;
                        }
                        value == true
                            ? selected.add(member.userID)
                            : selected.remove(member.userID);
                        error = null;
                      }),
                    ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: AppColors.clay)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) setState(() => _selected = result);
  }

  Future<void> _submit() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty || name.length > 200) {
      setState(() => _error = 'Enter a name between 1 and 200 characters.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final members = _visibility == 'shared' ? <String>[] : _selected.toList();
      String listID;
      if (_editing) {
        await _grocery.updateList(
          householdID: widget.householdID,
          list: widget.existingList!,
          name: name,
          description: _description.text,
          visibility: _visibility,
          visibleMemberIDs: members,
        );
        listID = widget.existingList!.groceryListID;
      } else if (widget.copyFromListID != null) {
        listID = await _grocery.copyList(
          householdID: widget.householdID,
          sourceListID: widget.copyFromListID!,
          name: name,
          description: _description.text,
          visibility: _visibility,
          visibleMemberIDs: members,
        );
      } else {
        listID = await _grocery.createList(
          householdID: widget.householdID,
          name: name,
          description: _description.text,
          visibility: _visibility,
          visibleMemberIDs: members,
        );
      }
      if (mounted) Navigator.pop(context, listID);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'Unable to save list. Check access and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit List' : 'Create List')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    TextField(
                      controller: _name,
                      autofocus: !_editing,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _description,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _visibility,
                      decoration: const InputDecoration(
                        labelText: 'Who can view this list?',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'restricted',
                          child: Text('Selected people (private by default)'),
                        ),
                        DropdownMenuItem(
                          value: 'shared',
                          child: Text('Anyone in the household'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _visibility = value);
                              }
                            },
                    ),
                    if (_visibility == 'restricted')
                      ListTile(
                        title: Text(
                          _selected.isEmpty
                              ? 'Only you'
                              : '${_selected.length} selected members',
                        ),
                        subtitle: const Text(
                          'Choose members who can also view this list',
                        ),
                        trailing: const Icon(Icons.people_outline),
                        onTap: _saving ? null : _selectMembers,
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.clay),
                        ),
                      ),
                  ],
                ),
              ),
              if (_saving) const LinearProgressIndicator(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(_editing ? 'Update' : 'Create'),
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
