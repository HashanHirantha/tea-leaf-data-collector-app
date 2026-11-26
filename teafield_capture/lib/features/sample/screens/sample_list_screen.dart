import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/disease_classes.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../data/models/leaf_photo.dart';
import '../../../data/models/leaf_sample.dart';
import '../sample_view_model.dart';

class SampleListScreen extends ConsumerStatefulWidget {
  const SampleListScreen({super.key});

  @override
  ConsumerState<SampleListScreen> createState() => _SampleListScreenState();
}

class _SampleListScreenState extends ConsumerState<SampleListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmMoveSelectedToTrash(int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move Samples to Trash?'),
        content: Text(
          'Moving $count sample(s) to Trash also moves their linked upper/lower photos and metadata. You can restore them later from Settings → Data Management → Trash.',
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
          .read(sampleListViewModelProvider.notifier)
          .moveSelectedToTrash();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sampleListViewModelProvider);
    final notifier = ref.read(sampleListViewModelProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: state.isSelectionMode
            ? Text('${state.selectedSampleUuids.length} selected')
            : const Text('Saved Samples'),
        leading: state.isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: notifier.clearSelection,
              )
            : null,
        actions: [
          if (state.isSelectionMode) ...[
            IconButton(
              tooltip: 'Select all',
              icon: const Icon(Icons.select_all),
              onPressed: notifier.selectAll,
            ),
          ] else ...[
            IconButton(
              tooltip: 'Search',
              icon: Icon(_showSearchBar ? Icons.search_off : Icons.search),
              onPressed: () {
                setState(() {
                  _showSearchBar = !_showSearchBar;
                  if (!_showSearchBar) {
                    _searchController.clear();
                    notifier.setSearchQuery('');
                  }
                });
              },
            ),
            IconButton(
              tooltip: 'More filters',
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showFilterSheet(context, state, notifier),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (_showSearchBar)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: notifier.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search sample code, estate, plot, label...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            notifier.setSearchQuery('');
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _StatusChip(
                  label: 'All',
                  selected: state.statusFilter == 'all' &&
                      state.missingSideFilter == 'none',
                  onTap: () {
                    notifier.setStatusFilter('all');
                    notifier.setMissingSideFilter('none');
                  },
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: 'Incomplete',
                  selected: state.statusFilter == 'incomplete',
                  onTap: () => notifier.setStatusFilter('incomplete'),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: 'Ready for Review',
                  selected: state.statusFilter == 'ready_for_review',
                  onTap: () => notifier.setStatusFilter('ready_for_review'),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: 'Verified',
                  selected: state.statusFilter == 'verified',
                  onTap: () => notifier.setStatusFilter('verified'),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: 'Missing Side',
                  selected: state.missingSideFilter == 'any',
                  onTap: () => notifier.setMissingSideFilter(
                    state.missingSideFilter == 'any' ? 'none' : 'any',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.samples.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.eco_outlined,
                                size: 64,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No leaf samples match the current filter.',
                                style: Theme.of(context).textTheme.titleMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () async {
                                  await context.push('/new-sample');
                                  if (mounted) notifier.loadSamples();
                                },
                                icon: const Icon(Icons.add_a_photo),
                                label: const Text('Collect First Sample'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: notifier.loadSamples,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                          itemCount: state.samples.length,
                          itemBuilder: (context, index) {
                            final sample = state.samples[index];
                            final pair = state.photosBySample[sample.sampleUuid];
                            final isSelected = state.selectedSampleUuids
                                .contains(sample.sampleUuid);

                            return _SampleListTile(
                              sample: sample,
                              upper: pair?.upper,
                              lower: pair?.lower,
                              isSelected: isSelected,
                              isSelectionMode: state.isSelectionMode,
                              onTap: () async {
                                if (state.isSelectionMode) {
                                  notifier.toggleSelection(sample.sampleUuid);
                                } else {
                                  await context
                                      .push('/sample/${sample.sampleUuid}');
                                  if (mounted) notifier.loadSamples();
                                }
                              },
                              onLongPress: () =>
                                  notifier.toggleSelection(sample.sampleUuid),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      bottomNavigationBar: state.isSelectionMode
          ? BottomAppBar(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      final ids = state.selectedSampleUuids.toList();
                      notifier.clearSelection();
                      context.push('/export', extra: ids);
                    },
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Export'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final ids = state.selectedSampleUuids.toList();
                      notifier.clearSelection();
                      context.push('/drive-backup', extra: ids);
                    },
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Drive Backup'),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.error,
                    ),
                    onPressed: () => _confirmMoveSelectedToTrash(
                      state.selectedSampleUuids.length,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Trash'),
                  ),
                ],
              ),
            )
          : null,
      floatingActionButton: state.isSelectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/new-sample');
                if (mounted) notifier.loadSamples();
              },
              icon: const Icon(Icons.add_a_photo),
              label: const Text('New Sample'),
            ),
    );
  }

  void _showFilterSheet(
    BuildContext context,
    SampleListState state,
    SampleListViewModel notifier,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filter Samples',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: state.estateFilter,
              decoration: const InputDecoration(
                labelText: 'Estate',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All estates')),
                ...state.availableEstates.map(
                  (e) => DropdownMenuItem(value: e, child: Text(e)),
                ),
              ],
              onChanged: (val) {
                if (val != null) notifier.setEstateFilter(val);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: state.labelFilter,
              decoration: const InputDecoration(
                labelText: 'Field Label',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All labels')),
                ...DiseaseClass.defaultFieldLabels.map(
                  (dc) => DropdownMenuItem(
                    value: dc.databaseKey,
                    child: Text(dc.displayName),
                  ),
                ),
              ],
              onChanged: (val) {
                if (val != null) notifier.setLabelFilter(val);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: state.missingSideFilter,
              decoration: const InputDecoration(
                labelText: 'Missing Side',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Any')),
                DropdownMenuItem(value: 'any', child: Text('Missing either side')),
                DropdownMenuItem(value: 'upper', child: Text('Missing upper side')),
                DropdownMenuItem(value: 'lower', child: Text('Missing lower side')),
              ],
              onChanged: (val) {
                if (val != null) notifier.setMissingSideFilter(val);
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    notifier.setEstateFilter('all');
                    notifier.setLabelFilter('all');
                    notifier.setMissingSideFilter('none');
                    notifier.setStatusFilter('all');
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Reset Filters'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _SampleListTile extends StatelessWidget {
  final LeafSample sample;
  final LeafPhoto? upper;
  final LeafPhoto? lower;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SampleListTile({
    required this.sample,
    required this.upper,
    required this.lower,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = SampleStatus.fromDatabaseKey(sample.sampleStatus);
    final disease = DiseaseClass.fromDatabaseKey(sample.fieldLabel);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isSelected
          ? colorScheme.primaryContainer.withOpacity(0.45)
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                  ),
                ),
              _MiniThumb(photo: upper, label: 'U'),
              const SizedBox(width: 4),
              _MiniThumb(photo: lower, label: 'L'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sample.sampleCode,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      disease.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${sample.estateName ?? 'No estate'} • ${AppDateUtils.formatDisplayDateTime(sample.createdAtUtc)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniThumb extends StatelessWidget {
  final LeafPhoto? photo;
  final String label;

  const _MiniThumb({required this.photo, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasFile = photo != null && File(photo!.filePath).existsSync();

    return Container(
      width: 44,
      height: 58,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: photo != null
              ? colorScheme.primary
              : colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasFile
          ? Image.file(File(photo!.filePath), fit: BoxFit.cover)
          : Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SampleStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      SampleStatus.verified => (const Color(0xFFD7F2DA), const Color(0xFF1B5E20)),
      SampleStatus.readyForReview => (
          const Color(0xFFE3F2FD),
          const Color(0xFF0D47A1)
        ),
      SampleStatus.needsRecheck => (
          const Color(0xFFFFEBEE),
          const Color(0xFFB71C1C)
        ),
      SampleStatus.incomplete => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100)
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
