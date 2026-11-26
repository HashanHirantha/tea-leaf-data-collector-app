import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/disease_classes.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../data/models/leaf_photo.dart';
import '../../../data/models/leaf_sample.dart';
import '../sample_view_model.dart';
import '../widgets/photo_slot_card.dart';

class SampleDetailScreen extends ConsumerStatefulWidget {
  final String sampleUuid;

  const SampleDetailScreen({super.key, required this.sampleUuid});

  @override
  ConsumerState<SampleDetailScreen> createState() => _SampleDetailScreenState();
}

class _SampleDetailScreenState extends ConsumerState<SampleDetailScreen> {
  Future<void> _captureOrRetake(LeafSide side) async {
    await context.push('/camera/${widget.sampleUuid}/${side.databaseKey}');
    if (mounted) {
      await ref
          .read(sampleDetailViewModelProvider(widget.sampleUuid).notifier)
          .load();
    }
  }

  Future<void> _confirmMoveSampleToTrash(LeafSample sample) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move Sample to Trash?'),
        content: Text(
          'Sample ${sample.sampleCode} and all linked upper/lower photos will move to Trash. You can restore them later from Trash.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Move to Trash'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(sampleDetailViewModelProvider(widget.sampleUuid).notifier)
          .moveSampleToTrash();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${sample.sampleCode} moved to Trash')),
        );
        context.pop();
      }
    }
  }

  Future<void> _confirmDeleteSinglePhoto(LeafPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Photo to Trash?'),
        content: Text(
          'This ${photo.leafSide} photo will move to Trash. The sample record and its opposite-side photo will remain active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove Photo'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(sampleDetailViewModelProvider(widget.sampleUuid).notifier)
          .movePhotoToTrash(photo.photoUuid);
    }
  }

  void _showFullScreenPhoto(LeafPhoto photo) {
    if (!File(photo.filePath).existsSync()) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(LeafSide.fromDatabaseKey(photo.leafSide).displayName),
          ),
          body: InteractiveViewer(
            child: Center(
              child: Image.file(File(photo.filePath), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showExpertReviewDialog(LeafSample sample) async {
    var selectedExpertLabel = sample.expertLabel ?? sample.fieldLabel;
    var selectedLabelStatus = LabelStatus.fromDatabaseKey(sample.labelStatus);
    if (selectedLabelStatus == LabelStatus.pending) {
      selectedLabelStatus = LabelStatus.confirmed;
    }
    var markNeedsRecheck = false;
    final reviewerController =
        TextEditingController(text: sample.expertReviewerCode ?? '');

    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Expert Verification'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Field label (preserved): ${DiseaseClass.fromDatabaseKey(sample.fieldLabel).displayName}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedExpertLabel,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Expert-confirmed label',
                    border: OutlineInputBorder(),
                  ),
                  items: DiseaseClass.defaultFieldLabels
                      .map(
                        (dc) => DropdownMenuItem(
                          value: dc.databaseKey,
                          child: Text(dc.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedExpertLabel = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<LabelStatus>(
                  value: selectedLabelStatus,
                  decoration: const InputDecoration(
                    labelText: 'Verification status',
                    border: OutlineInputBorder(),
                  ),
                  items: LabelStatus.values
                      .map(
                        (ls) => DropdownMenuItem(
                          value: ls,
                          child: Text(ls.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedLabelStatus = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reviewerController,
                  decoration: const InputDecoration(
                    labelText: 'Reviewer code',
                    hintText: 'e.g., PATH-01',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Request recheck / additional image'),
                  value: markNeedsRecheck,
                  onChanged: (val) =>
                      setDialogState(() => markNeedsRecheck = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save Review'),
            ),
          ],
        ),
      ),
    );

    final reviewerCode = reviewerController.text;
    reviewerController.dispose();

    if (submit == true && mounted) {
      await ref
          .read(sampleDetailViewModelProvider(widget.sampleUuid).notifier)
          .submitExpertReview(
            expertLabelKey: selectedExpertLabel,
            labelStatus: selectedLabelStatus,
            reviewerCode: reviewerCode,
            markNeedsRecheck: markNeedsRecheck,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sampleDetailViewModelProvider(widget.sampleUuid));
    final notifier =
        ref.read(sampleDetailViewModelProvider(widget.sampleUuid).notifier);
    final colorScheme = Theme.of(context).colorScheme;

    if (state.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final sample = state.sample;
    if (sample == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sample Not Found')),
        body: const Center(
          child: Text('This sample may have been moved to Trash or deleted.'),
        ),
      );
    }

    final status = SampleStatus.fromDatabaseKey(sample.sampleStatus);
    final labelStatus = LabelStatus.fromDatabaseKey(sample.labelStatus);

    return Scaffold(
      appBar: AppBar(
        title: Text(sample.sampleCode),
        actions: [
          IconButton(
            tooltip: 'Edit draft details',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await context.push('/new-sample?sampleUuid=${sample.sampleUuid}');
              if (mounted) notifier.load();
            },
          ),
          IconButton(
            tooltip: 'Share sample QR',
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => context.push('/show-qr/${sample.sampleUuid}'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Sample Identity & Status ───────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sample Status: ${status.displayName}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                      ),
                      if (sample.isImported == 1)
                        const Chip(
                          label: Text('Paired / Imported'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'UUID: ${sample.sampleUuid}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy UUID',
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: sample.sampleUuid),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sample UUID copied')),
                          );
                        },
                      ),
                    ],
                  ),
                  _InfoRow(label: 'Project', value: sample.projectCode),
                  _InfoRow(
                    label: 'Created',
                    value: AppDateUtils.formatDisplayDateTimeFull(
                      sample.createdAtUtc,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Paired Photos ─────────────────────────────────────────
          Text(
            'PAIRED LEAF PHOTOGRAPHS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
          ),
          const SizedBox(height: 8),
          PhotoSlotCard(
            title: 'UPPER SURFACE',
            subtitle: 'Adaxial',
            leafSide: LeafSide.upper,
            photo: state.upperPrimary,
            onCapture: () => _captureOrRetake(LeafSide.upper),
            onRetake: () => _captureOrRetake(LeafSide.upper),
            onViewFull: state.upperPrimary != null
                ? () => _showFullScreenPhoto(state.upperPrimary!)
                : null,
          ),
          if (state.upperPrimary != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                onPressed: () =>
                    _confirmDeleteSinglePhoto(state.upperPrimary!),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove upper photo'),
              ),
            ),
          const SizedBox(height: 8),
          PhotoSlotCard(
            title: 'LOWER SURFACE',
            subtitle: 'Abaxial',
            leafSide: LeafSide.lower,
            photo: state.lowerPrimary,
            onCapture: () => _captureOrRetake(LeafSide.lower),
            onRetake: () => _captureOrRetake(LeafSide.lower),
            onViewFull: state.lowerPrimary != null
                ? () => _showFullScreenPhoto(state.lowerPrimary!)
                : null,
          ),
          if (state.lowerPrimary != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                onPressed: () =>
                    _confirmDeleteSinglePhoto(state.lowerPrimary!),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove lower photo'),
              ),
            ),
          if (state.upperHistory.isNotEmpty || state.lowerHistory.isNotEmpty)
            ExpansionTile(
              title: Text(
                'Retake Audit History (${state.upperHistory.length + state.lowerHistory.length})',
              ),
              children: [
                ...state.upperHistory,
                ...state.lowerHistory,
              ]
                  .map(
                    (p) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.history),
                      title: Text('${p.leafSide.toUpperCase()} — ${p.deviceModel ?? 'unknown'}'),
                      subtitle: Text(
                        AppDateUtils.formatDisplayDateTimeFull(p.capturedAtUtc),
                      ),
                      onTap: () => _showFullScreenPhoto(p),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 12),

          // ── Field Label & Expert Verification ─────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Disease Labels & Verification',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: sample.fieldLabel,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Field label (provisional)',
                      border: OutlineInputBorder(),
                    ),
                    items: DiseaseClass.defaultFieldLabels
                        .map(
                          (dc) => DropdownMenuItem(
                            value: dc.databaseKey,
                            child: Text(dc.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: state.isSaving
                        ? null
                        : (val) {
                            if (val != null) notifier.updateFieldLabel(val);
                          },
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Expert Label',
                    value: sample.expertLabel != null
                        ? DiseaseClass.fromDatabaseKey(sample.expertLabel)
                            .displayName
                        : 'Not yet reviewed',
                  ),
                  _InfoRow(
                    label: 'Label Status',
                    value: labelStatus.displayName,
                  ),
                  if (sample.expertReviewerCode != null &&
                      sample.expertReviewerCode!.isNotEmpty)
                    _InfoRow(
                      label: 'Reviewer',
                      value:
                          '${sample.expertReviewerCode} (${AppDateUtils.formatDisplayDate(sample.expertReviewedAtUtc)})',
                    ),
                  if (sample.severity != null)
                    _InfoRow(
                      label: 'Severity',
                      value: 'Level ${sample.severity}',
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showExpertReviewDialog(sample),
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Record Expert Verification'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Plantation & GPS Provenance ───────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plantation & Provenance',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Estate',
                    value: sample.estateName ?? '—',
                  ),
                  _InfoRow(label: 'Region', value: sample.region ?? '—'),
                  _InfoRow(label: 'District', value: sample.district ?? '—'),
                  _InfoRow(
                    label: 'Bush / Plot',
                    value: sample.bushPlotCode ?? '—',
                  ),
                  _InfoRow(
                    label: 'Collector',
                    value: sample.collectorCode ?? '—',
                  ),
                  _InfoRow(
                    label: 'Sample GPS',
                    value: sample.hasGps
                        ? '${sample.sampleLatitude!.toStringAsFixed(6)}, '
                            '${sample.sampleLongitude!.toStringAsFixed(6)} '
                            '(±${sample.sampleGpsAccuracyM?.toStringAsFixed(1) ?? '?'} m)'
                        : GpsStatus.fromDatabaseKey(sample.sampleGpsStatus)
                            .displayName,
                  ),
                  if (sample.symptomNotes != null &&
                      sample.symptomNotes!.isNotEmpty)
                    _InfoRow(label: 'Symptoms', value: sample.symptomNotes!),
                  if (sample.otherNotes != null &&
                      sample.otherNotes!.isNotEmpty)
                    _InfoRow(label: 'Other notes', value: sample.otherNotes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Actions ───────────────────────────────────────────────
          OutlinedButton.icon(
            onPressed: () => context.push('/show-qr/${sample.sampleUuid}'),
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Share Sample QR for Second Phone'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            onPressed: () => _confirmMoveSampleToTrash(sample),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Move this sample to Trash'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
