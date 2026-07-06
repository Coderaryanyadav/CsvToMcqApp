import 'dart:math';
import 'package:flutter/material.dart';
import '../models/exam.dart';
import '../models/question.dart';
import 'exam_screen.dart';

class TakeExamScreen extends StatefulWidget {
  final List<Exam> exams;
  final String? initialExamId;
  const TakeExamScreen({super.key, required this.exams, this.initialExamId});

  @override
  State<TakeExamScreen> createState() => _TakeExamScreenState();
}

class _TakeExamScreenState extends State<TakeExamScreen> {
  late Exam selectedExam;

  String examName = '';
  int durationMin = 10;
  int takeCount = 0;
  bool shuffle = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialExamId != null) {
      selectedExam = widget.exams.firstWhere(
        (e) => e.id == widget.initialExamId,
        orElse: () => widget.exams.first,
      );
    } else {
      selectedExam = widget.exams.first;
    }
    examName = selectedExam.name;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _startExam() {
    final total = selectedExam.questions.length;
    final take = max(1, takeCount > 0 ? min(takeCount, total) : total);

    final questions = List<Question>.from(selectedExam.questions);
    if (shuffle) questions.shuffle();

    final selected = questions.take(take).toList();

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamScreen(
          questions: selected,
          durationMin: durationMin,
          examId: selectedExam.id,
          examName: examName,
        ),
      ),
    );
  }

  void _showExamPicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: widget.exams.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(widget.exams[i].name),
          subtitle: Text('${widget.exams[i].questions.length} Q'),
          onTap: () {
            setState(() {
              selectedExam = widget.exams[i];
              examName = selectedExam.name;
            });
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  // removed pickers (replaced by text inputs)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Take Exam'),
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              /// STEP 1: SELECT EXAM
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Step 1: Select Exam',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _showExamPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${selectedExam.name} (${selectedExam.questions.length} Q)',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Text(
                                '▼',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Removed exam name step: use selected exam's name
              const SizedBox(height: 16),

              /// STEP 3: OPTIONS
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Step 3: Exam Options',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text('Duration (minutes)'),
                      const SizedBox(height: 8),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'e.g. 30',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v) ?? durationMin;
                          setState(() => durationMin = n.clamp(1, 300));
                        },
                      ),

                      const Divider(),

                      const SizedBox(height: 16),
                      const Text('Questions to take'),
                      const SizedBox(height: 8),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'e.g. ${selectedExam.questions.length}',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (v) {
                          final n = int.tryParse(v) ?? selectedExam.questions.length;
                          setState(() => takeCount = n);
                        },
                      ),

                      const Divider(),

                      // Shuffle
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Shuffle Questions'),
                        trailing: Switch(
                          value: shuffle,
                          onChanged: (v) => setState(() => shuffle = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              /// START BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _startExam,
                  child: const Text(
                    'Start Exam',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
