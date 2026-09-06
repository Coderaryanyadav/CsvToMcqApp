import 'dart:io';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../services/import_service.dart';
import '../services/analytics_service.dart';
import '../models/exam.dart';
import '../models/performance.dart';
import 'add_edit_exam_screen.dart';
import 'exam_audit_screen.dart';
import 'take_exam_screen.dart';
import 'statistics_screen.dart';
import 'practice_mode_screen.dart';
import 'import_preview_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  // ignore: use_super_parameters
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Exam> exams = [];
  List<Exam> filtered = [];
  List<ExamPerformance> recentPerformances = [];
  bool loading = true;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await StorageService.init();
    await loadExams();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> loadExams() async {
    setState(() {
      loading = true;
    });
    final files = StorageService.listExamFiles();
    final List<Exam> list = [];
    for (var f in files) {
      try {
        final name = f.path.split(Platform.pathSeparator).last;
        final j = await StorageService.readExamFile(name);
        list.add(Exam.fromJson(j));
      } catch (e) {
        // ignore malformed files
      }
    }
    final recents = StorageService.loadAllPerformances().take(3).toList();
    if (!mounted) return;
    setState(() {
      exams = list;
      filtered = _applyFilter(list, _search.text);
      recentPerformances = recents;
      loading = false;
    });
  }

  List<Exam> _applyFilter(List<Exam> src, String q) {
    final t = q.trim().toLowerCase();
    if (t.isEmpty) return List<Exam>.from(src);
    return src
        .where((e) => e.name.toLowerCase().contains(t) ||
            e.questions.any((qq) => qq.question.toLowerCase().contains(t)))
        .toList();
  }

  Future<void> _uploadExam() async {
    try {
      final importResult = await ImportService.pickAndPreviewFile();
      if (importResult == null) return;
      if (!mounted) return;

      final previewedExam = await Navigator.push<Exam>(
        context,
        MaterialPageRoute(
          builder: (_) => ImportPreviewScreen(importResult: importResult),
        ),
      );

      if (previewedExam == null) return;
      if (!mounted) return;

      final nameCtrl = TextEditingController(text: previewedExam.name.isNotEmpty ? previewedExam.name : 'Imported Exam');
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Name your exam'),
          content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Exam name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      final named = Exam(
        id: const Uuid().v4(), // Give it a fresh ID
        name: nameCtrl.text.trim().isEmpty ? previewedExam.name : nameCtrl.text.trim(),
        questions: previewedExam.questions,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddEditExamScreen(importedExam: named),
        ),
      );
      if (!mounted) return;
      await loadExams();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _takeExam({List<Exam>? source, String? initialExamId}) async {
    final available = source ?? (filtered.isNotEmpty ? filtered : exams);
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No exams. Upload one first.')),
      );
      return;
    }
    // Navigate to take exam screen (where user selects exam + time + name)
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TakeExamScreen(
          exams: available,
          initialExamId: initialExamId,
        ),
      ),
    );
  }

  Future<void> _retakeExam(String examId) async {
    final exists = exams.any((e) => e.id == examId);
    if (!exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exam no longer exists. Import it again.')),
      );
      return;
    }
    await _takeExam(source: exams, initialExamId: examId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        toolbarHeight: 80,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        title: const Text(
          'MCQ Exams',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StatisticsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Run audit',
            icon: const Icon(Icons.fact_check_outlined, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ExamAuditScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2ECF6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _search,
                            onChanged: (v) {
                              setState(() {
                                filtered = _applyFilter(exams, v);
                              });
                            },
                            decoration: InputDecoration(
                              hintText: 'Search exams or questions',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.deepPurple),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Builder(builder: (_) {
                            final s = AnalyticsService.getOverallStats();
                            return Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    color: Colors.deepPurple,
                                    label: 'Avg Score',
                                    value:
                                        '${(s['averageScore'] as double).toStringAsFixed(1)}%',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatCard(
                                    color: Colors.blue,
                                    label: 'Exams',
                                    value: '${s['totalExams']}',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _StatCard(
                                    color: Colors.green,
                                    label: 'Correct',
                                    value: '${s['totalCorrect']}',
                                  ),
                                ),
                              ],
                            );
                          }),
                          if (recentPerformances.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Recent performance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...recentPerformances.map(
                              (perf) => _RecentPerformanceTile(
                                performance: perf,
                                onRetake: exams.any((e) => e.id == perf.examId)
                                    ? () => _retakeExam(perf.examId)
                                    : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // MAIN CTA: UPLOAD EXAM
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _uploadExam,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade400,
                                Colors.deepPurple,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 4),
                              const Text(
                                'Upload Exam',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Select an Excel file to import questions',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.deepPurple,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                                onPressed: _uploadExam,
                                child: const Text('Browse & Upload'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // SECONDARY CTA: TAKE EXAM
                    if ((filtered.isNotEmpty || exams.isNotEmpty))
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _takeExam(),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: const Color(0xFFF7F1F8),
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 4),
                                const Text(
                                  'Take Exam',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${(filtered.isNotEmpty ? filtered.length : exams.length)} exam${(filtered.isNotEmpty ? filtered.length : exams.length) == 1 ? '' : 's'} available',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _takeExam(),
                                  child: const Text('Select & Start'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    const SizedBox(height: 24),

                    if (exams.isNotEmpty)
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.analytics,
                              color: Colors.deepPurple),
                          title: const Text('Statistics & Analytics'),
                          subtitle: const Text(
                              'View performance trends and insights'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StatisticsScreen(),
                              ),
                            );
                          },
                        ),
                      ),

                    if ((filtered.isNotEmpty || exams.isNotEmpty)) ...[
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Practice Mode',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...(filtered.isNotEmpty ? filtered : exams).map(
                        (exam) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading:
                                const Icon(Icons.school, color: Colors.blue),
                            title: Text(exam.name),
                            subtitle:
                                Text('${exam.questions.length} questions'),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PracticeModeScreen(
                                    questions: exam.questions,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Your Exams',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: (filtered.isNotEmpty ? filtered : exams).length,
                        itemBuilder: (context, i) {
                          final e = (filtered.isNotEmpty ? filtered : exams)[i];
                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(
                                e.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text('${e.questions.length} questions'),
                              leading: const Icon(Icons.description_outlined, color: Colors.deepPurple),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AddEditExamScreen(examId: e.id),
                                        ),
                                      ).then((_) => loadExams());
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Delete Exam'),
                                          content: Text('Delete "${e.name}"? This cannot be undone.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                              onPressed: () => Navigator.pop(ctx, true),
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (ok == true) {
                                        await StorageService.deleteExamFile('${e.id}.json');
                                        await loadExams();
                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          const SnackBar(content: Text('Exam deleted')),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                              onTap: () => _takeExam(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _StatCard({required this.color, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RecentPerformanceTile extends StatelessWidget {
  final ExamPerformance performance;
  final VoidCallback? onRetake;

  const _RecentPerformanceTile({
    required this.performance,
    this.onRetake,
  });

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[date.month - 1];
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final meridiem = date.hour >= 12 ? 'PM' : 'AM';
    return '$month $day • $hour:$minute $meridiem';
  }

  @override
  Widget build(BuildContext context) {
    final color = performance.percentage >= 80
        ? Colors.green
        : performance.percentage >= 60
            ? Colors.orange
            : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Text(
            '${performance.percentage.toStringAsFixed(0)}%',
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          performance.examName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${performance.correct}/${performance.totalQuestions} correct • ${_formatDate(performance.date)}',
        ),
        trailing: onRetake == null
            ? const SizedBox.shrink()
            : TextButton.icon(
                onPressed: onRetake,
                icon: const Icon(Icons.replay, size: 16),
                label: const Text('Retake'),
              ),
      ),
    );
  }
}
