import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_date_utils.dart';
import '../../../data/models/drive_backup_batch.dart';
import '../../data_management/data_management_view_model.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  Future<void> _confirmPermanentDelete(
    BuildContext context,
    WidgetRef ref,
    List<String> sampleUuids,
    String titleLabel,
  ) async {
    if (sampleUuids.isEmpty) return;
    final notifier = ref.read(dataManagementViewModelProvider.notifier);
    final affectedBatches =
        await notifier.getAffectedDriveBatches(sampleUuids);
    final selectedDriveBatches = <DriveBackupBatch>{};

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Permanently Delete Local Records?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently erase $titleLabel and its local photo files from this device. This cannot be undone.',
                ),
                if (affectedBatches.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Google Drive backups containing selected sample(s):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Warning: ZIP archives may also contain other samples. Leave unchecked to keep Drive archives untouched.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  ...affectedBatches.map(
                    (batch) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: selectedDriveBatches.contains(batch),
                      title: Text(batch.driveFileName),
                      subtitle: Text('${batch.sampleCount} total samples in ZIP'),
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            selectedDriveBatches.add(batch);
                          } else {
                            selectedDriveBatches.remove(batch);
                          }
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
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
      ),
    );

    if (confirmed == true && context.mounted) {
      final report = await notifier.permanentlyDeleteSamples(
        sampleUuids,
        driveArchivesToDelete: selectedDriveBatches.toList(),
      );
      if (context.mounted) {
        final cloudNote = report.cloudDeletionRequested
            ? ' Drive deleted: ${report.driveArchivesDeleted}, pending: ${report.driveArchivesPending}.'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Local deleted: ${report.localSamplesDeleted} sample(s), '
              '${report.localPhotosDeleted} photo(s).$cloudNote',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dataManagementViewModelProvider);
    final notifier = ref.read(dataManagementViewModelProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    final hasAnythingInTrash = state.trashedSamples.isNotEmpty ||
        state.individuallyTrashedPhotos.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (state.trashedSamples.isNotEmpty)
            TextButton(
              onPressed: state.isWorking
                  ? null
                  : () => _confirmPermanentDelete(
                        context,
                        ref,
                        state.trashedSamples.map((s) => s.sampleUuid).toList(),
                        'all ${state.trashedSamples.length} trashed sample(s)',
                      ),
              child: Text(
                'Empty Trash',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : !hasAnythingInTrash
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 64,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      const Text('No items in Trash'),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (state.trashedSamples.isNotEmpty) ...[
                      Text(
                        'Trashed Leaf Samples (${state.trashedSamples.length})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ...state.trashedSamples.map((sample) {
                        final photoCount =
                            state.trashedPhotoCountBySample[sample.sampleUuid] ??
                                0;
                        final isSelected = state.selectedTrashUuids
                            .contains(sample.sampleUuid);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (_) => notifier
                                          .toggleTrashSelection(sample.sampleUuid),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sample.sampleCode,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${sample.estateName ?? 'No estate'} • $photoCount photo(s)',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                          Text(
                                            'Deleted: ${AppDateUtils.formatDisplayDateTime(sample.deletedAtUtc)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: state.isWorking
                                          ? null
                                          : () => notifier.restoreSamples(
                                                [sample.sampleUuid],
                                              ),
                                      icon: const Icon(Icons.restore),
                                      label: const Text('Restore'),
                                    ),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        foregroundColor: colorScheme.error,
                                      ),
                                      onPressed: state.isWorking
                                          ? null
                                          : () => _confirmPermanentDelete(
                                                context,
                                                ref,
                                                [sample.sampleUuid],
                                                '${sample.sampleCode} ($photoCount photo(s))',
                                              ),
                                      icon: const Icon(Icons.delete_forever),
                                      label: const Text('Delete Forever'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                    if (state.individuallyTrashedPhotos.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Individually Removed Photos (${state.individuallyTrashedPhotos.length})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      ...state.individuallyTrashedPhotos.map(
                        (photo) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('${photo.leafSide.toUpperCase()} photo'),
                            subtitle: Text(
                              'Deleted: ${AppDateUtils.formatDisplayDateTime(photo.deletedAtUtc)}',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Restore photo',
                                  icon: const Icon(Icons.restore),
                                  onPressed: state.isWorking
                                      ? null
                                      : () => notifier.restoreSinglePhoto(
                                            photo.photoUuid,
                                          ),
                                ),
                                IconButton(
                                  tooltip: 'Permanently delete photo',
                                  icon: Icon(
                                    Icons.delete_forever,
                                    color: colorScheme.error,
                                  ),
                                  onPressed: state.isWorking
                                      ? null
                                      : () => notifier
                                          .permanentlyDeleteSinglePhoto(
                                            photo.photoUuid,
                                          ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
      bottomNavigationBar: state.selectedTrashUuids.isNotEmpty
          ? BottomAppBar(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: state.isWorking
                        ? null
                        : () => notifier.restoreSamples(
                              state.selectedTrashUuids.toList(),
                            ),
                    icon: const Icon(Icons.restore),
                    label: Text(
                      'Restore (${state.selectedTrashUuids.length})',
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                    ),
                    onPressed: state.isWorking
                        ? null
                        : () => _confirmPermanentDelete(
                              context,
                              ref,
                              state.selectedTrashUuids.toList(),
                              '${state.selectedTrashUuids.length} selected sample(s)',
                            ),
                    icon: const Icon(Icons.delete_forever),
                    label: Text(
                      'Delete (${state.selectedTrashUuids.length})',
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
