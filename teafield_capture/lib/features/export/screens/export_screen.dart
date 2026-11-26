import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/disease_classes.dart';
import '../export/transfer_view_model.dart';

class ExportScreen extends ConsumerStatefulWidget {
  final List<String>? initialSelectedUuids;

  const ExportScreen({super.key, this.initialSelectedUuids});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  Future<void> _selectSamplesDialog(ExportState state) async {
    final tempSelected = Set<String>.from(state.selectedUuids);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Select Samples to Export'),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: ListView.builder(
              itemCount: state.allActiveSamples.length,
              itemBuilder: (ctx, index) {
                final sample = state.allActiveSamples[index];
                final checked = tempSelected.contains(sample.sampleUuid);
                return CheckboxListTile(
                  value: checked,
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
              child: Text('Use ${tempSelected.length}'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      ref
          .read(exportViewModelProvider(widget.initialSelectedUuids).notifier)
          .setSelectedUuids(result);
    }
  }

  Future<void> _shareFile(String filePath, String fileName) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'TeaField Capture research export: $fileName',
    );
  }

  Future<void> _saveToDeviceLocation(String filePath, String fileName) async {
    final bytes = await File(filePath).readAsBytes();
    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save research export',
      fileName: fileName,
      bytes: bytes,
    );
    if (savedPath != null && mounted) {
      // On desktop platforms saveFile returns a destination path without writing bytes.
      final dest = File(savedPath);
      if (!await dest.exists() || await dest.length() == 0) {
        await dest.writeAsBytes(bytes, flush: true);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $savedPath')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(exportViewModelProvider(widget.initialSelectedUuids));
    final notifier = ref
        .read(exportViewModelProvider(widget.initialSelectedUuids).notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Export Data')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '1. Export Format',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                ...ExportFormatType.values.map(
                  (fmt) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: RadioListTile<ExportFormatType>(
                      value: fmt,
                      groupValue: state.format,
                      title: Text(fmt.title),
                      subtitle: Text(fmt.subtitle),
                      onChanged: state.isExporting
                          ? null
                          : (val) {
                              if (val != null) notifier.setFormat(val);
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '2. Sample Scope',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        value: true,
                        groupValue: state.exportAll,
                        title: Text(
                          'All active samples (${state.allActiveSamples.length})',
                        ),
                        onChanged: state.isExporting
                            ? null
                            : (val) {
                                if (val != null) notifier.setExportAll(val);
                              },
                      ),
                      RadioListTile<bool>(
                        value: false,
                        groupValue: state.exportAll,
                        title: Text(
                          'Selected samples (${state.selectedUuids.length})',
                        ),
                        secondary: TextButton(
                          onPressed: state.isExporting
                              ? null
                              : () => _selectSamplesDialog(state),
                          child: const Text('Choose'),
                        ),
                        onChanged: state.isExporting
                            ? null
                            : (val) {
                                if (val != null) {
                                  notifier.setExportAll(val);
                                  if (state.selectedUuids.isEmpty) {
                                    _selectSamplesDialog(state);
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Omit exact GPS coordinates'),
                  subtitle: const Text(
                    'Keep region/district only when sharing outside the research team',
                  ),
                  value: state.omitGps,
                  onChanged: state.isExporting ? null : notifier.setOmitGps,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      state.isExporting || state.targetSamples.isEmpty
                          ? null
                          : notifier.runExport,
                  icon: const Icon(Icons.archive),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      state.isExporting
                          ? 'Creating Export...'
                          : 'Generate ${state.format.title} (${state.targetSamples.length} leaves)',
                    ),
                  ),
                ),
                if (state.isExporting) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: state.progress > 0 ? state.progress : null),
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
                if (state.result != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: colorScheme.primaryContainer.withOpacity(0.6),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Export Ready',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text('File: ${state.result!.fileName}'),
                          Text(
                            'Contents: ${state.result!.sampleCount} samples, '
                            '${state.result!.photoCount} photos',
                          ),
                          Text(
                            'Size: ${(state.result!.fileSizeBytes / 1024).toStringAsFixed(1)} KB',
                          ),
                          Text(
                            'SHA-256: ${state.result!.sha256.substring(0, 16)}...',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _saveToDeviceLocation(
                                    state.result!.filePath,
                                    state.result!.fileName,
                                  ),
                                  icon: const Icon(Icons.save_alt),
                                  label: const Text('Save As'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _shareFile(
                                    state.result!.filePath,
                                    state.result!.fileName,
                                  ),
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
