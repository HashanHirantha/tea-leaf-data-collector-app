import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/sample/screens/new_sample_screen.dart';
import 'features/camera/screens/camera_screen.dart';
import 'features/sample/screens/join_sample_screen.dart';
import 'features/sample/screens/show_sample_qr_screen.dart';
import 'features/sample/screens/sample_list_screen.dart';
import 'features/sample/screens/sample_detail_screen.dart';
import 'features/export/screens/export_screen.dart';
import 'features/import/screens/import_screen.dart';
import 'features/drive_backup/screens/drive_backup_screen.dart';
import 'features/drive_backup/screens/drive_backup_history_screen.dart';
import 'features/trash/screens/trash_screen.dart';
import 'features/data_management/screens/data_management_screen.dart';
import 'features/settings/screens/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      name: 'dashboard',
      builder: (BuildContext context, GoRouterState state) {
        return const DashboardScreen();
      },
    ),
    GoRoute(
      path: '/new-sample',
      name: 'new-sample',
      builder: (BuildContext context, GoRouterState state) {
        return const NewSampleScreen();
      },
    ),
    GoRoute(
      path: '/camera/:sampleUuid/:leafSide',
      name: 'camera',
      builder: (BuildContext context, GoRouterState state) {
        final sampleUuid = state.pathParameters['sampleUuid']!;
        final leafSide = state.pathParameters['leafSide']!;
        return CameraScreen(
          sampleUuid: sampleUuid,
          leafSide: leafSide,
        );
      },
    ),
    GoRoute(
      path: '/join-sample',
      name: 'join-sample',
      builder: (BuildContext context, GoRouterState state) {
        return const JoinSampleScreen();
      },
    ),
    GoRoute(
      path: '/show-qr/:sampleUuid',
      name: 'show-qr',
      builder: (BuildContext context, GoRouterState state) {
        final sampleUuid = state.pathParameters['sampleUuid']!;
        return ShowSampleQrScreen(sampleUuid: sampleUuid);
      },
    ),
    GoRoute(
      path: '/samples',
      name: 'samples',
      builder: (BuildContext context, GoRouterState state) {
        return const SampleListScreen();
      },
    ),
    GoRoute(
      path: '/sample/:sampleUuid',
      name: 'sample-detail',
      builder: (BuildContext context, GoRouterState state) {
        final sampleUuid = state.pathParameters['sampleUuid']!;
        return SampleDetailScreen(sampleUuid: sampleUuid);
      },
    ),
    GoRoute(
      path: '/export',
      name: 'export',
      builder: (BuildContext context, GoRouterState state) {
        return const ExportScreen();
      },
    ),
    GoRoute(
      path: '/import',
      name: 'import',
      builder: (BuildContext context, GoRouterState state) {
        return const ImportScreen();
      },
    ),
    GoRoute(
      path: '/drive-backup',
      name: 'drive-backup',
      builder: (BuildContext context, GoRouterState state) {
        return const DriveBackupScreen();
      },
    ),
    GoRoute(
      path: '/drive-backup/history',
      name: 'drive-backup-history',
      builder: (BuildContext context, GoRouterState state) {
        return const DriveBackupHistoryScreen();
      },
    ),
    GoRoute(
      path: '/trash',
      name: 'trash',
      builder: (BuildContext context, GoRouterState state) {
        return const TrashScreen();
      },
    ),
    GoRoute(
      path: '/data-management',
      name: 'data-management',
      builder: (BuildContext context, GoRouterState state) {
        return const DataManagementScreen();
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (BuildContext context, GoRouterState state) {
        return const SettingsScreen();
      },
    ),
  ],
);
