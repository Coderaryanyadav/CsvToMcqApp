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
  String selectedDifficulty = 'Any';
  String selectedTopic = 'All Topics';
  List<String> availableTopics = ['All Topics'];

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
    _initExamData();
  }

  void _initExamData() {
    examName = selectedExam.name;
    takeCount = selectedExam.questions.length;
    
    final topics = selectedExam.questions
        .map((q) => q.topic)
        .where((t) => t != null && t.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    topics.sort();
    availableTopics = ['All Topics', ...topics];
    selectedTopic = 'All Topics';
  }

  void _startExam() {
    final questions = List<Question>.from(selectedExam.questions);
    
    // Filter by Topic
    if (selectedTopic != 'All Topics') {
      questions.retainWhere((q) => q.topic == selectedTopic);
    }
    
    // Filter by Difficulty
    if (selectedDifficulty != 'Any') {
      if (selectedDifficulty == 'Easy') {
        questions.retainWhere((q) => q.difficulty <= 2);
      } else if (selectedDifficulty == 'Medium') {
        questions.retainWhere((q) => q.difficulty == 3 || q.difficulty == 4);
      } else if (selectedDifficulty == 'Hard') {
        questions.retainWhere((q) => q.difficulty == 5);
      }
    }

    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No questions match the selected filters.')),
      );
      return;
    }

    if (shuffle) questions.shuffle();

    final take = max(1, takeCount > 0 ? min(takeCount, questions.length) : questions.length);
    final selected = questions.take(take).toList();

    if (!mounted) return;

    Navigator.pushReplacement(
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
          subtitle: Text('${widget.exams[i].questions.length} Questions'),
          onTap: () {
            setState(() {
              selectedExam = widget.exams[i];
              _initExamData();
            });
            Navigator.pop(ctx);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Exam Setup'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Choose Exam',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _showExamPicker,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(selectedExam.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text('${selectedExam.questions.length} questions available', style: const TextStyle(color: Colors.grey)),
                            ],
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    'Exam Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildSettingRow(
                            'Duration (minutes)',
                            DropdownButton<int>(
                              value: durationMin,
                              underline: const SizedBox(),
                              items: [5, 10, 15, 30, 45, 60, 90, 120]
                                  .map((e) => DropdownMenuItem(value: e, child: Text('$e min')))
                                  .toList(),
                              onChanged: (v) => setState(() => durationMin = v!),
                            ),
                          ),
                          const Divider(),
                          _buildSettingRow(
                            'Questions',
                            DropdownButton<int>(
                              value: takeCount > selectedExam.questions.length ? selectedExam.questions.length : takeCount,
                              underline: const SizedBox(),
                              items: [5, 10, 20, 50, 100, selectedExam.questions.length]
                                  .where((e) => e <= selectedExam.questions.length)
                                  .toSet()
                                  .toList()
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e == selectedExam.questions.length ? 'All $e' : '$e')))
                                  .toList(),
                              onChanged: (v) => setState(() => takeCount = v!),
                            ),
                          ),
                          const Divider(),
                          _buildSettingRow(
                            'Question Order',
                            DropdownButton<bool>(
                              value: shuffle,
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: false, child: Text('Original')),
                                DropdownMenuItem(value: true, child: Text('Shuffle')),
                              ],
                              onChanged: (v) => setState(() => shuffle = v!),
                            ),
                          ),
                          const Divider(),
                          _buildSettingRow(
                            'Difficulty',
                            DropdownButton<String>(
                              value: selectedDifficulty,
                              underline: const SizedBox(),
                              items: ['Any', 'Easy', 'Medium', 'Hard']
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (v) => setState(() => selectedDifficulty = v!),
                            ),
                          ),
                          if (availableTopics.length > 1) ...[
                            const Divider(),
                            _buildSettingRow(
                              'Topics',
                              DropdownButton<String>(
                                value: selectedTopic,
                                underline: const SizedBox(),
                                items: availableTopics
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (v) => setState(() => selectedTopic = v!),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _startExam,
                    child: const Text('Start Exam', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          child,
        ],
      ),
    );
  }
}
