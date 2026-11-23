import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

// This widget is for quickly adding a new task from the home screen.

// It doesn't create the task itself, it just displays the pop-up,
// collects new task information, and returns it for the home screen.

class TaskQuickAddResult {
  const TaskQuickAddResult({
    required this.name,
    required this.description,
    required this.assignedMemberIDs,
  });

  final String name;
  final String description;
  final List<String> assignedMemberIDs;
}

Future<TaskQuickAddResult?> showTaskQuickAddDialog(
  BuildContext context, {
  required List<HouseholdMember> members,
}) {
  return showDialog<TaskQuickAddResult>(
    context: context,
    builder: (_) => _TaskQuickAddDialog(members: members),
  );
}

class _TaskQuickAddDialog extends StatefulWidget {
  const _TaskQuickAddDialog({required this.members});

  final List<HouseholdMember> members;

  @override
  State<_TaskQuickAddDialog> createState() => _TaskQuickAddDialogState();
}

class _TaskQuickAddDialogState extends State<_TaskQuickAddDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final Set<String> _selectedMemberIDs = {};

  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _memberName(String memberID) {
    for (final member in widget.members) {
      if (member.userID == memberID) {
        final name = member.displayName.trim();
        return name.isEmpty ? 'Household Member' : name;
      }
    }
    return 'Unknown Member';
  }

  String get _assignmentLabel {
    if (_selectedMemberIDs.isEmpty) return 'Anyone';

    final names = _selectedMemberIDs.map(_memberName).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return names.join(', ');
  }

  Future<void> _pickAssignees() async {
    final selected = Set<String>.from(_selectedMemberIDs);
    String? selectionError;

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) {
          return AlertDialog(
            title: const Text('Assigned To'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Select up to 8 household members. '
                      'Leaving everyone unchecked assigns '
                      'the task to Anyone.',
                      style: AppText.bodySoft,
                    ),

                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          updateDialog(() {
                            selected.clear();
                            selectionError = null;
                          });
                        },
                        child: const Text('Assign to Anyone'),
                      ),
                    ),

                    for (final member in widget.members)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          member.displayName.trim().isEmpty
                              ? 'Household Member'
                              : member.displayName,
                        ),
                        value: selected.contains(member.userID),
                        onChanged: (checked) {
                          updateDialog(() {
                            if (checked == true) {
                              if (selected.length >= 8) {
                                selectionError =
                                    'You can select up to 8 people.';
                                return;
                              }
                              selected.add(member.userID);
                            } else {
                              selected.remove(member.userID);
                            }

                            selectionError = null;
                          });
                        },
                      ),

                    if (selectionError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        selectionError!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      ),
                    ],
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
          );
        },
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedMemberIDs
        ..clear()
        ..addAll(result);
    });
  }

  void _submit() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter a task name.');
      return;
    }

    if (name.length > 200) {
      setState(() {
        _nameError = 'Task names cannot exceed 200 characters.';
      });
      return;
    }

    Navigator.pop(
      context,
      TaskQuickAddResult(
        name: name,
        description: _descriptionController.text.trim(),
        assignedMemberIDs: _selectedMemberIDs.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Task'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NAME', style: AppText.label),

              const SizedBox(height: 6),

              TextField(
                controller: _nameController,
                autofocus: true,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'e.g. Water the plants',
                  border: const OutlineInputBorder(),
                  errorText: _nameError,
                ),
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() => _nameError = null);
                  }
                },
              ),

              const SizedBox(height: 12),

              Text('DESCRIPTION (OPTIONAL)', style: AppText.label),

              const SizedBox(height: 6),

              TextField(
                controller: _descriptionController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Describe the task...',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              Text('ASSIGNED TO', style: AppText.label),

              const SizedBox(height: 6),

              InkWell(
                onTap: _pickAssignees,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    _assignmentLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _selectedMemberIDs.isEmpty
                    ? 'Anyone in the household can see '
                          'and complete this task.'
                    : 'Visible to the creator, selected '
                          'members, and household Managers.',
                style: AppText.bodySoft,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create Task')),
      ],
    );
  }
}
