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
  Exam? selectedExam;
  bool isPracticeMode = true;
  int selectedQuestionCount = 20;
  bool isAllQuestions = false;
  bool isCustomCount = false;
  int selectedDurationMin = 30; // 0 = Untimed
  bool isCustomDuration = false;
  bool shuffleQuestions = true;
  bool shuffleOptions = false;
  String selectedDifficulty = 'Any';
  String selectedTopic = 'All Topics';
  List<String> availableTopics = ['All Topics'];
  final TextEditingController _customCountCtrl = TextEditingController();
  final TextEditingController _customDurationCtrl = TextEditingController();

  final List<int> _presetCounts = [10, 20, 30, 50];
  final List<int> _presetDurations = [0, 15, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    isPracticeMode = widget.defaultToPractice;
    if (widget.exams.isNotEmpty) {
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
  }

  @override
  void dispose() {
    _customCountCtrl.dispose();
    _customDurationCtrl.dispose();
    super.dispose();
  }

  void _initExamData() {
    if (selectedExam == null) return;
    final totalQ = selectedExam!.questions.length;
    if (totalQ < 20) {
      selectedQuestionCount = totalQ > 0 ? totalQ : 10;
    } else {
      selectedQuestionCount = 20;
    }
    selectedDurationMin = selectedExam!.defaultDuration ?? 30;

    _customCountCtrl.text = '$selectedQuestionCount';
    _customDurationCtrl.text = '$selectedDurationMin';

    final topics = selectedExam!.questions
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
    if (selectedExam == null) return [];
    var questions = List<Question>.from(selectedExam!.questions);

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

    if (shuffleQuestions) {
      questions.shuffle();
    }

    if (shuffleOptions) {
      // Create copies with shuffled options
      questions = questions.map((origQ) {
        final originalCorrectOptions =
            origQ.correctAnswers.map((idx) => origQ.options[idx]).toSet();
        final optionsCopy = List<String>.from(origQ.options)..shuffle();
        final newCorrectAnswers = <int>{};
        final newExplanations = <int, String>{};

        for (int i = 0; i < optionsCopy.length; i++) {
          if (originalCorrectOptions.contains(optionsCopy[i])) {
            newCorrectAnswers.add(i);
          }
          final oldIdx = origQ.options.indexOf(optionsCopy[i]);
          if (oldIdx != -1 && origQ.optionExplanations.containsKey(oldIdx)) {
            newExplanations[i] = origQ.optionExplanations[oldIdx]!;
          }
        }

        return origQ.copyWith(
          options: optionsCopy,
          correctAnswers: newCorrectAnswers,
          optionExplanations: newExplanations,
        );
      }).toList();
    }

    if (isAllQuestions) {
      return questions;
    }

    final maxAvail = questions.length;
    final count = min(selectedQuestionCount, maxAvail);
    return questions.take(max(1, count)).toList();
  }

  void _startSession() {
    if (selectedExam == null) return;
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
            examName: selectedExam!.name,
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
            examId: selectedExam!.id,
            examName: selectedExam!.name,
            passingPercentage: selectedExam!.passingPercentage,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (widget.exams.isEmpty || selectedExam == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam Setup')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_outlined,
                    size: 64, color: AppTheme.secondaryText),
                SizedBox(height: 16),
                Text(
                  'No Exams Available',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Please create an exam track or import a question bank first.',
                  style: TextStyle(color: AppTheme.secondaryText),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final totalQuestionsInExam = selectedExam!.questions.length;

    return Scaffold(
      appBar: AppBar(
        title:
            Text(isPracticeMode ? 'Practice Setup' : 'Exam Simulation Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. SELECT EXAM TRACK
                _sectionTitle('1. Target Exam Track', Icons.school),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedExam!.id,
                        items: widget.exams.map((e) {
                          return DropdownMenuItem(
                            value: e.id,
                            child: Row(
                              children: [
                                Text(e.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(width: 12),
                                Chip(
                                  label: Text('${e.questions.length} Questions',
                                      style: const TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              selectedExam =
                                  widget.exams.firstWhere((e) => e.id == val);
                              _initExamData();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. MODE SELECTION (Exam vs Practice)
                _sectionTitle('2. Session Mode', Icons.dashboard_outlined),
                Row(
                  children: [
                    Expanded(
                      child: _buildModeCard(
                        title: 'Exam Mode',
                        desc:
                            'Timed simulation, final score, question navigator, and pass/fail evaluation.',
                        icon: Icons.timer_outlined,
                        isSelected: !isPracticeMode,
                        onTap: () => setState(() => isPracticeMode = false),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildModeCard(
                        title: 'Practice Mode',
                        desc:
                            'Untimed or self-paced study with instant feedback and answer explanations.',
                        icon: Icons.lightbulb_outline,
                        isSelected: isPracticeMode,
                        onTap: () => setState(() => isPracticeMode = true),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 3. QUESTIONS COUNT
                _sectionTitle(
                    '3. Number of Questions', Icons.format_list_numbered),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ..._presetCounts.map((count) {
                              final isSel = !isAllQuestions &&
                                  !isCustomCount &&
                                  selectedQuestionCount == count;
                              return ChoiceChip(
                                label: Text('$count Questions'),
                                selected: isSel,
                                onSelected: (v) {
                                  if (v) {
                                    setState(() {
                                      selectedQuestionCount = count;
                                      isAllQuestions = false;
                                      isCustomCount = false;
                                    });
                                  }
                                },
                              );
                            }),
                            ChoiceChip(
                              label: Text('All ($totalQuestionsInExam)'),
                              selected: isAllQuestions,
                              onSelected: (v) {
                                if (v) {
                                  setState(() {
                                    isAllQuestions = true;
                                    isCustomCount = false;
                                    selectedQuestionCount =
                                        totalQuestionsInExam;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 4. DURATION SELECTION
                _sectionTitle('4. Exam Duration', Icons.access_time),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _presetDurations.map((duration) {
                        final isSel = selectedDurationMin == duration;
                        final label = duration == 0
                            ? 'Untimed (No Limit)'
                            : '$duration Minutes';
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSel,
                          onSelected: (v) {
                            if (v) {
                              setState(() {
                                selectedDurationMin = duration;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 5. FILTERS & OPTIONS
                _sectionTitle('5. Filters & Options', Icons.tune),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Topic Dropdown
                        Row(
                          children: [
                            const Text('Topic:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedTopic,
                                underline: const SizedBox(),
                                items: availableTopics.map((t) {
                                  return DropdownMenuItem(
                                      value: t, child: Text(t));
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => selectedTopic = v);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // Difficulty
                        Row(
                          children: [
                            const Text('Difficulty:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 16),
                            Wrap(
                              spacing: 8,
                              children:
                                  ['Any', 'Easy', 'Medium', 'Hard'].map((d) {
                                final isSel = selectedDifficulty == d;
                                return ChoiceChip(
                                  label: Text(d),
                                  selected: isSel,
                                  onSelected: (v) {
                                    if (v) {
                                      setState(() => selectedDifficulty = d);
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        // Switches
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Shuffle Questions',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Randomize question sequence'),
                          value: shuffleQuestions,
                          onChanged: (v) =>
                              setState(() => shuffleQuestions = v),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Shuffle Options (A/B/C/D)',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text(
                              'Randomize option order for each question'),
                          value: shuffleOptions,
                          onChanged: (v) => setState(() => shuffleOptions = v),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // START BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isPracticeMode
                          ? AppTheme.primaryNavy
                          : AppTheme.accentBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(isPracticeMode ? Icons.school : Icons.play_arrow,
                        size: 22),
                    label: Text(
                      isPracticeMode
                          ? 'Start Practice Session'
                          : 'Start Exam Simulation',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _startSession,
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.accentBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String desc,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentBlue.withValues(alpha: 0.08)
              : (isDark ? AppTheme.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppTheme.accentBlue
                : (isDark ? AppTheme.darkBorder : AppTheme.border),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    color: isSelected ? AppTheme.accentBlue : Colors.grey,
                    size: 24),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppTheme.accentBlue : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.secondaryText, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }
}
