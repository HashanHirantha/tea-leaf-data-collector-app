import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/settings_service.dart';
import 'data/database/app_database.dart';
import 'data/repositories/backup_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the local SQLite database and recover any interrupted Drive uploads.
  await AppDatabase.instance.database;
  await SettingsService.instance.getOrCreateDeviceId();
  await BackupRepository().recoverInterruptedUploads();

  runApp(
    const ProviderScope(
      child: TeaFieldApp(),
    ),
  );
}
