import 'package:flutter/material.dart';

class NewSampleScreen extends StatelessWidget {
  const NewSampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Sample')),
      body: const Center(child: Text('New Sample')),
    );
  }
}
