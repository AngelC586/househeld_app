import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_theme.dart';


class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({
    super.key,
    required this.currentUserID,
    this.existingTask,
  });

  final String currentUserID;
  final HouseholdTask? existingTask;

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
        ? widget.existingTask!.copyWith(taskName: name, taskDescription: description)
        : HouseholdTask(
            taskId: 'local-${DateTime.now().millisecondsSinceEpoch}',
            taskName: name,
            taskDescription: description,
            taskStatus: 'pending',
            createdByMemberID: widget.currentUserID,
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
}
