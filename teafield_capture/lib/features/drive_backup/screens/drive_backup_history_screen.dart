import 'package:flutter/material.dart';

class DriveBackupHistoryScreen extends StatelessWidget {
  const DriveBackupHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup History')),
      body: const Center(child: Text('Drive Backup History')),
    );
  }
}
