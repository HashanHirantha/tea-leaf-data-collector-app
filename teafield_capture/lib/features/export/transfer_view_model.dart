import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/package_transfer_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/import_record.dart';
import '../../data/models/leaf_sample.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/sample_repository.dart';

enum ExportFormatType {
  fullZip('Full Research ZIP', 'Original photos + JSON/CSV + checksums'),
  sampleCsv('CSV Summary', 'One row per physical leaf sample'),
  imageCsv('Image-level CSV', 'One row per captured photograph');

  const ExportFormatType(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

class ExportState {
  final ExportFormatType format;
  final List<LeafSample> allActiveSamples;
  final Set<String> selectedUuids;
  final bool exportAll;
  final bool omitGps;
  final bool isLoading;
  final bool isExporting;
  final double progress;
  final ExportPackageResult? result;
  final String? errorMessage;

  const ExportState({
    this.format = ExportFormatType.fullZip,
    this.allActiveSamples = const [],
    this.selectedUuids = const {},
    this.exportAll = true,
    this.omitGps = false,
    this.isLoading = true,
    this.isExporting = false,
    this.progress = 0.0,
    this.result,
    this.errorMessage,
  });

  List<LeafSample> get targetSamples => exportAll
      ? allActiveSamples
      : allActiveSamples
          .where((s) => selectedUuids.contains(s.sampleUuid))
          .toList();

  ExportState copyWith({
    ExportFormatType? format,
    List<LeafSample>? allActiveSamples,
    Set<String>? selectedUuids,
    bool? exportAll,
    bool? omitGps,
    bool? isLoading,
    bool? isExporting,
    double? progress,
    ExportPackageResult? result,
    bool clearResult = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExportState(
      format: format ?? this.format,
      allActiveSamples: allActiveSamples ?? this.allActiveSamples,
      selectedUuids: selectedUuids ?? this.selectedUuids,
      exportAll: exportAll ?? this.exportAll,
      omitGps: omitGps ?? this.omitGps,
      isLoading: isLoading ?? this.isLoading,
      isExporting: isExporting ?? this.isExporting,
      progress: progress ?? this.progress,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ExportViewModel extends StateNotifier<ExportState> {
  ExportViewModel({List<String>? initialSelectedUuids})
      : super(
          ExportState(
            exportAll:
                initialSelectedUuids == null || initialSelectedUuids.isEmpty,
            selectedUuids: initialSelectedUuids?.toSet() ?? const {},
          ),
        ) {
    loadSamples();
  }

  final SampleRepository _sampleRepo = SampleRepository();
  final PackageTransferService _transfer = PackageTransferService.instance;
  final SettingsService _settings = SettingsService.instance;

  Future<void> loadSamples() async {
    state = state.copyWith(isLoading: true);
    final projectCode = await _settings.getProjectCode();
    final samples =
        await _sampleRepo.getAllActiveSamples(projectCode: projectCode);
    state = state.copyWith(allActiveSamples: samples, isLoading: false);
  }

  void setFormat(ExportFormatType format) {
    state = state.copyWith(format: format, clearResult: true, clearError: true);
  }

  void setExportAll(bool exportAll) {
    state = state.copyWith(exportAll: exportAll, clearResult: true);
  }

  void setSelectedUuids(Set<String> uuids) {
    state = state.copyWith(
      selectedUuids: uuids,
      exportAll: false,
      clearResult: true,
    );
  }

  void setOmitGps(bool omit) {
    state = state.copyWith(omitGps: omit, clearResult: true);
  }

  Future<void> runExport() async {
    final targets = state.targetSamples;
    if (targets.isEmpty) {
      state = state.copyWith(
        errorMessage: 'No samples selected for export.',
      );
      return;
    }

    state = state.copyWith(
      isExporting: true,
      progress: 0.0,
      clearResult: true,
      clearError: true,
    );

    try {
      final ExportPackageResult result;
      switch (state.format) {
        case ExportFormatType.fullZip:
          result = await _transfer.exportResearchZip(
            samples: targets,
            omitGps: state.omitGps,
            onProgress: (p) => state = state.copyWith(progress: p),
          );
        case ExportFormatType.sampleCsv:
          result = await _transfer.exportSampleSummaryCsv(
            samples: targets,
            omitGps: state.omitGps,
          );
        case ExportFormatType.imageCsv:
          result = await _transfer.exportImageLevelCsv(
            samples: targets,
            omitGps: state.omitGps,
          );
      }

      state = state.copyWith(
        isExporting: false,
        progress: 1.0,
        result: result,
      );
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        errorMessage: 'Export failed: $e',
      );
    }
  }
}

final exportViewModelProvider = StateNotifierProvider.autoDispose
    .family<ExportViewModel, ExportState, List<String>?>(
  (ref, initialSelected) =>
      ExportViewModel(initialSelectedUuids: initialSelected),
);

class ImportState {
  final PackagePreview? preview;
  final ImportResult? result;
  final List<ImportConflict> pendingConflicts;
  final List<ImportRecord> history;
  final bool isInspecting;
  final bool isImporting;
  final String? errorMessage;

  const ImportState({
    this.preview,
    this.result,
    this.pendingConflicts = const [],
    this.history = const [],
    this.isInspecting = false,
    this.isImporting = false,
    this.errorMessage,
  });

  ImportState copyWith({
    PackagePreview? preview,
    bool clearPreview = false,
    ImportResult? result,
    bool clearResult = false,
    List<ImportConflict>? pendingConflicts,
    List<ImportRecord>? history,
    bool? isInspecting,
    bool? isImporting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ImportState(
      preview: clearPreview ? null : (preview ?? this.preview),
      result: clearResult ? null : (result ?? this.result),
      pendingConflicts: pendingConflicts ?? this.pendingConflicts,
      history: history ?? this.history,
      isInspecting: isInspecting ?? this.isInspecting,
      isImporting: isImporting ?? this.isImporting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ImportViewModel extends StateNotifier<ImportState> {
  ImportViewModel() : super(const ImportState()) {
    loadHistory();
  }

  final PackageTransferService _transfer = PackageTransferService.instance;
  final SampleRepository _sampleRepo = SampleRepository();
  final BackupRepository _backupRepo = BackupRepository();

  Future<void> loadHistory() async {
    final history = await _backupRepo.getImportHistory();
    state = state.copyWith(history: history);
  }

  Future<void> inspectFile(String zipPath) async {
    state = state.copyWith(
      isInspecting: true,
      clearPreview: true,
      clearResult: true,
      clearError: true,
      pendingConflicts: const [],
    );

    try {
      final preview = await _transfer.inspectZipPackage(zipPath);
      state = state.copyWith(isInspecting: false, preview: preview);
    } catch (e) {
      state = state.copyWith(
        isInspecting: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> runImport() async {
    final preview = state.preview;
    if (preview == null) return;

    state = state.copyWith(isImporting: true, clearError: true);
    try {
      final result = await _transfer.importZipPackage(preview.zipPath);
      final history = await _backupRepo.getImportHistory();

      state = state.copyWith(
        isImporting: false,
        result: result,
        pendingConflicts: result.conflicts,
        history: history,
      );
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        errorMessage: 'Import failed: $e',
      );
    }
  }

  /// Resolves a flagged conflict explicitly in favor of either the local or
  /// incoming sample metadata. Never overwrites confirmed expert labels.
  Future<void> resolveConflict({
    required ImportConflict conflict,
    required bool useIncoming,
  }) async {
    if (useIncoming) {
      final local = conflict.localSample;
      final incoming = conflict.incomingSample;
      final updated = local.copyWith(
        fieldLabel: incoming.fieldLabel,
        estateName: incoming.estateName ?? local.estateName,
        bushPlotCode: incoming.bushPlotCode ?? local.bushPlotCode,
        updatedAtUtc: AppDateUtils.nowUtcIso(),
      );
      await _sampleRepo.updateSample(updated);
    }

    final remaining = state.pendingConflicts
        .where((c) => c.sampleUuid != conflict.sampleUuid)
        .toList();
    state = state.copyWith(pendingConflicts: remaining);
  }

  Future<bool> fileExists(String path) => File(path).exists();
}

final importViewModelProvider =
    StateNotifierProvider.autoDispose<ImportViewModel, ImportState>(
  (ref) => ImportViewModel(),
);
