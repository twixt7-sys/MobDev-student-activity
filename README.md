# Local Task Manager

**IT 126 – Module 3, Lesson 2: Local Storage and Database Operations**
Application and Reflection output

A single-screen Flutter app that lets the user add, view, complete, and delete tasks. The tasks are saved in a local SQLite database through the `sqflite` package, so they are still there after the app is closed and opened again. All database work goes through a `TaskRepository`, so the screen never runs SQL directly.

## Features

- Add a task with a text field and an **Add** button (or by pressing Enter)
- Empty or spaces-only titles are rejected with a message under the text field
- All saved tasks are loaded when the screen opens (newest first)
- Tick the checkbox to mark a task as completed (untick to set it back to pending)
- Delete a task with the trash icon (a confirmation dialog appears first)
- The list is reloaded from the database after every successful change
- A loading spinner is shown while tasks load, and an error message with a **Try again** button is shown if loading fails
- If an insert, update, or delete fails, the app shows an error instead of a success message

## Project structure

```
lib/
├── main.dart                         # Starts the app and gives the screen a way to open the database
├── models/
│   └── task.dart                     # Task class + fromMap / toMap (database row <-> Dart object)
├── data/
│   └── task_database.dart            # Opens tasks.db, creates the table, and the CRUD functions
├── repositories/
│   └── task_repository.dart          # The only class the UI uses for data (validation + CRUD)
└── screens/
    └── task_screen.dart              # The UI: text field, button, task list
test/
└── task_repository_test.dart         # Tests for the repository, including persistence after reopening
```

### How the parts connect

```
TaskScreen (UI)  ──calls──▶  TaskRepository  ──calls──▶  CRUD functions  ──▶  SQLite (tasks.db)
     ▲                                                                              │
     └──────────────────── reloads the list after each change ◀────────────────────┘
```

## Database table

```sql
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  is_completed INTEGER NOT NULL DEFAULT 0
);
```

| Column | Meaning |
| --- | --- |
| `id` | Primary key, generated automatically |
| `title` | The task title (cannot be missing) |
| `is_completed` | `0` = pending, `1` = completed (SQLite has no boolean type) |

The database file `tasks.db` is created inside the folder returned by `getDatabasesPath()`, and the full path is built with `join()` from the `path` package.

## How to run

Requirements: Flutter SDK (Dart 3.5 or newer) and an Android emulator/phone or an iOS simulator. `sqflite` supports Android and iOS, so run the app on one of those (not Chrome or Windows desktop).

```bash
git clone <this repository URL>
cd local_task_manager
flutter pub get
flutter run
```

To check persistence: add a few tasks, fully close the app (swipe it away or stop it), then run it again. The tasks will still be listed.

Run the tests (they use `sqflite_common_ffi`, so no phone is needed):

```bash
flutter test
```

> If Gradle reports a version problem on your Flutter installation, delete the `android` and `ios` folders and run `flutter create .` inside the project. This regenerates the platform files for your Flutter version without touching `lib/`, `test/`, or `pubspec.yaml`.

---

## Reflection

### 1. Why does the application use SQLite instead of relying only on a Dart list?

A Dart list only lives in memory (RAM). In the Activity, the tasks showed up while the app was running, but once the app process ended and was launched again, the list was empty because nothing had been written to storage. SQLite saves the tasks in a file on the device (`tasks.db`), so when the app opens again, `_loadTasks()` in `TaskScreen` calls `repository.getAll()`, which reads the rows back from that file.

SQLite also gives me things a plain list does not: a fixed structure for each task (the `tasks` table), queries that can sort records (`orderBy: 'id DESC'` shows the newest first), updates and deletes that target one record with a `where` condition, and constraints such as `NOT NULL` and `DEFAULT 0`. If I only used a list, I would have to write my own file format and my own code for loading, searching, and saving everything. My test `tasks are still there after the database is closed and reopened` checks this by closing the database file, opening it again, and confirming the task is still there.

The list still exists in my app (`List<Task> _tasks` in the screen), but it is only a copy of what is in the database for displaying on screen. The database is the real record.

