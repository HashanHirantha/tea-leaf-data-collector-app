import 'package:flutter/material.dart';

class ShowSampleQrScreen extends StatelessWidget {
  final String sampleUuid;

  const ShowSampleQrScreen({
    super.key,
    required this.sampleUuid,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sample QR Code')),
      body: Center(child: Text('QR for $sampleUuid')),
    );
  }
}
