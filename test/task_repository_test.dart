import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_task_manager/data/task_database.dart';
import 'package:local_task_manager/repositories/task_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// These tests run SQLite on the computer (through sqflite_common_ffi),
/// so `flutter test` works without a phone or emulator.
void main() {
  late Database db;
  late TaskRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    // A fresh in-memory database with the same table as the real app.
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: createTasksTable),
    );
    repository = TaskRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('create saves a task and getAll reads it back', () async {
    final id = await repository.create('  Complete laboratory activity  ');

    final tasks = await repository.getAll();
    expect(tasks.length, 1);
    expect(tasks.first.id, id);
    expect(tasks.first.title, 'Complete laboratory activity'); // trimmed
    expect(tasks.first.isCompleted, isFalse); // default value from the table
  });

  test('getAll returns the newest task first', () async {
    await repository.create('First');
    await repository.create('Second');

    final tasks = await repository.getAll();
    expect(tasks.map((task) => task.title).toList(), ['Second', 'First']);
  });

  test('empty or whitespace-only titles are rejected', () async {
    expect(() => repository.create(''), throwsArgumentError);
    expect(() => repository.create('    '), throwsArgumentError);
    expect(await repository.getAll(), isEmpty);
  });

  test('markCompleted updates only the selected task', () async {
    final first = await repository.create('Review lesson materials');
    final second = await repository.create('Submit assignment');

    await repository.markCompleted(first);

    final tasks = await repository.getAll();
    final firstTask = tasks.firstWhere((task) => task.id == first);
    final secondTask = tasks.firstWhere((task) => task.id == second);
    expect(firstTask.isCompleted, isTrue);
    expect(secondTask.isCompleted, isFalse);

    await repository.markCompleted(first, isCompleted: false);
    final updated = await repository.getAll();
    expect(updated.firstWhere((task) => task.id == first).isCompleted, isFalse);
  });

  test('delete removes the task from the database', () async {
    final keep = await repository.create('Keep me');
    final remove = await repository.create('Delete me');

    await repository.delete(remove);

    final tasks = await repository.getAll();
    expect(tasks.map((task) => task.id), [keep]);
  });

  test('update and delete report an error when the task does not exist',
      () async {
    await expectLater(
      repository.markCompleted(999),
      throwsA(isA<TaskNotFoundException>()),
    );
    await expectLater(
      repository.delete(999),
      throwsA(isA<TaskNotFoundException>()),
    );
  });

  test('tasks are still there after the database is closed and reopened',
      () async {
    // Simulates closing and relaunching the app by using a real file.
    final folder = await Directory.systemTemp.createTemp('task_db_test');
    final path = p.join(folder.path, databaseFileName);
    final options =
        OpenDatabaseOptions(version: 1, onCreate: createTasksTable);

    final firstSession = await databaseFactoryFfi.openDatabase(
      path,
      options: options,
    );
    await TaskRepository(firstSession).create('Mobile Development Activity');
    await firstSession.close();

    final secondSession = await databaseFactoryFfi.openDatabase(
      path,
      options: options,
    );
    final tasks = await TaskRepository(secondSession).getAll();
    expect(tasks.single.title, 'Mobile Development Activity');

    await secondSession.close();
    await folder.delete(recursive: true);
  });
}
