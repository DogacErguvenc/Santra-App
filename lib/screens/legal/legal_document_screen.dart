import 'package:flutter/material.dart';

class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String documentContent;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.documentContent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          documentContent,
          style: TextStyle(
            color: Colors.grey[300],
            height:
                1.5, // Satır aralığını artırarak okunabilirliği kolaylaştırır
          ),
        ),
      ),
    );
  }
}
