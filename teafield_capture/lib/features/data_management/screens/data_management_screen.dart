import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/sample_deletion_service.dart';
import '../data_management_view_model.dart';

class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});

  @override
  ConsumerState<DataManagementScreen> createState() =>
      _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen> {
  final TextEditingController _phraseController = TextEditingController();
  bool _alsoDeleteDriveBackups = false;

  @override
  void dispose() {
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDeleteAll(ProjectDataCounts counts) async {
    final notifier = ref.read(dataManagementViewModelProvider.notifier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Full Project Reset'),
        content: Text(
          'This will permanently delete:\n'
          '• ${counts.totalSamples} sample(s)\n'
          '• ${counts.photoFiles} local photo file(s)\n'
          '• ${counts.localExportFiles} local export package(s)\n\n'
          '${_alsoDeleteDriveBackups ? 'Tracked Google Drive backups (${counts.driveBackupFiles}) will ALSO be deleted.' : 'Tracked Google Drive backups (${counts.driveBackupFiles}) will be KEPT.'}\n\n'
          'Note: Copies already transferred outside the app (laptop, Downloads, other phones) cannot be erased.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final report = await notifier.deleteAllProjectData(
      alsoDeleteDriveBackups: _alsoDeleteDriveBackups,
    );

    _phraseController.clear();
    setState(() => _alsoDeleteDriveBackups = false);

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletion Outcome'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local records deleted: ${report.localSamplesDeleted} samples, '
              '${report.localPhotosDeleted} photos.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (report.localFileFailures.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Warning: ${report.localFileFailures.length} local file(s) could not be removed.',
              ),
            ],
            const SizedBox(height: 10),
            if (report.cloudDeletionRequested)
              Text(
                'Google Drive backups deleted: ${report.driveArchivesDeleted}\n'
                'Google Drive backups still pending: ${report.driveArchivesPending}'
                '${report.cloudErrorMessage != null ? '\n(${report.cloudErrorMessage})' : ''}',
              )
            else
              Text(
                'Google Drive backups remaining: ${report.driveArchivesPending} '
                '(not requested for deletion).',
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dataManagementViewModelProvider);
    final notifier = ref.read(dataManagementViewModelProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    final counts = state.counts;
    final storageMb = (state.storageBytesUsed / (1024 * 1024)).toStringAsFixed(2);
    final phraseMatches = _phraseController.text.trim() == 'DELETE ALL DATA';

    return Scaffold(
      appBar: AppBar(title: const Text('Data Management')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Project Storage (${state.projectCode})',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        _CountRow(
                          label: 'Active samples',
                          value: '${counts.activeSamples}',
                        ),
                        _CountRow(
                          label: 'Trashed samples',
                          value: '${counts.trashedSamples}',
                        ),
                        _CountRow(
                          label: 'Local photo files',
                          value: '${counts.photoFiles}',
                        ),
                        _CountRow(
                          label: 'Local export files',
                          value: '${counts.localExportFiles}',
                        ),
                        _CountRow(
                          label: 'App storage used',
                          value: '$storageMb MB',
                        ),
                        _CountRow(
                          label: 'Tracked Drive backup files',
                          value: '${counts.driveBackupFiles}',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Open Trash'),
                    subtitle: Text(
                      '${counts.trashedSamples} trashed sample(s), '
                      '${state.individuallyTrashedPhotos.length} removed photo(s)',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await context.push('/trash');
                      if (mounted) notifier.refresh();
                    },
                  ),
                ),
                if (state.pendingCloudDeletions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pending Google Drive Deletions (${state.pendingCloudDeletions.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...state.pendingCloudDeletions.map(
                            (p) => Text(
                              '• ${p.driveFileName} (${p.lastError ?? p.status})',
                              style: TextStyle(
                                color: colorScheme.onErrorContainer,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: state.isWorking
                                ? null
                                : () async {
                                    final res = await notifier
                                        .retryPendingCloudDeletions();
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Deleted ${res.deletedCount} Drive archive(s); '
                                            '${res.remainingCount} remaining.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.cloud_sync),
                            label: const Text('Retry Drive Deletion'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.error),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber, color: colorScheme.error),
                            const SizedBox(width: 8),
                            Text(
                              'Delete All Project Data',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Samples: ${counts.totalSamples} | Photos: ${counts.photoFiles} | '
                          'Exports: ${counts.localExportFiles} | Drive backups: ${counts.driveBackupFiles}',
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Also delete the app-created backup files from Google Drive',
                          ),
                          subtitle: const Text(
                            'Deletes only tracked archive IDs created by this app. Leave unchecked to preserve Drive backups.',
                          ),
                          value: _alsoDeleteDriveBackups,
                          onChanged: state.isWorking
                              ? null
                              : (val) => setState(
                                    () => _alsoDeleteDriveBackups = val ?? false,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _phraseController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Type DELETE ALL DATA to continue',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.error,
                          ),
                          onPressed: state.isWorking || !phraseMatches
                              ? null
                              : () => _confirmAndDeleteAll(counts),
                          icon: const Icon(Icons.delete_forever),
                          label: Text(
                            state.isWorking
                                ? 'Deleting...'
                                : 'Permanently Delete All Project Data',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CountRow extends StatelessWidget {
  final String label;
  final String value;

  const _CountRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
