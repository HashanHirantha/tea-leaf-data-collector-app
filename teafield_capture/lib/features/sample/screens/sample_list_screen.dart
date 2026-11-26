import 'package:flutter/material.dart';

class SampleListScreen extends StatelessWidget {
  const SampleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Samples')),
      body: const Center(child: Text('Sample List')),
    );
  }
}
