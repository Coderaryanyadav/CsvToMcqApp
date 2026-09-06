import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../services/import_service.dart';
import '../models/exam.dart';
import '../models/performance.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import 'take_exam_screen.dart';
import 'statistics_screen.dart';
import 'question_bank_screen.dart';
import 'settings_screen.dart';
import 'import_preview_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeNavTab = 0; // 0: Dashboard, 1: Exams, 2: Question Bank, 3: History
  List<Exam> exams = [];
  List<ExamPerformance> performances = [];
  bool loading = true;
  final TextEditingController _searchCtrl = TextEditingController();
  String _examFilter = 'All'; // All | In Progress | Not Started | Completed

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await StorageService.init();
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    final allExams = await StorageService.loadAllExams();
    final allPerfs = StorageService.loadAllPerformances();

    // If no exams exist yet, initialize sample exams (CIA, CISA, SQL)
    if (allExams.isEmpty) {
      final sampleCIA = Exam(
        id: 'cia_exam',
        name: 'CIA',
        questions: [
          Question(
            id: 'Q1',
            question: 'Which of the following best defines the primary purpose of an internal audit activity?',
            options: [
              'To detect fraud and report it to external authorities.',
              'To provide independent, objective assurance and consulting designed to add value.',
              'To certify financial statements for investors.',
              'To replace external auditors for operational assessments.',
            ],
            correctAnswers: {1},
            optionExplanations: {
              0: 'Detecting fraud is a management responsibility assisted by internal audit, not the primary purpose.',
              1: 'The IIA defines internal auditing as an independent, objective assurance and consulting activity designed to add value.',
              2: 'External auditors certify financial statements.',
              3: 'Internal auditors complement but do not replace external auditors.',
            },
            topic: 'Governance & Audit',
            difficulty: 3,
            tags: ['Audit', 'Governance'],
          ),
          Question(
            id: 'Q2',
            question: 'Which principles are part of the IIA Code of Ethics? (Select all that apply)',
            options: [
              'Integrity',
              'Objectivity',
              'Confidentiality',
              'Maximizing Profitability',
            ],
            questionType: 'multiple',
            correctAnswers: {0, 1, 2},
            optionExplanations: {
              0: 'Integrity establishes trust and provides the basis for reliance on judgment.',
              1: 'Objectivity ensures auditors exhibit highest professional objectivity in gathering information.',
              2: 'Confidentiality requires respecting the value and ownership of information received.',
              3: 'Maximizing profitability is a business goal, not an ethical principle.',
            },
            topic: 'Ethics',
            difficulty: 4,
            tags: ['Ethics', 'Standards'],
          ),
        ],
      );

      final sampleCISA = Exam(
        id: 'cisa_exam',
        name: 'CISA',
        questions: [
          Question(
            id: 'Q1',
            question: 'What is the primary role of an IS auditor during a business continuity audit?',
            options: [
              'Develop and test the disaster recovery plan.',
              'Evaluate the adequacy of the BCP and test results.',
              'Procure alternate site facilities.',
              'Declare disaster status in emergency.',
            ],
            correctAnswers: {1},
            optionExplanations: {
              0: 'Management develops the plan; auditor independence must be maintained.',
              1: 'The IS auditor assesses adequacy, effectiveness, and test results.',
              2: 'Procurement is an operational management task.',
              3: 'Disaster declaration is a management decision.',
            },
            topic: 'Business Continuity',
            difficulty: 3,
            tags: ['BCP', 'IS Audit'],
          ),
        ],
      );

      await StorageService.saveExam(sampleCIA);
      await StorageService.saveExam(sampleCISA);
      allExams.addAll([sampleCIA, sampleCISA]);
    }

    if (!mounted) return;
    setState(() {
      exams = allExams;
      performances = allPerfs;
      loading = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _createExamDialog() async {
    final nameCtrl = TextEditingController();
    final created = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Exam'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Exam Code / Title (e.g. CIA, CISA, SQL, AWS)',
            hintText: 'e.g. AWS Solutions Architect',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final val = nameCtrl.text.trim();
              if (val.isNotEmpty) Navigator.pop(ctx, val);
            },
            child: const Text('Create Exam'),
          ),
        ],
      ),
    );

    if (created != null && created.isNotEmpty) {
      final newExam = Exam(
        id: const Uuid().v4(),
        name: created,
        questions: [],
      );
      await StorageService.saveExam(newExam);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exam "$created" created successfully!'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  Future<void> _startImportFlow([Exam? preselected]) async {
    Exam? target = preselected ?? (exams.isNotEmpty ? exams.first : null);
    if (exams.isEmpty) {
      await _createExamDialog();
      if (exams.isEmpty) return;
      target = exams.first;
    }

    if (preselected == null && exams.length > 1) {
      if (!mounted) return;
      final chosen = await showDialog<Exam>(
        context: context,
        builder: (ctx) {
          Exam? currentTarget = target;
          return StatefulBuilder(
            builder: (context, setDlgState) => AlertDialog(
              title: const Text('Select Target Exam'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Choose the exam to import questions into:'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: currentTarget?.id,
                    decoration: const InputDecoration(labelText: 'Exam'),
                    items: exams
                        .map((e) => DropdownMenuItem(
                              value: e.id,
                              child: Text('${e.name} (${e.questions.length} questions)'),
                            ))
                        .toList(),
                    onChanged: (id) {
                      if (id != null) {
                        setDlgState(() {
                          currentTarget = exams.firstWhere((e) => e.id == id);
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, currentTarget),
                  child: const Text('Select File'),
                ),
              ],
            ),
          );
        },
      );
      if (chosen == null) return;
      target = chosen;
    }

    if (target == null) return;

    try {
      final importResult = await ImportService.pickAndPreviewFile(targetExam: target);
      if (importResult == null) return;
      if (!mounted) return;

      final validQuestions = await Navigator.push<List<Question>>(
        context,
        MaterialPageRoute(
          builder: (_) => ImportPreviewScreen(importResult: importResult),
        ),
      );

      if (validQuestions != null && validQuestions.isNotEmpty) {
        final prevCount = target.questions.length;
        target.questions.addAll(validQuestions);
        target.reindexQuestions();
        await StorageService.saveExam(target);
        await _loadData();

        if (!mounted) return;
        _showImportSuccessDialog(target.name, prevCount, validQuestions.length, target.questions.length);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  void _showImportSuccessDialog(String examName, int prevCount, int importedCount, int newTotal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: AppTheme.success, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'Import Complete',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              const SizedBox(height: 6),
              Text(
                '$importedCount questions successfully added to $examName.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.secondaryText, fontSize: 14),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('Previous', '$prevCount'),
                    const Text('+', style: TextStyle(color: AppTheme.secondaryText, fontWeight: FontWeight.bold)),
                    _buildStatCol('Imported', '$importedCount', highlight: true),
                    const Text('=', style: TextStyle(color: AppTheme.secondaryText, fontWeight: FontWeight.bold)),
                    _buildStatCol('New Total', '$newTotal'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startImportFlow();
            },
            child: const Text('Import Another CSV'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _activeNavTab = 2); // Switch to Question Bank
            },
            child: const Text('View Question Bank'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String val, {bool highlight = false}) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: highlight ? AppTheme.accentBlue : AppTheme.text)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.secondaryText)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNavBar(),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildActiveTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  // Top QuizPro SaaS Navigation Bar
  Widget _buildTopNavBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // Logo / Brand
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.quiz, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'QuizPro',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryNavy,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 32),

          // Nav items
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _navButton(0, 'Dashboard', Icons.dashboard_outlined),
                  _navButton(1, 'Exams', Icons.assignment_outlined),
                  _navButton(2, 'Question Bank', Icons.storage_outlined),
                  _navButton(3, 'Import Questions', Icons.file_upload_outlined, isImportAction: true),
                  _navButton(4, 'Practice History', Icons.history),
                  _navButton(5, 'Results', Icons.insights_outlined),
                ],
              ),
            ),
          ),

          // Right Profile & Notifications
          Row(
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Badge(
                  label: Text('2'),
                  child: Icon(Icons.notifications_none, color: AppTheme.secondaryText, size: 22),
                ),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined, color: AppTheme.secondaryText, size: 22),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              const SizedBox(width: 12),
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryNavy,
                child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 8),
              const Text('Aryan', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.text)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navButton(int index, String label, IconData icon, {bool isImportAction = false}) {
    final isSelected = _activeNavTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (isImportAction) {
            _startImportFlow();
          } else if (index == 5) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen()));
          } else {
            setState(() => _activeNavTab = index);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.background : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isSelected ? AppTheme.accentBlue : AppTheme.secondaryText),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppTheme.text : AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeNavTab) {
      case 1:
        return _buildExamsScreen();
      case 2:
        return QuestionBankScreen(exams: exams);
      case 4:
        return _buildHistoryScreen();
      case 0:
      default:
        return _buildDashboardContent();
    }
  }

  // 1. MAIN DASHBOARD CONTENT
  Widget _buildDashboardContent() {
    int totalQuestionsAnswered = 0;
    int totalCorrect = 0;
    int totalStudySecs = 0;

    for (var p in performances) {
      totalQuestionsAnswered += p.totalQuestions;
      totalCorrect += p.correct;
      totalStudySecs += p.durationSeconds;
    }

    final double avgScore = totalQuestionsAnswered > 0
        ? (totalCorrect / totalQuestionsAnswered) * 100
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard Heading
              const Text(
                'Good morning, Aryan',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose an exam and continue your preparation.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.secondaryText,
                ),
              ),
              const SizedBox(height: 24),

              // KPI Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Questions Answered',
                      value: '$totalQuestionsAnswered',
                      icon: Icons.quiz_outlined,
                      color: AppTheme.accentBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Average Score',
                      value: '${avgScore.toStringAsFixed(0)}%',
                      icon: Icons.trending_up,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Study Time',
                      value: '${totalStudySecs ~/ 60} min',
                      icon: Icons.timer_outlined,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      label: 'Active Exams',
                      value: '${exams.length}',
                      icon: Icons.school_outlined,
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Exams Cards Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Your Exam Question Banks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('+ Add Exam'),
                    onPressed: _createExamDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Exam Cards List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: exams.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final exam = exams[index];
                  return _buildExamDashboardCard(exam);
                },
              ),
              const SizedBox(height: 32),

              // Recent Activity Section
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 12),
              if (performances.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Center(
                    child: Text(
                      'No practice sessions yet. Start a session to see your progress here.',
                      style: TextStyle(color: AppTheme.secondaryText),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: performances.take(4).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final perf = performances[idx];
                    return _buildActivityTile(perf);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExamDashboardCard(Exam exam) {
    final perf = performances.where((p) => p.examId == exam.id).toList();
    final double progressPct = exam.questions.isNotEmpty
        ? ((perf.isNotEmpty ? perf.first.percentage : 40) / 100).clamp(0.0, 1.0)
        : 0.0;

    String subtitle = 'Professional Certification Question Bank';
    if (exam.name.toUpperCase().contains('CIA')) {
      subtitle = 'Certified Internal Auditor';
    } else if (exam.name.toUpperCase().contains('CISA')) {
      subtitle = 'Certified Information Systems Auditor';
    } else if (exam.name.toUpperCase().contains('SQL')) {
      subtitle = 'Database Querying & Administration';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school, color: AppTheme.primaryNavy, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  '${exam.questions.length} Questions',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress Bar & Info
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPct,
                    minHeight: 8,
                    backgroundColor: AppTheme.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${(progressPct * 100).toInt()}% Progress',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Card Action Buttons
          Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.school_outlined, size: 18),
                label: const Text('Practice'),
                onPressed: exam.questions.isNotEmpty
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TakeExamScreen(
                              exams: exams,
                              initialExamId: exam.id,
                              defaultToPractice: true,
                            ),
                          ),
                        ).then((_) => _loadData());
                      }
                    : null,
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: const Text('Start Exam'),
                onPressed: exam.questions.isNotEmpty
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TakeExamScreen(
                              exams: exams,
                              initialExamId: exam.id,
                            ),
                          ),
                        ).then((_) => _loadData());
                      }
                    : null,
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.storage, size: 18),
                label: const Text('Question Bank'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuestionBankScreen(
                        exams: exams,
                        initialExamId: exam.id,
                      ),
                    ),
                  ).then((_) => _loadData());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(ExamPerformance perf) {
    final pct = perf.percentage;
    final color = pct >= 80 ? AppTheme.success : (pct >= 60 ? AppTheme.warning : AppTheme.danger);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${pct.round()}%',
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perf.examName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.text),
                ),
                Text(
                  '${perf.correct}/${perf.totalQuestions} correct • ${perf.date.toLocal().toString().split(' ').first}',
                  style: const TextStyle(color: AppTheme.secondaryText, fontSize: 13),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Retake', style: TextStyle(fontSize: 13)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TakeExamScreen(exams: exams, initialExamId: perf.examId),
                ),
              ).then((_) => _loadData());
            },
          ),
        ],
      ),
    );
  }

  // 2. EXAMS SCREEN
  Widget _buildExamsScreen() {
    final query = _searchCtrl.text.trim().toLowerCase();
    var list = exams.where((e) {
      if (query.isEmpty) return true;
      return e.name.toLowerCase().contains(query) ||
          e.questions.any((q) => q.question.toLowerCase().contains(query));
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exams',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${exams.length} Certification Tracks Available',
                        style: const TextStyle(color: AppTheme.secondaryText, fontSize: 14),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('+ Add Exam'),
                    onPressed: _createExamDialog,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search & Filter Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search exams...',
                        prefixIcon: Icon(Icons.search, color: AppTheme.secondaryText),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Wrap(
                    spacing: 8,
                    children: ['All', 'In Progress', 'Not Started', 'Completed'].map((f) {
                      final isSel = _examFilter == f;
                      return ChoiceChip(
                        label: Text(f),
                        selected: isSel,
                        onSelected: (v) => setState(() => _examFilter = f),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Exam Cards
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, idx) => _buildExamDashboardCard(list[idx]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. PRACTICE HISTORY
  Widget _buildHistoryScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Practice & Exam History',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.text),
              ),
              const SizedBox(height: 4),
              const Text(
                'Review all past practice and exam simulation attempts.',
                style: TextStyle(color: AppTheme.secondaryText, fontSize: 14),
              ),
              const SizedBox(height: 24),
              if (performances.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Text('No exam attempts recorded yet.'),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: performances.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, idx) => _buildActivityTile(performances[idx]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
