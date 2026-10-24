import 'package:flutter/material.dart';

import 'data/task_database.dart';
import 'repositories/task_repository.dart';
import 'screens/task_screen.dart';

void main() {
  // Needed because we use plugins (sqflite) before runApp finishes.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskApp());
}

class TaskApp extends StatelessWidget {
  const TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Task Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: TaskScreen(
        // The screen opens the database itself, so it can show a loading
        // spinner and an error message if opening fails.
        openRepository: () async => TaskRepository(await openTaskDatabase()),
      ),
    );
  }
}
