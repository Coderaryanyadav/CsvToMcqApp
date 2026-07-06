import 'dart:math';
import 'package:flutter/material.dart';
import '../models/exam.dart';
import '../models/question.dart';
import 'exam_screen.dart';

class TakeSelectionScreen extends StatefulWidget {
  final Exam exam;
  const TakeSelectionScreen({super.key, required this.exam});
  @override
  State<TakeSelectionScreen> createState() => _TakeSelectionScreenState();
}

class _TakeSelectionScreenState extends State<TakeSelectionScreen> {
  int durationMin = 10;
  double percent = 100;
  bool shuffle = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Take "${widget.exam.name}"')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ListTile(
                title: const Text('Duration (minutes)'),
                trailing: DropdownButton<int>(
                    value: durationMin,
                    items: [5, 10, 15, 20, 30, 60]
                        .map((e) =>
                            DropdownMenuItem(value: e, child: Text('$e')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => durationMin = v);
                    })),
            ListTile(
                title: const Text('Pick % of questions'),
                trailing: DropdownButton<double>(
                    value: percent,
                    items: [100, 50, 25]
                        .map((e) => DropdownMenuItem(
                            value: e.toDouble(), child: Text('$e%')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => percent = v);
                    })),
            SwitchListTile(
                value: shuffle,
                onChanged: (v) => setState(() => shuffle = v),
                title: const Text('Shuffle questions')),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: () {
                  final total = widget.exam.questions.length;
                  final take = max(1, (total * percent / 100).round());
                  final questions = List<Question>.from(widget.exam.questions);
                  if (shuffle) questions.shuffle();
                  final selected = questions.take(take).toList();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ExamScreen(
                              questions: selected,
                              durationMin: durationMin,
                              examId: widget.exam.id,
                              examName: widget.exam.name)));
                },
                child: const Text('Start Exam')),
          ],
        ),
      ),
    );
  }
}
