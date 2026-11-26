import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/disease_classes.dart';
import '../../../data/models/drive_backup_batch.dart';
import '../drive_backup_view_model.dart';

class DriveBackupScreen extends ConsumerStatefulWidget {
  final List<String>? initialSelectedUuids;

  const DriveBackupScreen({super.key, this.initialSelectedUuids});

  @override
  ConsumerState<DriveBackupScreen> createState() => _DriveBackupScreenState();
}

class _DriveBackupScreenState extends ConsumerState<DriveBackupScreen> {
  Future<void> _pickSamplesDialog(DriveBackupState state) async {
    final tempSelected = Set<String>.from(state.selectedUuids);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Select Samples for Backup'),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: ListView.builder(
              itemCount: state.allActiveSamples.length,
              itemBuilder: (ctx, index) {
                final sample = state.allActiveSamples[index];
                return CheckboxListTile(
                  value: tempSelected.contains(sample.sampleUuid),
                  title: Text(sample.sampleCode),
                  subtitle: Text(
                    '${sample.estateName ?? 'No estate'} • '
                    '${DiseaseClass.fromDatabaseKey(sample.fieldLabel).displayName}',
                  ),
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) {
                        tempSelected.add(sample.sampleUuid);
                      } else {
                        tempSelected.remove(sample.sampleUuid);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(tempSelected),
              child: Text('Select ${tempSelected.length}'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await ref
          .read(
            driveBackupViewModelProvider(widget.initialSelectedUuids).notifier,
          )
          .setSelectedSamples(result);
    }
  }

  Future<void> _openInDrive(String? webViewLink) async {
    final uri = Uri.parse(
      webViewLink ?? 'https://drive.google.com/drive/my-drive',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(driveBackupViewModelProvider(widget.initialSelectedUuids));
    final notifier = ref.read(
      driveBackupViewModelProvider(widget.initialSelectedUuids).notifier,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Drive Backup'),
        actions: [
          IconButton(
            tooltip: 'Backup history',
            icon: const Icon(Icons.history),
            onPressed: () => context.push('/drive-backup/history'),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Account Card ────────────────────────────────────
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              state.isConnected
                                  ? Icons.account_circle
                                  : Icons.no_accounts,
                              size: 32,
                              color: state.isConnected
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    state.isConnected
                                        ? 'Google Account Connected'
                                        : 'Not Connected',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    state.connectedEmail ??
                                        'Connect your Google account for manual My Drive backups',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (state.isConnected)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: state.isUploading
                                      ? null
                                      : notifier.connectGoogleAccount,
                                  child: const Text('Switch Account'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: state.isUploading
                                    ? null
                                    : notifier.disconnectGoogleAccount,
                                child: const Text('Disconnect'),
                              ),
                            ],
                          )
                        else
                          FilledButton.icon(
                            onPressed: state.isUploading
                                ? null
                                : notifier.connectGoogleAccount,
                            icon: const Icon(Icons.login),
                            label: const Text('Connect Google Account'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Backup Type Selection ───────────────────────────
                Text(
                  'Select Records to Back Up',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: RadioGroup<DriveBackupType>(
                    groupValue: state.backupType,
                    onChanged: (v) {
                      if (state.isUploading || v == null) return;
                      notifier.setBackupType(v);
                      if (v == DriveBackupType.selected &&
                          state.selectedUuids.isEmpty) {
                        _pickSamplesDialog(state);
                      }
                    },
                    child: Column(
                      children: [
                        RadioListTile<DriveBackupType>(
                          value: DriveBackupType.changed,
                          enabled: !state.isUploading,
                          title: Text(
                            'New or changed records (${state.changedSamples.length})',
                          ),
                          subtitle: const Text(
                            'Samples not yet uploaded or edited since last confirmed backup',
                          ),
                        ),
                        RadioListTile<DriveBackupType>(
                          value: DriveBackupType.all,
                          enabled: !state.isUploading,
                          title: Text(
                            'All active records (${state.allActiveSamples.length})',
                          ),
                        ),
                        RadioListTile<DriveBackupType>(
                          value: DriveBackupType.selected,
                          enabled: !state.isUploading,
                          title: Text(
                            'Selected samples (${state.selectedUuids.length})',
                          ),
                          secondary: TextButton(
                            onPressed: state.isUploading
                                ? null
                                : () => _pickSamplesDialog(state),
                            child: const Text('Choose'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Destination & Privacy Summary ───────────────────
                Card(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Destination & Contents Summary',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Folder: My Drive / TeaField Capture / ${state.projectCode} / backups/',
                        ),
                        Text('Samples queued: ${state.targetSamples.length}'),
                        Text('Photos queued: ${state.targetPhotoCount}'),
                        const SizedBox(height: 6),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Include exact GPS coordinates'),
                          subtitle: const Text(
                            'Archive includes original images + JSON/CSV + checksums',
                          ),
                          value: state.includeGps,
                          onChanged:
                              state.isUploading ? null : notifier.setIncludeGps,
                        ),
                        Text(
                          'Note: Manual backup only. Capturing photos never starts an upload, and local copies are never deleted after upload.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Upload / Progress Controls ──────────────────────
                if (state.isUploading) ...[
                  LinearProgressIndicator(value: state.progress),
                  const SizedBox(height: 8),
                  Text(
                    state.stageMessage,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: notifier.cancelUpload,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel Upload'),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: state.targetSamples.isEmpty
                        ? null
                        : notifier.startManualUpload,
                    icon: const Icon(Icons.cloud_upload),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Upload Now (${state.targetSamples.length} samples)',
                      ),
                    ),
                  ),

                if (state.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.errorMessage!,
                            style: TextStyle(color: colorScheme.onErrorContainer),
                          ),
                          if (state.lastOutcome != null) ...[
                            const SizedBox(height: 8),
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  notifier.retryBatch(state.lastOutcome!.batch),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry Failed Upload'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                if (state.lastOutcome != null &&
                    state.lastOutcome!.succeeded) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.7),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Backup Uploaded Successfully ✓',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'File: ${state.lastOutcome!.batch.driveFileName}',
                          ),
                          Text(
                            'Account: ${state.lastOutcome!.batch.googleAccountEmail ?? 'unknown'}',
                          ),
                          Text(
                            'Uploaded: ${state.lastOutcome!.batch.sampleCount} samples, '
                            '${state.lastOutcome!.batch.photoCount} photos',
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openInDrive(state.lastOutcome!.webViewLink),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Open in Drive'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push('/drive-backup/history'),
                  icon: const Icon(Icons.history),
                  label: Text('View Backup History (${state.history.length})'),
                ),
              ],
            ),
    );
  }
}
