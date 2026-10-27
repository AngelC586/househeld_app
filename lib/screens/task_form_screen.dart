import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';


class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.currentUserID,
    this.existingTask,
    this.members = const [],
  });

  final String currentUserID;
  final HouseholdTask? existingTask;
  final List<HouseholdMember> members;

  bool get isEditing => existingTask != null;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _selectedAssignees = {
      ...?widget.existingTask?.taskAssignedMemberIDs,
    };
    _nameController = TextEditingController(text: widget.existingTask?.taskName ?? '');
    _descriptionController =
        TextEditingController(text: widget.existingTask?.taskDescription ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final description = _descriptionController.text.trim();

    final result = widget.isEditing
        ? widget.existingTask!.copyWith(
            taskName: name,
            taskDescription: description,
            taskAssignedMemberIDs: _canChangeAssignees
                ? _selectedAssignees.toList()
                : widget.existingTask!.taskAssignedMemberIDs,
          )
        : HouseholdTask(
            taskId: 'local-${DateTime.now().millisecondsSinceEpoch}',
            taskName: name,
            taskDescription: description,
            taskStatus: 'pending',
            createdByMemberID: widget.currentUserID,
            taskAssignedMemberIDs: _selectedAssignees.toList(),
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
                    widget.isEditing ? 'Edit Task' : 'Create Task',
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
                decoration: InputDecoration(
                  hintText: 'e.g. Water the plants',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.line),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text('Description (optional)', style: AppText.label),
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
              Text('Assigned to', style: AppText.label),
              const SizedBox(height: 6),
              InkWell(
                onTap: _canChangeAssignees ? _pickAssignees : null,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    enabled: _canChangeAssignees,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    _assignmentLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                !_canChangeAssignees
                    ? 'Only the creator can change assignees.'
                    : _selectedAssignees.isEmpty
                        ? 'Everyone in the household can see and complete this task.'
                        : 'Visible to you, selected assignees, and household Managers.',
                style: AppText.bodySoft,
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
                      child: Text(widget.isEditing ? 'Save' : 'Create'),
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

  late final Set<String> _selectedAssignees;

  bool get _canChangeAssignees =>
      !widget.isEditing ||
      widget.existingTask!.createdByMemberID == widget.currentUserID;

  String _memberName(String memberID) {
    for (final member in widget.members) {
      if (member.userID == memberID) {
        return member.displayName.trim().isEmpty
            ? 'Member ($memberID)'
            : member.displayName;
      }
    }

    return 'Unavailable member ($memberID)';
  }

  String get _assignmentLabel {
    if (_selectedAssignees.isEmpty) return 'Anyone';

    return _selectedAssignees.map(_memberName).join(', ');
  }

    Future<void> _pickAssignees() async {
    final selected = Set<String>.from(_selectedAssignees);

    // Include previous selections even if a member has since left.
    final availableIDs = {
      ...widget.members.map((member) => member.userID),
      ...selected,
    }.toList();

    String? selectionError;

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) {
          return AlertDialog(
            title: const Text('Assign task'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select up to 8 people. '
                      'No selections means Anyone.',
                    ),
                    TextButton(
                      onPressed: () {
                        updateDialog(() {
                          selected.clear();
                          selectionError = null;
                        });
                      },
                      child: const Text('Assign to Anyone'),
                    ),
                    for (final memberID in availableIDs)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_memberName(memberID)),
                        value: selected.contains(memberID),
                        onChanged: (checked) {
                          updateDialog(() {
                            if (checked == true) {
                              if (selected.length >= 8) {
                                selectionError =
                                    'You can select up to 8 people.';
                                return;
                              }

                              selected.add(memberID);
                            } else {
                              selected.remove(memberID);
                            }

                            selectionError = null;
                          });
                        },
                      ),
                    if (selectionError != null)
                      Text(
                        selectionError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
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
      _selectedAssignees
        ..clear()
        ..addAll(result);
    });
  }
}
