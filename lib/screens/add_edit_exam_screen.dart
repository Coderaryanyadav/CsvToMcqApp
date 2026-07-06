import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../services/storage_service.dart';
import '../services/excel_service.dart';

class AddEditExamScreen extends StatefulWidget {
  final String? examId;
  final bool importOnly;
  final Exam? importedExam;
  const AddEditExamScreen({
    super.key,
    this.examId,
    this.importOnly = false,
    this.importedExam,
  });

  @override
  State<AddEditExamScreen> createState() => _AddEditExamScreenState();
}

class _AddEditExamScreenState extends State<AddEditExamScreen>
    with SingleTickerProviderStateMixin {
  static const Uuid _uuid = Uuid();
  late Exam exam;
  bool loaded = false;
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _load();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.importedExam != null) {
      // Loading from imported exam
      exam = widget.importedExam!;
      if (!mounted) return;
      setState(() {
        loaded = true;
      });
      return;
    }

    if (widget.importOnly) {
      try {
        final imported = await ExcelService.importFromExcel();
        if (imported == null) {
          if (!mounted) return;
          Navigator.pop(context);
          return;
        }
        exam = Exam(
          id: imported.id,
          name: 'Imported Exam',
          questions: imported.questions,
        );
        _save();
        if (!mounted) return;
        setState(() {
          loaded = true;
        });
      } catch (e) {
        // show error dialog with details
        await showDialog(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Import error'),
              content: SingleChildScrollView(child: Text(e.toString())),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
        if (!mounted) return;
        Navigator.pop(context);
      }
      return;
    }
    if (widget.examId != null) {
      try {
        final j = await StorageService.readExamFile('${widget.examId}.json');
        exam = Exam.fromJson(j);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading exam: $e')));
        Navigator.pop(context);
        return;
      }
    } else {
      final id = _uuid.v4();
      exam = Exam(id: id, name: 'New Exam', questions: []);
    }
    if (!mounted) return;
    setState(() {
      loaded = true;
    });
  }

  Future<void> _save() async {
    try {
      await StorageService.saveExamFile('${exam.id}.json', exam.toJson());
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  void addQuestion() {
    if (exam.questions.length >= 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 100 questions allowed')),
      );
      return;
    }
    final id = _uuid.v4();
    final q = Question(
      id: id,
      question: 'New question',
      options: ['Option 1', 'Option 2', 'Option 3', 'Option 4'],
      correct: 0,
    );
    exam.questions.add(q);
    _save();
    _anim.forward(from: 0);
  }

  void editQuestion(Question q) {
    showDialog(
      context: context,
      builder: (ctx) {
        final qCtrl = TextEditingController(text: q.question);
        final oCtrls = List.generate(
          4,
          (i) => TextEditingController(text: q.options[i]),
        );
        int corr = q.correct;
        return StatefulBuilder(
          builder: (ctx2, setSt) {
            bool valid() {
              if (qCtrl.text.trim().isEmpty) return false;
              for (var c in oCtrls) {
                if (c.text.trim().isEmpty) return false;
              }
              return true;
            }

            return AlertDialog(
              title: const Text('Edit Question'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: qCtrl,
                      decoration: const InputDecoration(labelText: 'Question'),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(
                      4,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: TextField(
                          controller: oCtrls[i],
                          decoration: InputDecoration(
                            labelText: 'Option ${i + 1}',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<int>(
                      value: corr,
                      items: List.generate(
                        4,
                        (i) => DropdownMenuItem(
                          value: i,
                          child: Text('Correct = Option ${i + 1}'),
                        ),
                      ),
                      onChanged: (v) {
                        if (v != null) {
                          corr = v;
                          setSt(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: valid()
                      ? () {
                          q.question = qCtrl.text.trim();
                          for (var i = 0; i < 4; i++) {
                            q.options[i] = oCtrls[i].text.trim();
                          }
                          q.correct = corr;
                          _save();
                          Navigator.pop(ctx);
                        }
                      : null,
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void deleteQuestion(Question q) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              exam.questions.removeWhere((x) => x.id == q.id);
              _save();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> exportExam() async {
    final p = await ExcelService.exportToExcelFile(exam);
    if (p != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exported to $p')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(exam.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Rename exam',
            onPressed: () async {
              final ctrl = TextEditingController(text: exam.name);
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Rename Exam'),
                  content: TextField(
                    controller: ctrl,
                    decoration: const InputDecoration(labelText: 'Exam name'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                setState(() {
                  exam.name = ctrl.text.trim().isEmpty
                      ? exam.name
                      : ctrl.text.trim();
                });
                await _save();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child: ListView.builder(
                  itemCount: exam.questions.length,
                  itemBuilder: (context, i) {
                    final q = exam.questions[i];
                    return Card(
                      child: ListTile(
                        title: Text(q.question),
                        subtitle: Text('Options: ${q.options.join(' | ')}'),
                        onTap: () => editQuestion(q),
                      ),
                    );
                  },
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: addQuestion,
                    child: const Text('Add Question'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _save();
                      Navigator.pop(context);
                    },
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
