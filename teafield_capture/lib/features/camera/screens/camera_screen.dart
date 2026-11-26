import 'package:flutter/material.dart';

class CameraScreen extends StatelessWidget {
  final String sampleUuid;
  final String leafSide;

  const CameraScreen({
    super.key,
    required this.sampleUuid,
    required this.leafSide,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: Center(child: Text('Camera — $leafSide for $sampleUuid')),
    );
  }
}
