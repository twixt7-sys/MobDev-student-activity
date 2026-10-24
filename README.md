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

A Dart list only stores data in memory, so the tasks will disappear when the app is closed. SQLite solves this problem by saving the tasks in a database file called tasks.db. When I open the app again, _loadTasks() in TaskScreen calls repository.getAll() to load the saved tasks from the database.

SQLite also makes managing tasks easier. I can organize them in a table, sort them using id DESC to show the newest tasks first, and update or delete specific tasks. It also has rules like NOT NULL and DEFAULT 0 to help keep the data consistent. I tested this by closing and reopening the database and checking if the tasks were still there.

My app still uses a Dart list (List<Task> _tasks) to display the tasks on the screen, but the actual data is saved in SQLite. This means the tasks will still be there even after I close the app.

### 2. What is the purpose of the primary key in the `tasks` table?

The id column (INTEGER PRIMARY KEY AUTOINCREMENT) gives each task a unique number. This is important because two tasks can have the same title but still need to be treated as different tasks.

For example, when I complete or delete a task, the app uses its id to identify which record to change.

db.update('tasks', {'is_completed': isCompleted ? 1 : 0},
    where: 'id = ?', whereArgs: [id]);

db.delete('tasks', where: 'id = ?', whereArgs: [id]);

If I used the task title instead, deleting one task could accidentally delete other tasks with the same title. Using the id makes sure that only the selected task is affected. It also helps the app identify each task in the list and show the newest tasks first by sorting them with id DESC.

### 3. How does the repository simplify the UI's interaction with the database?

The repository makes it easier for the UI to work with the database because the screen only needs to call methods like create(title), getAll(), markCompleted(id), and delete(id). I do not have to write the database queries directly inside the UI.

The repository handles things like checking if the task title is empty, converting database records into Task objects, and making sure the task exists before updating or deleting it. If a task cannot be found, it throws a TaskNotFoundException, which the screen can catch and display as an error.

This makes the code easier to manage because the database operations are kept in one place. If I need to change how the database works, I can mostly make those changes in the repository and task_database.dart without having to rewrite the UI.

It also makes testing easier. For example, I can test the repository using an in-memory database without needing to run the entire app or build the UI.

### 4. What would happen if a task were removed from the displayed list but not deleted from SQLite?

The task would disappear from the screen, but its record would still be saved in the database. When the app loads the tasks again, the deleted task would show up again because it was never actually removed from SQLite.

This could make the app confusing to use because the displayed list would not match the data saved in the database.

To avoid this, my _deleteTask() method first calls repository.delete(task.id) to remove the task from the database. Once the deletion succeeds, the app shows the "Task deleted." message and calls _loadTasks() to refresh the list.

If the deletion fails, the app shows an error instead of pretending that the task was deleted. This helps keep the displayed tasks consistent with the data stored in the database.

### 5. If the database schema later needed a new column for task priority, what parts of the application might need to change?

Several parts of the application would need to be updated to support task priority.

Database (task_database.dart): I would add a priority column to the table and increase the database version from 1 to 2. I would also add an onUpgrade callback with ALTER TABLE tasks ADD COLUMN priority INTEGER NOT NULL DEFAULT 0 so existing users can update their database without losing their saved tasks.

CRUD functions: The functions that add or retrieve tasks might need to be updated to support priority. For example, I could sort tasks by priority using orderBy: 'priority DESC, id DESC'.

Model (task.dart): I would add a priority field and update fromMap() and toMap() so the model can read and save the new value.

Repository (task_repository.dart): I would update create() to accept a priority value and add a method like updatePriority(id, priority) to change a task's priority. I could also validate the value to allow only priorities such as 0, 1, or 2.

UI (task_screen.dart): I would add a way for users to choose a priority when creating a task, such as a dropdown, and display the selected priority in the task list.

Tests: I would update the test setup and add tests to check if priority values are saved, loaded, and updated correctly.

The good thing about using a repository is that the UI does not need to handle the SQL queries directly. I would only need to change the parts of the screen related to choosing and displaying the task priority.
