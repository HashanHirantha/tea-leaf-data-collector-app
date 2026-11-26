import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the database before running the app.
  await AppDatabase.instance.database;

  runApp(
    const ProviderScope(
      child: TeaFieldApp(),
    ),
  );
}