### 2. What is the purpose of the primary key in the `tasks` table?

The `id` column (`INTEGER PRIMARY KEY AUTOINCREMENT`) gives every task its own unique number, even if two tasks have the same title. My app uses this id whenever it changes a specific task:

```dart
db.update('tasks', {'is_completed': isCompleted ? 1 : 0},
    where: 'id = ?', whereArgs: [id]);

db.delete('tasks', where: 'id = ?', whereArgs: [id]);
```

If I used the title instead, completing or deleting "Submit assignment" would affect every task with that same title. With the id, only the one row the user tapped is changed. The id is also stored in the `Task` object, so each row in the `ListView` knows exactly which database record it belongs to. Because the ids increase over time, I can also sort by `id DESC` to show the newest tasks first.

### 3. How does the repository simplify the UI's interaction with the database?

`TaskScreen` only calls four simple methods: `create(title)`, `getAll()`, `markCompleted(id)`, and `delete(id)`. It does not know the table name, the column names, the SQL, or that `is_completed` is stored as `0` or `1`. The repository takes care of those details:

- It trims the title and throws an error if it is empty, so invalid data never reaches the database.
- It converts database maps into `Task` objects with `Task.fromMap`, so the UI works with `task.title` and `task.isCompleted` instead of `row['is_completed'] == 1`.
- It checks how many rows were changed, and throws `TaskNotFoundException` if an update or delete affected 0 rows. The screen catches this and shows an error instead of a false "success" message.

Because all data access is in one place, if the database code changes I only need to update the repository and `task_database.dart`, not the widget. It also made testing easier: my tests in `test/task_repository_test.dart` check the repository with an in-memory database without needing to build the UI at all.

### 4. What would happen if a task were removed from the displayed list but not deleted from SQLite?

The task would disappear from the screen for now, but the row would still be in `tasks.db`. The next time the list is loaded from the database (after adding another task, completing a task, or reopening the app) the "deleted" task would come back. The user would think delete is broken, and the database and the screen would be out of sync.

To prevent this, my `_deleteTask()` method first calls `repository.delete(task.id)`, which runs `db.delete(...)` with the task's id. Only after that succeeds does it show "Task deleted." and call `_loadTasks()` to reload the list from the database. If the delete fails, the app shows an error and leaves the list as it is, so the screen always matches what is actually stored.

### 5. If the database schema later needed a new column for task priority, what parts of the application might need to change?

- **Database (`task_database.dart`):** Add the column to the `CREATE TABLE` statement for new installs, increase `version` from `1` to `2`, and add an `onUpgrade` callback that runs `ALTER TABLE tasks ADD COLUMN priority INTEGER NOT NULL DEFAULT 0` for users who already have version 1. Without the migration, existing users would keep the old table and the app would fail when it tries to use `priority`.
- **CRUD functions:** `addTask()` would need to insert the priority, and I might add a function to update it. `getTasks()` could sort by priority (for example `orderBy: 'priority DESC, id DESC'`).
- **Model (`task.dart`):** Add a `priority` field and update `fromMap()` and `toMap()`.
- **Repository (`task_repository.dart`):** Change `create()` to accept a priority, validate it (for example only 0, 1, or 2), and add a method such as `updatePriority(id, priority)`.
- **UI (`task_screen.dart`):** Add a way to choose the priority when adding a task (like a dropdown) and show it in each list item.
- **Tests:** Update the test database setup and add tests for the new column.

Because of the repository, the screen would only change where it needs to show or pick the priority. It still would not need to know any SQL.

---

## References

- Flutter. (n.d.). *Persist data with SQLite*. https://docs.flutter.dev/cookbook/persistence/sqlite
- SQLite Consortium. (n.d.). *CREATE TABLE*. https://www.sqlite.org/lang_createtable.html
- Tekartik. (n.d.). *sqflite: Flutter plugin for SQLite*. https://pub.dev/packages/sqflite
- Dart. (n.d.). *Asynchronous programming: Futures, async, and await*. https://dart.dev/libraries/async/async-await
