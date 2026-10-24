import 'package:flutter/material.dart';

import '../models/task.dart';
import '../repositories/task_repository.dart';

/// The only screen of the app.
///
/// It shows a text field + Add button at the top and the saved tasks below.
/// Every change goes through [TaskRepository]; this widget never runs SQL.
class TaskScreen extends StatefulWidget {
  /// Opens the database and gives back a repository.
  /// Passed in from main.dart so the screen can show a spinner while it opens.
  final Future<TaskRepository> Function() openRepository;

  const TaskScreen({super.key, required this.openRepository});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final TextEditingController _titleController = TextEditingController();

  TaskRepository? _repository;
  List<Task> _tasks = [];

  bool _isLoading = true; // true while the list is being loaded
  bool _isSaving = false; // true while a new task is being inserted
  String? _loadError; // message shown when loading fails
  String? _titleError; // validation message under the text field

  @override
  void initState() {
    super.initState();
    // _isLoading already starts as true, so no extra setState is needed here.
    _loadTasks(showSpinner: false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data operations (all of them go through the repository)
  // ---------------------------------------------------------------------------

  /// READ: loads the saved tasks from SQLite.
  /// [showSpinner] is false when we only refresh after a change, so the list
  /// does not flash.
  Future<void> _loadTasks({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      _repository ??= await widget.openRepository();
      final tasks = await _repository!.getAll();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _isLoading = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load your tasks.\n$error';
      });
    }
  }

  /// CREATE: validates the title, saves it, then reloads the list.
  Future<void> _addTask() async {
    final title = _titleController.text;

    // Validation: an empty or spaces-only title is not allowed.
    if (title.trim().isEmpty) {
      setState(() => _titleError = 'Please enter a task title.');
      return;
    }

    final repository = _repository;
    if (repository == null) return;

    setState(() {
      _isSaving = true;
      _titleError = null;
    });

    try {
      await repository.create(title);
    } catch (error) {
      // The insert failed, so we must NOT say the task was saved.
      _showMessage('Could not save the task: $error', isError: true);
      if (mounted) setState(() => _isSaving = false);
      return;
    }

    _titleController.clear();
    if (mounted) setState(() => _isSaving = false);
    _showMessage('Task added.');
    await _loadTasks(showSpinner: false);
  }

  /// UPDATE: marks a task as completed (or back to pending).
  Future<void> _setCompleted(Task task, bool isCompleted) async {
    try {
      await _repository!.markCompleted(task.id, isCompleted: isCompleted);
    } catch (error) {
      _showMessage('Could not update the task: $error', isError: true);
      return;
    }
    await _loadTasks(showSpinner: false);
  }

  /// DELETE: asks for confirmation, removes the task from SQLite,
  /// then reloads the list from the database.
  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repository!.delete(task.id);
    } catch (error) {
      _showMessage('Could not delete the task: $error', isError: true);
      return;
    }

    _showMessage('Task deleted.');
    await _loadTasks(showSpinner: false);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final completedCount = _tasks.where((task) => task.isCompleted).length;
    final canEdit = _repository != null && !_isSaving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    enabled: canEdit,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Task title',
                      hintText: 'e.g. Mobile Development Activity',
                      border: const OutlineInputBorder(),
                      errorText: _titleError,
                    ),
                    onChanged: (_) {
                      if (_titleError != null) {
                        setState(() => _titleError = null);
                      }
                    },
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: canEdit ? _addTask : null,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ),
              ],
            ),
          ),
          if (!_isLoading && _loadError == null && _tasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$completedCount of ${_tasks.length} completed',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          Expanded(child: _buildTaskList()),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadTasks,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_tasks.isEmpty) {
      return const Center(
        child: Text('No tasks yet. Add your first task above.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _tasks.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return ListTile(
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: (value) => _setCompleted(task, value ?? false),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? Colors.grey : null,
            ),
          ),
          subtitle: Text(task.isCompleted ? 'Completed' : 'Pending'),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete task',
            onPressed: () => _deleteTask(task),
          ),
        );
      },
    );
  }
}
