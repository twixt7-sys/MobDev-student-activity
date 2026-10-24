import 'package:sqflite/sqflite.dart';

import '../data/task_database.dart';
import '../models/task.dart';

/// Thrown when an update or delete did not find the task it was looking for.
class TaskNotFoundException implements Exception {
  final int id;

  TaskNotFoundException(this.id);

  @override
  String toString() => 'Task $id was not found in the database.';
}

/// The only class the UI talks to when it needs task data.
///
/// The screen never writes SQL or calls the database directly. It asks the
/// repository, and the repository uses the CRUD functions in task_database.dart.
class TaskRepository {
  final Database database;

  TaskRepository(this.database);

  /// Saves a new task after checking the title.
  /// Throws an [ArgumentError] if the title is empty or only spaces.
  Future<int> create(String title) {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError('Task title cannot be empty.');
    }
    return addTask(database, cleanTitle);
  }

  /// Loads all saved tasks and turns each row into a [Task] object.
  Future<List<Task>> getAll() async {
    final rows = await getTasks(database);
    return rows.map((row) => Task.fromMap(row)).toList();
  }

  /// Marks a task as completed (or not completed when [isCompleted] is false).
  Future<void> markCompleted(int id, {bool isCompleted = true}) async {
    final changedRows = await setTaskCompleted(database, id, isCompleted);
    if (changedRows == 0) {
      throw TaskNotFoundException(id);
    }
  }

  /// Deletes a task from the database.
  Future<void> delete(int id) async {
    final deletedRows = await deleteTask(database, id);
    if (deletedRows == 0) {
      throw TaskNotFoundException(id);
    }
  }
}
