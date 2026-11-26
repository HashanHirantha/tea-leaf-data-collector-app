import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/disease_classes.dart';
import '../../../data/models/leaf_sample.dart';
import '../capture_view_model.dart';
import '../widgets/photo_slot_card.dart';

/// Single-screen paired capture and immediate field-labeling form.
///
/// Both upper (adaxial) and lower (abaxial) photo slots belong to the same
/// physical leaf sample UUID and share one provisional field label.
class NewSampleScreen extends ConsumerStatefulWidget {
  final String? existingSampleUuid;

  const NewSampleScreen({super.key, this.existingSampleUuid});

  @override
  ConsumerState<NewSampleScreen> createState() => _NewSampleScreenState();
}

class _NewSampleScreenState extends ConsumerState<NewSampleScreen> {
  final TextEditingController _bushController = TextEditingController();
  final TextEditingController _collectorController = TextEditingController();
  final TextEditingController _symptomController = TextEditingController();
  final TextEditingController _otherNotesController = TextEditingController();
  bool _controllersSeeded = false;

  @override
  void dispose() {
    _bushController.dispose();
    _collectorController.dispose();
    _symptomController.dispose();
    _otherNotesController.dispose();
    super.dispose();
  }

  void _syncControllersOnce(CaptureState state) {
    if (_controllersSeeded || state.isInitializing) return;
    _bushController.text = state.bushPlotCode;
    _collectorController.text = state.collectorCode;
    _symptomController.text = state.symptomNotes;
    _otherNotesController.text = state.otherNotes;
    _controllersSeeded = true;
  }

  Future<void> _captureSide(LeafSide side) async {
    final state = ref.read(captureViewModelProvider(widget.existingSampleUuid));
    final sample = state.sample;
    if (sample == null) return;

    // Persist any typed form values before opening camera.
    await ref
        .read(captureViewModelProvider(widget.existingSampleUuid).notifier)
        .saveSample(asIncomplete: true);

    if (!mounted) return;
    await context.push('/camera/${sample.sampleUuid}/${side.databaseKey}');

    if (mounted) {
      await ref
          .read(captureViewModelProvider(widget.existingSampleUuid).notifier)
          .reloadPhotos();
    }
  }

  Future<void> _openShareQr() async {
    final notifier =
        ref.read(captureViewModelProvider(widget.existingSampleUuid).notifier);
    final saved = await notifier.saveSample(asIncomplete: true);
    if (saved == null || !mounted) return;
    await context.push('/show-qr/${saved.sampleUuid}');
  }

