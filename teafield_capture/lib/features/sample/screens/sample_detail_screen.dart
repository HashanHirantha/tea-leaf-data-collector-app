import 'package:flutter/material.dart';

class SampleDetailScreen extends StatelessWidget {
  final String sampleUuid;

  const SampleDetailScreen({
    super.key,
    required this.sampleUuid,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sample Detail')),
      body: Center(child: Text('Detail for $sampleUuid')),
    );
  }
}
