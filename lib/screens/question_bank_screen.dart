import 'package:flutter/material.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../services/storage_service.dart';
import '../services/import_service.dart';
import 'import_preview_screen.dart';

class QuestionBankScreen extends StatefulWidget {
  final List<Exam> exams;
  final String? initialExamId;

  const QuestionBankScreen({
    super.key,
    required this.exams,
    this.initialExamId,
  });

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  late List<Exam> _exams;
  late Exam _selectedExam;
  final TextEditingController _searchCtrl = TextEditingController();

  String _selectedTopic = 'All Topics';
  String _selectedDifficulty = 'All';
  String _selectedType = 'All';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _exams = List.from(widget.exams);
    if (_exams.isEmpty) {
      final defaultExam = Exam(id: 'exam_1', name: 'Sample Exam', questions: []);
      _exams.add(defaultExam);
    }
    if (widget.initialExamId != null) {
      _selectedExam = _exams.firstWhere(
        (e) => e.id == widget.initialExamId,
        orElse: () => _exams.first,
      );
    } else {
      _selectedExam = _exams.first;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentExam() async {
    await StorageService.saveExam(_selectedExam);
    setState(() {});
  }

  List<String> get _topics {
    final t = _selectedExam.questions
        .map((q) => q.topic)
        .where((x) => x != null && x.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    t.sort();
    return ['All Topics', ...t];
  }

  List<Question> get _filteredQuestions {
    var list = List<Question>.from(_selectedExam.questions);

    // Search query
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((q) {
        final inQ = q.question.toLowerCase().contains(query);
        final inId = q.id.toLowerCase().contains(query);
        final inOpts = q.options.any((o) => o.toLowerCase().contains(query));
        final inTopic = q.topic?.toLowerCase().contains(query) ?? false;
        final inTags = q.tags.any((t) => t.toLowerCase().contains(query));
        return inQ || inId || inOpts || inTopic || inTags;
      }).toList();
    }

    // Topic
    if (_selectedTopic != 'All Topics') {
      list = list.where((q) => q.topic == _selectedTopic).toList();
    }

    // Difficulty
    if (_selectedDifficulty != 'All') {
      final d = int.tryParse(_selectedDifficulty);
      if (d != null) {
        list = list.where((q) => q.difficulty == d).toList();
      }
    }

    // Question Type
    if (_selectedType != 'All') {
      if (_selectedType == 'Single') {
        list = list.where((q) => !q.isMultiple).toList();
      } else if (_selectedType == 'Multiple') {
        list = list.where((q) => q.isMultiple).toList();
      }
    }

    // Sort by ID number
    list.sort((a, b) {
      final aNum = int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final bNum = int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return _sortAscending ? aNum.compareTo(bNum) : bNum.compareTo(aNum);
    });

    return list;
  }

  Future<void> _importQuestionsToCurrentExam() async {
    try {
      final importResult = await ImportService.pickAndPreviewFile(
        targetExam: _selectedExam,
      );
      if (importResult == null) return;
      if (!mounted) return;

      final validQuestions = await Navigator.push<List<Question>>(
        context,
        MaterialPageRoute(
          builder: (_) => ImportPreviewScreen(importResult: importResult),
        ),
      );

      if (validQuestions != null && validQuestions.isNotEmpty) {
        _selectedExam.questions.addAll(validQuestions);
        _selectedExam.reindexQuestions();
        await _saveCurrentExam();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${validQuestions.length} questions into ${_selectedExam.name}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to import: $e')),
      );
    }
  }

  void _showAddEditQuestionDialog([Question? questionToEdit]) {
    final isEdit = questionToEdit != null;
    final qCtrl = TextEditingController(text: questionToEdit?.question ?? '');
    final optACtrl = TextEditingController(
        text: (questionToEdit != null && questionToEdit.options.isNotEmpty)
            ? questionToEdit.options[0]
            : '');
    final optBCtrl = TextEditingController(
        text: (questionToEdit != null && questionToEdit.options.length > 1)
            ? questionToEdit.options[1]
            : '');
    final optCCtrl = TextEditingController(
        text: (questionToEdit != null && questionToEdit.options.length > 2)
            ? questionToEdit.options[2]
            : '');
    final optDCtrl = TextEditingController(
        text: (questionToEdit != null && questionToEdit.options.length > 3)
            ? questionToEdit.options[3]
            : '');

    final expACtrl = TextEditingController(
        text: questionToEdit?.optionExplanations[0] ?? '');
    final expBCtrl = TextEditingController(
        text: questionToEdit?.optionExplanations[1] ?? '');
    final expCCtrl = TextEditingController(
        text: questionToEdit?.optionExplanations[2] ?? '');
    final expDCtrl = TextEditingController(
        text: questionToEdit?.optionExplanations[3] ?? '');

    final topicCtrl = TextEditingController(text: questionToEdit?.topic ?? '');
    final tagsCtrl =
        TextEditingController(text: questionToEdit?.tags.join(', ') ?? '');
    int difficulty = questionToEdit?.difficulty ?? 3;
    String questionType = questionToEdit?.questionType ?? 'single';
    Set<int> correctAnswers =
        questionToEdit != null ? Set.from(questionToEdit.correctAnswers) : {0};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Text(isEdit
                  ? 'Edit Question (${questionToEdit.id})'
                  : 'Add New Question (Q${_selectedExam.nextQuestionNumber})'),
              content: SizedBox(
                width: 650,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question Type Selector
                      Row(
                        children: [
                          const Text('Type: ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          ChoiceChip(
                            label: const Text('Single Select'),
                            selected: questionType == 'single',
                            onSelected: (v) {
                              if (v) {
                                setDlgState(() {
                                  questionType = 'single';
                                  if (correctAnswers.length > 1) {
                                    correctAnswers = {correctAnswers.first};
                                  }
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Multiple Select'),
                            selected: questionType == 'multiple',
                            onSelected: (v) {
                              if (v) {
                                setDlgState(() {
                                  questionType = 'multiple';
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: qCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Question Text *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Options & Explanations (select correct answer):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),

                      // Option A
                      _buildOptionInput(
                        label: 'Option A',
                        index: 0,
                        optCtrl: optACtrl,
                        expCtrl: expACtrl,
                        isMultiple: questionType == 'multiple',
                        isSelected: correctAnswers.contains(0),
                        onChanged: (sel) {
                          setDlgState(() {
                            if (questionType == 'single') {
                              correctAnswers = {0};
                            } else {
                              if (sel) {
                                correctAnswers.add(0);
                              } else {
                                correctAnswers.remove(0);
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // Option B
                      _buildOptionInput(
                        label: 'Option B',
                        index: 1,
                        optCtrl: optBCtrl,
                        expCtrl: expBCtrl,
                        isMultiple: questionType == 'multiple',
                        isSelected: correctAnswers.contains(1),
                        onChanged: (sel) {
                          setDlgState(() {
                            if (questionType == 'single') {
                              correctAnswers = {1};
                            } else {
                              if (sel) {
                                correctAnswers.add(1);
                              } else {
                                correctAnswers.remove(1);
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // Option C
                      _buildOptionInput(
                        label: 'Option C',
                        index: 2,
                        optCtrl: optCCtrl,
                        expCtrl: expCCtrl,
                        isMultiple: questionType == 'multiple',
                        isSelected: correctAnswers.contains(2),
                        onChanged: (sel) {
                          setDlgState(() {
                            if (questionType == 'single') {
                              correctAnswers = {2};
                            } else {
                              if (sel) {
                                correctAnswers.add(2);
                              } else {
                                correctAnswers.remove(2);
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 8),

                      // Option D
                      _buildOptionInput(
                        label: 'Option D',
                        index: 3,
                        optCtrl: optDCtrl,
                        expCtrl: expDCtrl,
                        isMultiple: questionType == 'multiple',
                        isSelected: correctAnswers.contains(3),
                        onChanged: (sel) {
                          setDlgState(() {
                            if (questionType == 'single') {
                              correctAnswers = {3};
                            } else {
                              if (sel) {
                                correctAnswers.add(3);
                              } else {
                                correctAnswers.remove(3);
                              }
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: topicCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Topic',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: difficulty,
                              decoration: const InputDecoration(
                                labelText: 'Difficulty',
                                border: OutlineInputBorder(),
                              ),
                              items: [1, 2, 3, 4, 5]
                                  .map((d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(
                                            '$d (${d <= 2 ? "Easy" : d <= 4 ? "Medium" : "Hard"})'),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setDlgState(() => difficulty = v);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tagsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final qText = qCtrl.text.trim();
                    final oA = optACtrl.text.trim();
                    final oB = optBCtrl.text.trim();
                    final oC = optCCtrl.text.trim();
                    final oD = optDCtrl.text.trim();

                    if (qText.isEmpty ||
                        oA.isEmpty ||
                        oB.isEmpty ||
                        oC.isEmpty ||
                        oD.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Question text and all 4 options are required.')),
                      );
                      return;
                    }

                    if (correctAnswers.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Please mark at least one correct answer.')),
                      );
                      return;
                    }

                    final Map<int, String> expMap = {};
                    if (expACtrl.text.trim().isNotEmpty) {
                      expMap[0] = expACtrl.text.trim();
                    }
                    if (expBCtrl.text.trim().isNotEmpty) {
                      expMap[1] = expBCtrl.text.trim();
                    }
                    if (expCCtrl.text.trim().isNotEmpty) {
                      expMap[2] = expCCtrl.text.trim();
                    }
                    if (expDCtrl.text.trim().isNotEmpty) {
                      expMap[3] = expDCtrl.text.trim();
                    }

                    final tags = tagsCtrl.text
                        .split(',')
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();

                    if (isEdit) {
                      questionToEdit.question = qText;
                      questionToEdit.options = [oA, oB, oC, oD];
                      questionToEdit.correctAnswers = correctAnswers;
                      questionToEdit.questionType =
                          correctAnswers.length > 1 ? 'multiple' : questionType;
                      questionToEdit.optionExplanations = expMap;
                      questionToEdit.topic =
                          topicCtrl.text.trim().isEmpty ? null : topicCtrl.text.trim();
                      questionToEdit.difficulty = difficulty;
                      questionToEdit.tags = tags;
                    } else {
                      final newQ = Question(
                        id: 'Q${_selectedExam.nextQuestionNumber}',
                        question: qText,
                        options: [oA, oB, oC, oD],
                        correctAnswers: correctAnswers,
                        questionType:
                            correctAnswers.length > 1 ? 'multiple' : questionType,
                        optionExplanations: expMap,
                        topic: topicCtrl.text.trim().isEmpty
                            ? null
                            : topicCtrl.text.trim(),
                        difficulty: difficulty,
                        tags: tags,
                      );
                      _selectedExam.questions.add(newQ);
                    }

                    _selectedExam.reindexQuestions();
                    _saveCurrentExam();
                    Navigator.pop(ctx);
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Add Question'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildOptionInput({
    required String label,
    required int index,
    required TextEditingController optCtrl,
    required TextEditingController expCtrl,
    required bool isMultiple,
    required bool isSelected,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.green.shade400 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isMultiple)
                Checkbox(
                  value: isSelected,
                  onChanged: (v) => onChanged(v ?? false),
                )
              else
                IconButton(
                  icon: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.green : Colors.grey,
                  ),
                  onPressed: () => onChanged(true),
                ),
              Expanded(
                child: TextField(
                  controller: optCtrl,
                  decoration: InputDecoration(
                    labelText: '$label Text *',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: TextField(
              controller: expCtrl,
              decoration: InputDecoration(
                labelText: '$label Explanation (shown when revealed)',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuestionDetailsDialog(Question q) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  q.id,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  q.isMultiple ? 'MULTIPLE SELECT' : 'SINGLE SELECT',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                backgroundColor:
                    q.isMultiple ? Colors.purple.shade50 : Colors.blue.shade50,
                side: BorderSide.none,
              ),
            ],
          ),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    q.question,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Options & Explanations:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...List.generate(q.options.length, (i) {
                    final isCorrect = q.correctAnswers.contains(i);
                    final exp = q.getExplanation(i);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? Colors.green.shade50
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCorrect
                              ? Colors.green.shade400
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCorrect
                                    ? Icons.check_circle
                                    : Icons.cancel_outlined,
                                color: isCorrect ? Colors.green : Colors.grey,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${String.fromCharCode(65 + i)} — ',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Expanded(child: Text(q.options[i])),
                            ],
                          ),
                          if (exp != null && exp.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.only(left: 26),
                              child: Text(
                                'Explanation: $exp',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (q.topic != null)
                        Chip(
                          label: Text('Topic: ${q.topic}'),
                          avatar: const Icon(Icons.category, size: 14),
                        ),
                      Chip(
                        label: Text('Difficulty: ${q.difficulty}/5'),
                        avatar: const Icon(Icons.speed, size: 14),
                      ),
                      ...q.tags.map((t) => Chip(
                            label: Text(t),
                            avatar: const Icon(Icons.tag, size: 14),
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _deleteQuestion(Question q) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${q.id}?'),
        content: Text('Are you sure you want to delete question ${q.id}: "${q.question}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _selectedExam.questions.removeWhere((item) => item.id == q.id);
              _selectedExam.reindexQuestions();
              _saveCurrentExam();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted ${q.id} and re-indexed.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = _filteredQuestions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Bank'),
        actions: [
          IconButton(
            tooltip: 'Import Questions',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: _importQuestionsToCurrentExam,
          ),
          IconButton(
            tooltip: 'Add Question',
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditQuestionDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Exam Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.school, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                const Text(
                  'Target Exam: ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedExam.id,
                  underline: const SizedBox(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  items: _exams
                      .map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.name),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedExam = _exams.firstWhere((e) => e.id == val);
                        _selectedTopic = 'All Topics';
                      });
                    }
                  },
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedExam.questions.length} Questions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Filters & Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by question, option, topic, or tag...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Topic Filter
                      DropdownButton<String>(
                        value: _selectedTopic,
                        items: _topics
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t, style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedTopic = v);
                        },
                      ),
                      const SizedBox(width: 16),

                      // Difficulty Filter
                      DropdownButton<String>(
                        value: _selectedDifficulty,
                        items: ['All', '1', '2', '3', '4', '5']
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text(
                                    d == 'All' ? 'Difficulty: All' : 'Diff: $d',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedDifficulty = v);
                        },
                      ),
                      const SizedBox(width: 16),

                      // Type Filter
                      DropdownButton<String>(
                        value: _selectedType,
                        items: ['All', 'Single', 'Multiple']
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t == 'All' ? 'Type: All' : '$t Select',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedType = v);
                        },
                      ),
                      const SizedBox(width: 16),

                      // Sort Order
                      TextButton.icon(
                        icon: Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                        ),
                        label: Text(
                          _sortAscending ? 'ID Asc' : 'ID Desc',
                          style: const TextStyle(fontSize: 13),
                        ),
                        onPressed: () {
                          setState(() {
                            _sortAscending = !_sortAscending;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Question List
          Expanded(
            child: questions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.quiz_outlined,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          _selectedExam.questions.isEmpty
                              ? 'No questions in ${_selectedExam.name} yet.'
                              : 'No questions match the current filters.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton.icon(
                              icon: const Icon(Icons.file_upload_outlined),
                              label: const Text('Import Questions'),
                              onPressed: _importQuestionsToCurrentExam,
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Add Question'),
                              onPressed: () => _showAddEditQuestionDialog(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: questions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final q = questions[index];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                              color: theme.colorScheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Question ID Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  q.id,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Question Content & Meta
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      q.question,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: q.isMultiple
                                                ? Colors.purple.shade50
                                                : Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                              color: q.isMultiple
                                                  ? Colors.purple.shade200
                                                  : Colors.blue.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            q.isMultiple
                                                ? 'Multiple Select'
                                                : 'Single Select',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: q.isMultiple
                                                  ? Colors.purple.shade900
                                                  : Colors.blue.shade900,
                                            ),
                                          ),
                                        ),
                                        if (q.topic != null &&
                                            q.topic!.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              q.topic!,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                          ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Diff: ${q.difficulty}/5',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Action Buttons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined,
                                        size: 20),
                                    tooltip: 'View Details',
                                    onPressed: () =>
                                        _showQuestionDetailsDialog(q),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 20),
                                    tooltip: 'Edit',
                                    onPressed: () =>
                                        _showAddEditQuestionDialog(q),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 20, color: Colors.red),
                                    tooltip: 'Delete',
                                    onPressed: () => _deleteQuestion(q),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
