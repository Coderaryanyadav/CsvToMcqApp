import 'package:flutter/material.dart';
import '../models/exam.dart';
import '../services/import_service.dart';

class ImportPreviewScreen extends StatefulWidget {
  final ImportResult importResult;

  const ImportPreviewScreen({super.key, required this.importResult});

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  @override
  Widget build(BuildContext context) {
    final res = widget.importResult;
    final hasCritical = res.criticalErrors.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Preview'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'File: ${res.filename}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatCol('Valid', res.validQuestions.length.toString(), Colors.green),
                    _StatCol('Warnings', res.warnings.length.toString(), Colors.orange),
                    _StatCol('Critical', res.criticalErrors.length.toString(), Colors.red),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (hasCritical)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Text('Cannot import because there are critical errors.', style: TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  if (res.criticalErrors.isNotEmpty) ...[
                    const Text('Critical Errors', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ...res.criticalErrors.map((e) => ListTile(title: Text(e, style: const TextStyle(fontSize: 14)))),
                    const Divider(),
                  ],
                  if (res.warnings.isNotEmpty) ...[
                    const Text('Warnings', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ...res.warnings.map((e) => ListTile(title: Text(e, style: const TextStyle(fontSize: 14)))),
                    const Divider(),
                  ],
                  if (res.suggestions.isNotEmpty) ...[
                    const Text('Suggestions', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ...res.suggestions.map((e) => ListTile(title: Text(e, style: const TextStyle(fontSize: 14)))),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: hasCritical
                  ? null
                  : () {
                      Navigator.pop(context, Exam(
                        id: '', // Will be generated or preserved
                        name: res.filename.replaceAll('.csv', '').replaceAll('.xlsx', ''),
                        questions: res.validQuestions,
                      ));
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              child: Text(hasCritical ? 'Fix Errors to Import' : 'Import ${res.validQuestions.length} Questions'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCol(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
