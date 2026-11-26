import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../data/models/leaf_sample.dart';
import '../pairing_view_model.dart';

/// Allows a second phone to scan Phone A's QR code offline, select which
/// surface (`upper` or `lower`) it is capturing, and photograph that side
/// against the shared `sample_uuid`.
class JoinSampleScreen extends ConsumerStatefulWidget {
  const JoinSampleScreen({super.key});

  @override
  ConsumerState<JoinSampleScreen> createState() => _JoinSampleScreenState();
}

class _JoinSampleScreenState extends ConsumerState<JoinSampleScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final current = ref.read(joinSampleViewModelProvider);
    if (current.isValid || current.isProcessing) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        await ref
            .read(joinSampleViewModelProvider.notifier)
            .handleScannedRawData(raw);
        break;
      }
    }
  }

  Future<void> _captureAssignedSide() async {
    final state = ref.read(joinSampleViewModelProvider);
    final notifier = ref.read(joinSampleViewModelProvider.notifier);

    final linkedSample = await notifier.ensureLocalLinkedSample();
    if (linkedSample == null || !mounted) return;

    final photoResult = await context.push(
      '/camera/${linkedSample.sampleUuid}/${state.selectedSide.databaseKey}',
    );

    if (mounted && photoResult != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${state.selectedSide.databaseKey} photo under ${linkedSample.sampleCode}',
          ),
        ),
      );
      context.pushReplacement('/sample/${linkedSample.sampleUuid}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(joinSampleViewModelProvider);
    final notifier = ref.read(joinSampleViewModelProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Existing Sample'),
        actions: [
          if (!state.isValid) ...[
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _scannerController,
              builder: (context, scannerState, child) {
                switch (scannerState.torchState) {
                  case TorchState.on:
                    return IconButton(
                      icon: const Icon(Icons.flash_on, color: Colors.amber),
                      onPressed: () => _scannerController.toggleTorch(),
                    );
                  case TorchState.off:
                    return IconButton(
                      icon: const Icon(Icons.flash_off),
                      onPressed: () => _scannerController.toggleTorch(),
                    );
                  case TorchState.auto:
                    return IconButton(
                      icon: const Icon(Icons.flash_auto),
                      onPressed: () => _scannerController.toggleTorch(),
                    );
                  case TorchState.unavailable:
                    return const IconButton(
                      icon: Icon(Icons.no_flash),
                      onPressed: null,
                    );
                }
              },
            ),
            IconButton(
              tooltip: 'Switch camera',
              icon: const Icon(Icons.cameraswitch),
              onPressed: () => _scannerController.switchCamera(),
            ),
          ],
        ],
      ),
      body: state.isValid && state.parsedData != null
          ? _buildJoinedConfirmation(context, state, notifier)
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      MobileScanner(
                        controller: _scannerController,
                        onDetect: _onDetect,
                        errorBuilder: (context, error, child) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.qr_code_scanner,
                                    size: 56,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Camera unavailable for QR scan: ${error.errorCode.name}',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: colorScheme.primary,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Point camera at the QR code shown on Phone A',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Works completely offline. Export ZIPs later to merge both sides.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Card(
                            color: colorScheme.errorContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      state.errorMessage!,
                                      style: TextStyle(
                                        color: colorScheme.onErrorContainer,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildJoinedConfirmation(
    BuildContext context,
    JoinSampleState state,
    JoinSampleViewModel notifier,
  ) {
    final data = state.parsedData!;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.link, color: colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Text(
                        state.alreadyExistsLocally
                            ? 'Opened Existing Linked Sample'
                            : 'Linked Sample Verified',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('Sample Code: ${data.sampleCode}'),
                  Text('Project Code: ${data.projectCode}'),
                  Text(
                    'Sample UUID: ${data.sampleUuid}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Which leaf side is this phone capturing?',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          RadioGroup<LeafSide>(
            groupValue: state.selectedSide,
            onChanged: (val) {
              if (val != null) notifier.setSelectedSide(val);
            },
            child: const Column(
              children: [
                RadioListTile<LeafSide>(
                  title: Text('Upper surface (adaxial)'),
                  subtitle: Text('Top side of the tea leaf'),
                  value: LeafSide.upper,
                ),
                RadioListTile<LeafSide>(
                  title: Text('Lower surface (abaxial)'),
                  subtitle: Text('Underside of the tea leaf'),
                  value: LeafSide.lower,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _captureAssignedSide,
            icon: const Icon(Icons.camera_alt),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Capture ${state.selectedSide.databaseKey} surface'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: notifier.resetScan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan a Different QR'),
          ),
        ],
      ),
    );
  }
}
