import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import 'config/app.dart';
import 'config/database.dart';
import 'config/logging.dart';
import 'config/auth.dart';

import 'database/migrations/m_2025_12_28_155929_create_todos_table.dart';
import 'database/seeders/todo_seeder.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Magic
  await Magic.init(
    configFactories: [
      () => appConfig,
      () => databaseConfig,
      () => loggingConfig,
      () => authConfig,
    ],
  );

  // Run database migrations
  final migrations = await Migrator().run([CreateTodosTable()]);

  if (migrations.isNotEmpty) {
    Log.info(
      '🗄️ Ran ${migrations.length} migration(s): ${migrations.join(', ')}',
    );
  }

  // Seed database in development
  if (kDebugMode) {
    // Only seed if todos table is empty
    final count = await DB.table('todos').count();
    if (count == 0) {
      await Magic.seed([TodoSeeder()]);
    }
  }

  runApp(
    MagicApplication(
      title: 'Magic Example',
      debugShowCheckedModeBanner: true,
      onInit: () {
        Log.info('Magic App initialized!');
      },
    ),
  );
}
