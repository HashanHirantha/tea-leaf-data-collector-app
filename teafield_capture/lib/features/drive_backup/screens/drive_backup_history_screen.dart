import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/app_date_utils.dart';
import '../../../data/models/drive_backup_batch.dart';
import '../drive_backup_view_model.dart';

class DriveBackupHistoryScreen extends ConsumerWidget {
  const DriveBackupHistoryScreen({super.key});

  Future<void> _confirmDeleteDriveBackup(
    BuildContext context,
    WidgetRef ref,
    DriveBackupBatch batch,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Backup from Google Drive?'),
        content: Text(
          'This deletes only the app-created archive "${batch.driveFileName}" '
          '(${batch.sampleCount} samples) from Google Drive.\n\n'
          'Local samples and photos on this phone will NOT be deleted.',
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
            child: const Text('Delete from Drive'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final res = await ref
          .read(driveBackupViewModelProvider(null).notifier)
          .deleteBackupFromDrive(batch);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.deleted
                  ? 'Drive backup deleted. Local records remain intact.'
                  : (res.error ?? 'Could not delete Drive backup.'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _openDriveFile(String fileId) async {
    final uri = Uri.parse('https://drive.google.com/file/d/$fileId/view');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driveBackupViewModelProvider(null));
    final notifier = ref.read(driveBackupViewModelProvider(null).notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Backup History')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.history.isEmpty
              ? const Center(
                  child: Text('No Google Drive backup batches recorded yet.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.history.length,
                  itemBuilder: (context, index) {
                    final batch = state.history[index];
                    final status =
                        DriveBackupStatus.fromDatabaseKey(batch.status);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    batch.driveFileName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Chip(
                                  label: Text(status.displayName),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Account: ${batch.googleAccountEmail ?? 'unknown'}',
                            ),
                            Text(
                              'Type: ${DriveBackupType.fromDatabaseKey(batch.backupType).displayName} • '
                              '${batch.sampleCount} samples, ${batch.photoCount} photos',
                            ),
                            Text(
                              'Created: ${AppDateUtils.formatDisplayDateTimeFull(batch.createdAtUtc)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (batch.uploadedAtUtc != null)
                              Text(
                                'Uploaded: ${AppDateUtils.formatDisplayDateTimeFull(batch.uploadedAtUtc)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            if (batch.lastError != null &&
                                batch.lastError!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Error: ${batch.lastError}',
                                  style: TextStyle(color: colorScheme.error),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (status == DriveBackupStatus.failed)
                                  FilledButton.tonalIcon(
                                    onPressed: state.isUploading
                                        ? null
                                        : () => notifier.retryBatch(batch),
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('Retry'),
                                  ),
                                if (batch.driveFileId != null &&
                                    status == DriveBackupStatus.uploaded)
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _openDriveFile(batch.driveFileId!),
                                    icon: const Icon(Icons.open_in_new, size: 18),
                                    label: const Text('Open in Drive'),
                                  ),
                                if (batch.driveFileId != null)
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: colorScheme.error,
                                    ),
                                    onPressed: () => _confirmDeleteDriveBackup(
                                      context,
                                      ref,
                                      batch,
                                    ),
                                    icon: const Icon(
                                      Icons.delete_forever,
                                      size: 18,
                                    ),
                                    label: const Text('Delete from Drive'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
