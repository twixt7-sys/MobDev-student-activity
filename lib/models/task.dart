/// A single task stored in the `tasks` table.
///
/// The database gives us rows as `Map<String, Object?>`, so this class
/// converts between a row and a Dart object (the same idea as fromJson/toJson
/// from Lesson 1, but for database maps).
class Task {
  final int id;
  final String title;
  final bool isCompleted;

  const Task({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  /// Builds a Task from one database row.
  /// SQLite has no boolean type, so `is_completed` is stored as 0 or 1.
  factory Task.fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as int,
      title: map['title'] as String,
      isCompleted: (map['is_completed'] as int) == 1,
    );
  }

  /// Converts the Task back into a map that matches the table columns.
  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'is_completed': isCompleted ? 1 : 0,
    };
  }
}
