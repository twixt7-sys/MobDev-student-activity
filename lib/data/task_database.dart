import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Name of the database file saved on the device.
const String databaseFileName = 'tasks.db';

/// SQL that creates the tasks table.
/// - id is generated automatically (primary key)
/// - title cannot be missing (NOT NULL)
/// - is_completed is 0 (false) by default
const String createTasksTableSql = '''
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  is_completed INTEGER NOT NULL DEFAULT 0
)
''';

/// Runs only the first time the database file is created.
Future<void> createTasksTable(Database db, int version) async {
  await db.execute(createTasksTableSql);
}

/// Opens (or creates) the tasks database in the app's database folder.
Future<Database> openTaskDatabase() async {
  final databasePath = await getDatabasesPath();
  final path = join(databasePath, databaseFileName);

  return openDatabase(
    path,
    version: 1,
    onCreate: createTasksTable,
  );
}

// ---------------------------------------------------------------------------
// CRUD functions. Each one receives the database connection and works on the
// tasks table. Values are always passed with `?` placeholders + whereArgs,
// never glued into the SQL string.
// ---------------------------------------------------------------------------

/// CREATE: inserts a new task and returns its generated id.
Future<int> addTask(Database db, String title) {
  return db.insert(
    'tasks',
    {'title': title},
  );
}

/// READ: returns every task, newest first.
Future<List<Map<String, Object?>>> getTasks(Database db) {
  return db.query(
    'tasks',
    orderBy: 'id DESC',
  );
}

/// UPDATE: sets the completion status of one task.
/// Returns the number of rows changed (should be 1).
Future<int> setTaskCompleted(Database db, int id, bool isCompleted) {
  return db.update(
    'tasks',
    {'is_completed': isCompleted ? 1 : 0},
    where: 'id = ?',
    whereArgs: [id],
  );
}

/// DELETE: removes one task. Returns the number of rows deleted (should be 1).
Future<int> deleteTask(Database db, int id) {
  return db.delete(
    'tasks',
    where: 'id = ?',
    whereArgs: [id],
  );
}