  Future<void> _handleSave({required bool asIncomplete}) async {
    final state = ref.read(captureViewModelProvider(widget.existingSampleUuid));
    final notifier =
        ref.read(captureViewModelProvider(widget.existingSampleUuid).notifier);

    if (!asIncomplete && !state.hasAnyPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Take at least one leaf photo, or tap "Save incomplete" to keep this draft.',
          ),
        ),
      );
      return;
    }

    if (!asIncomplete && !state.hasBothPhotos) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('One Leaf Surface Missing'),
          content: const Text(
            'Only one side of the leaf has been photographed. Save it as an incomplete sample so the remaining side can be added later?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep Editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save Incomplete'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final saved = await notifier.saveSample(asIncomplete: asIncomplete);
    if (!mounted || saved == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved.sampleStatus == SampleStatus.incomplete.databaseKey
              ? 'Saved incomplete sample ${saved.sampleCode}'
              : 'Saved sample ${saved.sampleCode} (${saved.sampleStatus})',
        ),
      ),
    );
    context.pop();
  }

  Future<void> _promptCustomDropdownValue({
    required String title,
    required void Function(String) onApply,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enter $title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: title,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Use Value'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      onApply(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureViewModelProvider(widget.existingSampleUuid));
    final notifier =
        ref.read(captureViewModelProvider(widget.existingSampleUuid).notifier);
    _syncControllersOnce(state);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('New Leaf Sample'),
            if (state.sample != null)
              Text(
                'ID: ${state.sample!.sampleCode}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ),
      body: state.isInitializing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.errorMessage != null)
                    Card(
                      color: colorScheme.errorContainer,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ),

                  // ── GPS Banner ──────────────────────────────────────
                  _GpsStatusBanner(
                    state: state,
                    onRefresh: notifier.refreshGpsFix,
                  ),
                  const SizedBox(height: 16),

                  // ── Plantation / Location Details ───────────────────
                  _DropdownWithCustomField(
                    label: 'Estate / Plantation',
                    value: state.selectedEstate,
                    options: state.estates,
                    onChanged: notifier.setEstate,
                    onCustomRequested: () => _promptCustomDropdownValue(
                      title: 'Estate / Plantation',
                      onApply: notifier.setEstate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DropdownWithCustomField(
                          label: 'Region',
                          value: state.selectedRegion,
                          options: state.regions,
                          onChanged: notifier.setRegion,
                          onCustomRequested: () => _promptCustomDropdownValue(
                            title: 'Region',
                            onApply: notifier.setRegion,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DropdownWithCustomField(
                          label: 'District',
                          value: state.selectedDistrict,
                          options: state.districts,
                          onChanged: notifier.setDistrict,
                          onCustomRequested: () => _promptCustomDropdownValue(
                            title: 'District',
                            onApply: notifier.setDistrict,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bushController,
                    onChanged: notifier.setBushPlotCode,
                    decoration: const InputDecoration(
                      labelText: 'Bush / Plot Code',
                      hintText: 'e.g., PLOT-B12 / BUSH-04',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Leaf Photographs (Both sides on one screen) ─────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LEAF PHOTOGRAPHS (SAME LEAF)',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showProtocolDialog(context),
                        icon: const Icon(Icons.checklist, size: 18),
                        label: const Text('Capture guide'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final upperCard = PhotoSlotCard(
                        title: 'UPPER SURFACE',
                        subtitle: 'Adaxial (top side)',
                        leafSide: LeafSide.upper,
                        photo: state.upperPhoto,
                        onCapture: () => _captureSide(LeafSide.upper),
                        onRetake: () => _captureSide(LeafSide.upper),
                      );
                      final lowerCard = PhotoSlotCard(
                        title: 'LOWER SURFACE',
                        subtitle: 'Abaxial (underside)',
                        leafSide: LeafSide.lower,
                        photo: state.lowerPhoto,
                        onCapture: () => _captureSide(LeafSide.lower),
                        onRetake: () => _captureSide(LeafSide.lower),
                      );

                      if (constraints.maxWidth >= 600) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: upperCard),
                            const SizedBox(width: 12),
                            Expanded(child: lowerCard),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          upperCard,
                          const SizedBox(height: 12),
                          lowerCard,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── Shared Field Label (One label per leaf) ─────────
                  Text(
                    'FIELD LABEL (ONE LABEL FOR THIS LEAF)',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: state.fieldLabelKey,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Provisional field label',
                      border: OutlineInputBorder(),
                    ),
                    items: DiseaseClass.defaultFieldLabels
                        .map(
                          (dc) => DropdownMenuItem<String>(
                            value: dc.databaseKey,
                            child: Text(dc.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) notifier.setFieldLabel(val);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Severity (optional)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [0, 1, 2, 3].map((level) {
                      final selected = state.severity == level;
                      return ChoiceChip(
                        label: Text('Level $level'),
                        selected: selected,
                        onSelected: (_) => notifier.setSeverity(level),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _symptomController,
                    onChanged: notifier.setSymptomNotes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Symptoms / field notes',
                      hintText: 'Spots, margin blight, blister pustules, etc.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _collectorController,
                    onChanged: notifier.setCollectorCode,
                    decoration: const InputDecoration(
                      labelText: 'Collector code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otherNotesController,
                    onChanged: notifier.setOtherNotes,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Other notes (shade, weather, cultivar)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Actions ─────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: state.isSaving ? null : _openShareQr,
                          icon: const Icon(Icons.qr_code_2),
                          label: const Text('Share sample QR'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: state.isSaving
                              ? null
                              : () => _handleSave(asIncomplete: false),
                          icon: state.isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: const Text('Save sample'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: state.isSaving
                          ? null
                          : () => _handleSave(asIncomplete: true),
                      icon: const Icon(Icons.pending_actions),
                      label: const Text('Save incomplete'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  void _showProtocolDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Image Capture Protocol'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1. Photograph upper and lower surfaces of the SAME leaf.'),
              SizedBox(height: 6),
              Text('2. Keep the entire leaf visible and sharply in focus.'),
              SizedBox(height: 6),
              Text('3. Avoid harsh shadows, glare, or cluttered backgrounds.'),
              SizedBox(height: 6),
              Text('4. Do not apply beauty modes, filters, or color edits.'),
              SizedBox(height: 6),
              Text('5. If symptoms are unclear, select "Not sure — needs expert review".'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _GpsStatusBanner extends StatelessWidget {
  final CaptureState state;
  final VoidCallback onRefresh;

  const _GpsStatusBanner({
    required this.state,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final gps = state.gpsResult;
    final colorScheme = Theme.of(context).colorScheme;

    if (state.isLoadingGps) {
      return Card(
        color: colorScheme.surfaceContainerHighest,
        child: const ListTile(
          leading: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('Acquiring foreground GPS fix...'),
        ),
      );
    }

    if (gps.isCaptured) {
      return Card(
        color: colorScheme.primaryContainer.withValues(alpha: 0.6),
        child: ListTile(
          leading: Icon(Icons.gps_fixed, color: colorScheme.primary),
          title: Text(
            'GPS: Captured ✓  Accuracy: ${gps.accuracyMeters?.toStringAsFixed(1) ?? '?'} m',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${gps.latitude!.toStringAsFixed(6)}, ${gps.longitude!.toStringAsFixed(6)}',
          ),
          trailing: IconButton(
            tooltip: 'Refresh GPS',
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
          ),
        ),
      );
    }

    return Card(
      color: colorScheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.gps_off, color: colorScheme.onTertiaryContainer),
        title: Text(
          'GPS: ${gps.status.displayName}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.onTertiaryContainer,
          ),
        ),
        subtitle: Text(
          gps.errorMessage ??
              'Location unavailable — sample can still be saved.',
          style: TextStyle(color: colorScheme.onTertiaryContainer),
        ),
        trailing: IconButton(
          tooltip: 'Retry GPS',
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh,
        ),
      ),
    );
  }
}

class _DropdownWithCustomField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final VoidCallback onCustomRequested;

  const _DropdownWithCustomField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.onCustomRequested,
  });

  @override
  Widget build(BuildContext context) {
    final itemsList = <String>{...options};
    if (value != null && value!.isNotEmpty) {
      itemsList.add(value!);
    }

    const customSentinel = '__custom__';

    return DropdownButtonFormField<String>(
      initialValue: (value != null && value!.isNotEmpty) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        ...itemsList.map(
          (item) => DropdownMenuItem<String>(
            value: item,
            child: Text(item, overflow: TextOverflow.ellipsis),
          ),
        ),
        const DropdownMenuItem<String>(
          value: customSentinel,
          child: Text('+ Enter custom value...'),
        ),
      ],
      onChanged: (val) {
        if (val == customSentinel) {
          onCustomRequested();
        } else {
          onChanged(val);
        }
      },
    );
  }
}
