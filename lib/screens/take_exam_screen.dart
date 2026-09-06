import 'dart:math';
import 'package:flutter/material.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import 'exam_screen.dart';
import 'practice_mode_screen.dart';

class TakeExamScreen extends StatefulWidget {
  final List<Exam> exams;
  final String? initialExamId;
  final bool defaultToPractice;

  const TakeExamScreen({
    super.key,
    required this.exams,
    this.initialExamId,
    this.defaultToPractice = false,
  });

  @override
  State<TakeExamScreen> createState() => _TakeExamScreenState();
}

class _TakeExamScreenState extends State<TakeExamScreen> {
  late Exam selectedExam;
  bool isPracticeMode = true;
  int selectedQuestionCount = 20;
  bool isCustomCount = false;
  int selectedDurationMin = 30;
  bool isCustomDuration = false;
  bool shuffle = false;
  String selectedDifficulty = 'Any';
  String selectedTopic = 'All Topics';
  List<String> availableTopics = ['All Topics'];
  final TextEditingController _customCountCtrl = TextEditingController();
  final TextEditingController _customDurationCtrl = TextEditingController();

  final List<int> _presetCounts = [10, 20, 30, 50];
  final List<int> _presetDurations = [15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    isPracticeMode = widget.defaultToPractice;
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

  @override
  void dispose() {
    _customCountCtrl.dispose();
    _customDurationCtrl.dispose();
    super.dispose();
  }

  void _initExamData() {
    final totalQ = selectedExam.questions.length;
    if (totalQ < 20) {
      selectedQuestionCount = totalQ > 0 ? totalQ : 10;
    } else {
      selectedQuestionCount = 20;
    }
    _customCountCtrl.text = '$selectedQuestionCount';
    _customDurationCtrl.text = '$selectedDurationMin';

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

  List<Question> _getFilteredQuestions() {
    final questions = List<Question>.from(selectedExam.questions);

    if (selectedTopic != 'All Topics') {
      questions.retainWhere((q) => q.topic == selectedTopic);
    }

    if (selectedDifficulty != 'Any') {
      if (selectedDifficulty == 'Easy') {
        questions.retainWhere((q) => q.difficulty <= 2);
      } else if (selectedDifficulty == 'Medium') {
        questions.retainWhere((q) => q.difficulty == 3 || q.difficulty == 4);
      } else if (selectedDifficulty == 'Hard') {
        questions.retainWhere((q) => q.difficulty == 5);
      }
    }

    if (shuffle) questions.shuffle();

    final maxAvail = questions.length;
    final count = min(selectedQuestionCount, maxAvail);
    return questions.take(max(1, count)).toList();
  }

  void _startSession() {
    final filtered = _getFilteredQuestions();
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No questions match the selected filters.'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    if (isPracticeMode) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PracticeModeScreen(
            questions: filtered,
            durationMin: selectedDurationMin,
            examName: selectedExam.name,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExamScreen(
            questions: filtered,
            durationMin: selectedDurationMin,
            examId: selectedExam.id,
            examName: selectedExam.name,
          ),
        ),
      );
    }
  }

  void _showExamPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                'Select Exam',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.exams.length,
                itemBuilder: (_, i) {
                  final e = widget.exams[i];
                  final isSel = e.id == selectedExam.id;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.primaryNavy : const Color(0xFFE5E8ED),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.school,
                        color: isSel ? Colors.white : AppTheme.secondaryText,
                        size: 20,
                      ),
                    ),
                    title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.text)),
                    subtitle: Text('${e.questions.length} Questions', style: const TextStyle(color: AppTheme.secondaryText, fontSize: 13)),
                    trailing: isSel ? const Icon(Icons.check_circle, color: AppTheme.accentBlue) : null,
                    onTap: () {
                      setState(() {
                        selectedExam = e;
                        _initExamData();
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _promptCustomCount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Question Count'),
        content: TextField(
          controller: _customCountCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Number of Questions (max ${selectedExam.questions.length})',
            hintText: 'Enter question count',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(_customCountCtrl.text);
              if (val != null && val > 0) {
                setState(() {
                  selectedQuestionCount = min(val, selectedExam.questions.length);
                  isCustomCount = true;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _promptCustomDuration() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom Duration'),
        content: TextField(
          controller: _customDurationCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Duration in Minutes',
            hintText: 'e.g. 40',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(_customDurationCtrl.text);
              if (val != null && val > 0) {
                setState(() {
                  selectedDurationMin = val;
                  isCustomDuration = true;
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalQ = selectedExam.questions.length;
    final modeTitle = isPracticeMode ? 'Practice' : 'Exam';
    final actualCount = min(selectedQuestionCount, max(1, totalQ));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Start New Session'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Exam Selection
                const Text(
                  'Exam',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondaryText,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: widget.exams.length > 1 ? _showExamPicker : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBF2FA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.school, color: AppTheme.primaryNavy, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedExam.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.text,
                                ),
                              ),
                              Text(
                                '$totalQ Questions Available',
                                style: const TextStyle(
                                  color: AppTheme.secondaryText,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.exams.length > 1)
                          const Icon(Icons.arrow_drop_down, color: AppTheme.secondaryText, size: 24),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // 2. Session Mode
                const Text(
                  'Session Mode',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondaryText,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Practice Mode Card
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => isPracticeMode = true),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isPracticeMode ? AppTheme.accentBlue : AppTheme.border,
                              width: isPracticeMode ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.school_outlined,
                                    color: isPracticeMode ? AppTheme.accentBlue : AppTheme.secondaryText,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Practice Mode',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: isPracticeMode ? AppTheme.primaryNavy : AppTheme.text,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Reveal answers and explanations while answering.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.secondaryText,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Exam Mode Card
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => isPracticeMode = false),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: !isPracticeMode ? AppTheme.accentBlue : AppTheme.border,
                              width: !isPracticeMode ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.assignment_outlined,
                                    color: !isPracticeMode ? AppTheme.accentBlue : AppTheme.secondaryText,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Exam Mode',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: !isPracticeMode ? AppTheme.primaryNavy : AppTheme.text,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Simulate the real exam. Answers remain locked until submission.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.secondaryText,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // 3. Number of Questions
                const Text(
                  'Number of Questions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondaryText,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ..._presetCounts.map((cnt) {
                      final isSelected = !isCustomCount && selectedQuestionCount == cnt;
                      final isOverMax = cnt > totalQ && totalQ > 0;
                      return ChoiceChip(
                        label: Text('$cnt'),
                        selected: isSelected,
                        onSelected: (sel) {
                          if (sel) {
                            setState(() {
                              isCustomCount = false;
                              selectedQuestionCount = isOverMax ? totalQ : cnt;
                            });
                          }
                        },
                        selectedColor: AppTheme.primaryNavy,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.text,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryNavy : AppTheme.border,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      );
                    }),
                    ChoiceChip(
                      label: Text(isCustomCount ? 'Custom ($selectedQuestionCount)' : 'Custom'),
                      selected: isCustomCount,
                      onSelected: (sel) {
                        _promptCustomCount();
                      },
                      selectedColor: AppTheme.primaryNavy,
                      labelStyle: TextStyle(
                        color: isCustomCount ? Colors.white : AppTheme.text,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isCustomCount ? AppTheme.primaryNavy : AppTheme.border,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // 4. Duration
                const Text(
                  'Duration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.secondaryText,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ..._presetDurations.map((dur) {
                      final isSelected = !isCustomDuration && selectedDurationMin == dur;
                      return ChoiceChip(
                        label: Text('$dur min'),
                        selected: isSelected,
                        onSelected: (sel) {
                          if (sel) {
                            setState(() {
                              isCustomDuration = false;
                              selectedDurationMin = dur;
                            });
                          }
                        },
                        selectedColor: AppTheme.primaryNavy,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.text,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: isSelected ? AppTheme.primaryNavy : AppTheme.border,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      );
                    }),
                    ChoiceChip(
                      label: Text(isCustomDuration ? 'Custom ($selectedDurationMin min)' : 'Custom'),
                      selected: isCustomDuration,
                      onSelected: (sel) {
                        _promptCustomDuration();
                      },
                      selectedColor: AppTheme.primaryNavy,
                      labelStyle: TextStyle(
                        color: isCustomDuration ? Colors.white : AppTheme.text,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: isCustomDuration ? AppTheme.primaryNavy : AppTheme.border,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // 5. Advanced Filters & Options Card
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Optional Filters & Options',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.secondaryText,
                    ),
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Difficulty', style: TextStyle(fontWeight: FontWeight.w500)),
                              DropdownButton<String>(
                                value: selectedDifficulty,
                                underline: const SizedBox(),
                                items: ['Any', 'Easy', 'Medium', 'Hard']
                                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => selectedDifficulty = v);
                                },
                              ),
                            ],
                          ),
                          if (availableTopics.length > 1) ...[
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Topic', style: TextStyle(fontWeight: FontWeight.w500)),
                                DropdownButton<String>(
                                  value: selectedTopic,
                                  underline: const SizedBox(),
                                  items: availableTopics
                                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null) setState(() => selectedTopic = v);
                                  },
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 16),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Shuffle Questions', style: TextStyle(fontWeight: FontWeight.w500)),
                            value: shuffle,
                            onChanged: (v) => setState(() => shuffle = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 6. Session Summary Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF2FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDBEAFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.accentBlue, size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${selectedExam.name}  ·  $modeTitle  ·  $actualCount Questions  ·  $selectedDurationMin Minutes',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryNavy,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 7. Primary CTA
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: isPracticeMode ? AppTheme.accentBlue : AppTheme.primaryNavy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: totalQ > 0 ? _startSession : null,
                    child: Text(
                      isPracticeMode ? 'Start Practice' : 'Start Exam',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
