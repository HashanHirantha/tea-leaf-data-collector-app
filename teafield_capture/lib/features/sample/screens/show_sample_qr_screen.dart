import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/qr_pairing_service.dart';
import '../../../data/models/leaf_sample.dart';
import '../../../data/repositories/sample_repository.dart';

class ShowSampleQrScreen extends StatefulWidget {
  final String sampleUuid;

  const ShowSampleQrScreen({super.key, required this.sampleUuid});

  @override
  State<ShowSampleQrScreen> createState() => _ShowSampleQrScreenState();
}

class _ShowSampleQrScreenState extends State<ShowSampleQrScreen> {
  final GlobalKey _qrBoundaryKey = GlobalKey();
  LeafSample? _sample;
  String? _qrPayload;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSample();
  }

  Future<void> _loadSample() async {
    final sample = await SampleRepository().getSampleByUuid(widget.sampleUuid);
    if (!mounted) return;

    if (sample == null) {
      setState(() => _isLoading = false);
      return;
    }

    final payload = QrPairingService.instance.generateQrPayload(
      projectCode: sample.projectCode,
      sampleUuid: sample.sampleUuid,
      sampleCode: sample.sampleCode,
    );

    setState(() {
      _sample = sample;
      _qrPayload = payload;
      _isLoading = false;
    });
  }

  Future<void> _shareQrImage() async {
    final sample = _sample;
    if (sample == null) return;
    try {
      final boundary = _qrBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final tempDir = await getTemporaryDirectory();
      final outPath = p.join(tempDir.path, '${sample.sampleCode}_qr.png');
      final file = File(outPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(outPath)],
        text: 'TeaField sample QR: ${sample.sampleCode}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share QR image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Share Sample QR')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sample == null || _qrPayload == null
              ? const Center(child: Text('Sample not found.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Show this QR code to the second phone',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'On the second phone, open Join Existing Sample and scan this code to attach the opposite surface to the same physical leaf offline.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      RepaintBoundary(
                        key: _qrBoundaryKey,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              QrImageView(
                                data: _qrPayload!,
                                version: QrVersions.auto,
                                size: 240,
                                backgroundColor: Colors.white,
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _sample!.sampleCode,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Project: ${_sample!.projectCode}',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        color: colorScheme.surfaceContainerHighest,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.privacy_tip_outlined, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Privacy: This QR contains only the project code, sample UUID, and sample code. Exact GPS and personal data are excluded.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _shareQrImage,
                        icon: const Icon(Icons.share),
                        label: const Text('Share QR Image'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
