import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/disease_classes.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../data/models/import_record.dart';
import '../../export/transfer_view_model.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  Future<void> _pickZipFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    final path = picked?.files.single.path;
    if (path != null && mounted) {
      await ref.read(importViewModelProvider.notifier).inspectFile(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importViewModelProvider);
    final notifier = ref.read(importViewModelProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Import Package')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Merge Data From Another Phone',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select an exported TeaField ZIP package. Records are matched by sample_uuid and deduplicated by photo_uuid/SHA-256 without overwriting expert labels.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: state.isInspecting || state.isImporting
                        ? null
                        : _pickZipFile,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Select Export ZIP File'),
                  ),
                ],
              ),
            ),
          ),
          if (state.isInspecting) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Card(
              color: colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  state.errorMessage!,
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ),
          ],
          if (state.preview != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Package Preview: ${state.preview!.fileName}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Project: ${state.preview!.manifest.projectCode}',
                    ),
                    Text(
                      'Exported by device: ${state.preview!.manifest.exportDeviceId}',
                    ),
                    Text(
                      'Exported at: ${AppDateUtils.formatDisplayDateTimeFull(state.preview!.manifest.exportTimeUtc)}',
                    ),
                    Text(
                      'Counts: ${state.preview!.manifest.sampleCount} samples, '
                      '${state.preview!.manifest.photoCount} photos',
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed:
                          state.isImporting ? null : notifier.runImport,
                      icon: state.isImporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.merge_type),
                      label: Text(
                        state.isImporting
                            ? 'Verifying Checksums & Merging...'
                            : 'Verify Checksums & Import',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (state.result != null) ...[
            const SizedBox(height: 16),
            Card(
              color: colorScheme.primaryContainer.withValues(alpha: 0.6),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Summary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text('New samples created: ${state.result!.samplesCreated}'),
                    Text('Existing samples merged: ${state.result!.samplesMerged}'),
                    Text('New photos imported: ${state.result!.photosImported}'),
                    Text(
                      'Duplicate photos skipped: ${state.result!.photosSkippedDuplicate}',
                    ),
                    Text('Conflicts flagged: ${state.result!.conflicts.length}'),
                  ],
                ),
              ),
            ),
          ],
          if (state.pendingConflicts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Conflicts Requiring Manual Resolution',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
            ),
            const SizedBox(height: 8),
            ...state.pendingConflicts.map(
              (conflict) => _ConflictCard(
                conflict: conflict,
                onKeepLocal: () => notifier.resolveConflict(
                  conflict: conflict,
                  useIncoming: false,
                ),
                onUseIncoming: () => notifier.resolveConflict(
                  conflict: conflict,
                  useIncoming: true,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Import History',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (state.history.isEmpty)
            const Text('No packages imported on this device yet.')
          else
            ...state.history.map(
              (rec) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(rec.packageName),
                  subtitle: Text(
                    '${AppDateUtils.formatDisplayDateTime(rec.importedAtUtc)}\n${rec.resultSummary ?? ''}',
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConflictCard extends StatelessWidget {
  final ImportConflict conflict;
  final VoidCallback onKeepLocal;
  final VoidCallback onUseIncoming;

  const _ConflictCard({
    required this.conflict,
    required this.onKeepLocal,
    required this.onUseIncoming,
  });

  @override
  Widget build(BuildContext context) {
    final localLabel =
        DiseaseClass.fromDatabaseKey(conflict.localSample.fieldLabel)
            .displayName;
    final incomingLabel =
        DiseaseClass.fromDatabaseKey(conflict.incomingSample.fieldLabel)
            .displayName;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conflict on ${conflict.sampleCode}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Fields: ${conflict.conflictingFields.join(', ')}'),
            const SizedBox(height: 8),
            Text('This phone: $localLabel (${conflict.localSample.estateName ?? 'no estate'})'),
            Text('Imported phone: $incomingLabel (${conflict.incomingSample.estateName ?? 'no estate'})'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onKeepLocal,
                    child: const Text('Keep Local'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onUseIncoming,
                    child: const Text('Use Imported'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
