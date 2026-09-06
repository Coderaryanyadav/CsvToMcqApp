import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../services/import_service.dart';
import '../models/exam.dart';
import '../models/performance.dart';
import '../models/question.dart';
import '../models/student_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'take_exam_screen.dart';
import 'statistics_screen.dart';
import 'question_bank_screen.dart';
import 'settings_screen.dart';
import 'import_preview_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _activeNavTab = 0; // 0: Dashboard, 1: Exams, 2: Question Bank, 3: History
  List<Exam> exams = [];
  List<ExamPerformance> performances = [];
  StudentProfile? activeStudent;
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
    await StorageService.seedStarterDataIfEmpty();
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() => loading = true);
    final allExams = await StorageService.loadAllExams();
    final student = await StorageService.getActiveStudent();
    final allPerfs = await StorageService.loadPerformancesForActiveStudent();

    if (!mounted) return;
    setState(() {
      exams = allExams;
      activeStudent = student;
      performances = allPerfs;
      loading = false;
    });
  }

  Future<void> _openStudentSwitcher() async {
    final changed = await Navigator.push<StudentProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => const WelcomeScreen(isSwitching: true),
      ),
    );
    if (changed != null) {
      await _loadData();
    }
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
                              child: Text(
                                  '${e.name} (${e.questions.length} questions)'),
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
      final importResult =
          await ImportService.pickAndPreviewFile(targetExam: target);
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
        _showImportSuccessDialog(target.name, prevCount, validQuestions.length,
            target.questions.length);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  void _showImportSuccessDialog(
      String examName, int prevCount, int importedCount, int newTotal) {
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
                child: const Icon(Icons.check_circle,
                    color: AppTheme.success, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'Import Complete',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text),
              ),
              const SizedBox(height: 6),
              Text(
                '$importedCount questions successfully added to $examName.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.secondaryText, fontSize: 14),
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
                    const Text('+',
                        style: TextStyle(
                            color: AppTheme.secondaryText,
                            fontWeight: FontWeight.bold)),
                    _buildStatCol('Imported', '$importedCount',
                        highlight: true),
                    const Text('=',
                        style: TextStyle(
                            color: AppTheme.secondaryText,
                            fontWeight: FontWeight.bold)),
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
        Text(val,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: highlight ? AppTheme.accentBlue : AppTheme.text)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.secondaryText)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: AppTheme.background,
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: (_activeNavTab >= 0 && _activeNavTab <= 2)
                  ? _activeNavTab
                  : (_activeNavTab == 4 ? 3 : 0),
              onDestinationSelected: (idx) {
                if (idx == 3) {
                  setState(() => _activeNavTab = 4); // History tab
                } else {
                  setState(() => _activeNavTab = idx);
                }
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: 'Exams',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storage_outlined),
                  selectedIcon: Icon(Icons.storage),
                  label: 'Bank',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: 'History',
                ),
              ],
            )
          : null,
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
    final isMobile = MediaQuery.of(context).size.width < 900;

    if (isMobile) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppTheme.border)),
        ),
        child: Row(
          children: [
            const AppLogo(size: 32, fontSize: 18, showBadge: false),
            const Spacer(),
            // Student Profile Quick Switcher Pill
            InkWell(
              onTap: _openStudentSwitcher,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (activeStudent != null
                          ? Color(activeStudent!.avatarColorValue)
                          : AppTheme.primaryNavy)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (activeStudent != null
                            ? Color(activeStudent!.avatarColorValue)
                            : AppTheme.primaryNavy)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(activeStudent?.avatarEmoji ?? '🎓',
                        style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 4),
                    Text(
                      activeStudent?.name ?? 'Student',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: activeStudent != null
                            ? Color(activeStudent!.avatarColorValue)
                            : AppTheme.text,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down,
                        size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined, size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ).then((_) => _loadData());
              },
            ),
          ],
        ),
      );
    }

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
          const AppLogo(),
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
                  _navButton(3, 'Import Questions', Icons.file_upload_outlined,
                      isImportAction: true),
                  _navButton(4, 'Practice History', Icons.history),
                  _navButton(5, 'Results', Icons.insights_outlined),
                ],
              ),
            ),
          ),

          // Right Profile & Quick Actions
          Row(
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Exam',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _createExamDialog,
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined, size: 20),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ).then((_) => _loadData());
                },
              ),
              const SizedBox(width: 8),
              // Interactive Student Profile Switcher
              InkWell(
                onTap: _openStudentSwitcher,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (activeStudent != null
                            ? Color(activeStudent!.avatarColorValue)
                            : AppTheme.primaryNavy)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: (activeStudent != null
                              ? Color(activeStudent!.avatarColorValue)
                              : AppTheme.primaryNavy)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(activeStudent?.avatarEmoji ?? '🎓',
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        activeStudent?.name ?? 'Select Student',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: activeStudent != null
                              ? Color(activeStudent!.avatarColorValue)
                              : AppTheme.text,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.swap_horiz,
                          size: 18, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navButton(int index, String label, IconData icon,
      {bool isImportAction = false}) {
    final isSelected = _activeNavTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (isImportAction) {
            _startImportFlow();
          } else if (index == 5) {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatisticsScreen()));
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
              Icon(icon,
                  size: 18,
                  color: isSelected
                      ? AppTheme.accentBlue
                      : AppTheme.secondaryText),
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

    final isMobile = MediaQuery.of(context).size.width < 900;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 16 : 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard Heading
              Text(
                activeStudent != null
                    ? 'Welcome, ${activeStudent!.name}! ${activeStudent!.avatarEmoji}'
                    : 'Welcome to QuizPro',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                activeStudent != null
                    ? 'Here is your active practice progress and performance overview.'
                    : 'Create and manage your MCQ question banks, practice, and track performance.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryText,
                ),
              ),
              const SizedBox(height: 20),

              // KPI Stats Row / Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                label: 'Answered',
                                value: '$totalQuestionsAnswered',
                                icon: Icons.quiz_outlined,
                                color: AppTheme.accentBlue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                label: 'Avg Score',
                                value: '${avgScore.toStringAsFixed(0)}%',
                                icon: Icons.trending_up,
                                color: AppTheme.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                label: 'Study Time',
                                value: '${totalStudySecs ~/ 60} min',
                                icon: Icons.timer_outlined,
                                color: AppTheme.primaryNavy,
                              ),
                            ),
                            const SizedBox(width: 12),
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
                      ],
                    );
                  }

                  return Row(
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
                  );
                },
              ),
              const SizedBox(height: 24),

              // Exams Cards Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Exam Question Banks',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Exam'),
                    onPressed: _createExamDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Exam Cards List or Clean Empty State
              if (exams.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.assignment_add,
                          color: AppTheme.accentBlue,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Exams Created Yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Get started by creating a new exam track or importing your question bank from CSV or JSON.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Create New Exam'),
                            onPressed: _createExamDialog,
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.file_upload_outlined,
                                size: 18),
                            label: const Text('Import Questions'),
                            onPressed: _startImportFlow,
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: exams.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final exam = exams[index];
                    return _buildExamDashboardCard(exam);
                  },
                ),
              const SizedBox(height: 24),

              // Recent Activity Section
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.text,
                ),
              ),
              const SizedBox(height: 12),
              if (performances.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Center(
                    child: Text(
                      'No practice sessions yet. Start a session to see your progress here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.secondaryText, fontSize: 13),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamDashboardCard(Exam exam) {
    final perf = performances.where((p) => p.examId == exam.id).toList();
    final double progressPct = (perf.isNotEmpty && exam.questions.isNotEmpty)
        ? (perf.first.percentage / 100).clamp(0.0, 1.0)
        : 0.0;

    final String subtitle = exam.questions.isNotEmpty
        ? '${exam.questions.length} questions • Ready for practice'
        : 'No questions yet • Tap below to import';

    return Container(
      padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.school,
                    color: AppTheme.primaryNavy, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  '${exam.questions.length} Qs',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress Bar & Info
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPct,
                    minHeight: 6,
                    backgroundColor: AppTheme.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.accentBlue),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(progressPct * 100).toInt()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppTheme.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Card Action Buttons - Responsive Wrap
          LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.school_outlined, size: 16),
                          label: const Text('Practice', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
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
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.timer_outlined, size: 16),
                          label: const Text('Start Exam', style: TextStyle(fontSize: 12)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.file_upload_outlined, size: 14),
                        label: const Text('Import CSV', style: TextStyle(fontSize: 12)),
                        onPressed: () => _startImportFlow(exam),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.storage_outlined, size: 14),
                        label: const Text('Question Bank', style: TextStyle(fontSize: 12)),
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
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTile(ExamPerformance perf) {
    final pct = perf.percentage;
    final color = pct >= 80
        ? AppTheme.success
        : (pct >= 60 ? AppTheme.warning : AppTheme.danger);
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${pct.round()}%',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: isMobile ? 12 : 13),
            ),
          ),
          SizedBox(width: isMobile ? 10 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  perf.examName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 15,
                      color: AppTheme.text),
                ),
                const SizedBox(height: 2),
                Text(
                  '${perf.correct}/${perf.totalQuestions} correct • ${perf.date.toLocal().toString().split(' ').first}',
                  style: TextStyle(
                      color: AppTheme.secondaryText, fontSize: isMobile ? 11 : 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 10 : 14,
                vertical: isMobile ? 6 : 8,
              ),
              visualDensity: VisualDensity.compact,
            ),
            child: Text('Retake', style: TextStyle(fontSize: isMobile ? 12 : 13)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TakeExamScreen(exams: exams, initialExamId: perf.examId),
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
    final isMobile = MediaQuery.of(context).size.width < 900;
    final query = _searchCtrl.text.trim().toLowerCase();
    var list = exams.where((e) {
      if (query.isEmpty) return true;
      return e.name.toLowerCase().contains(query) ||
          e.questions.any((q) => q.question.toLowerCase().contains(query));
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 16 : 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Exams',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${exams.length} Tracks Available',
                          style: const TextStyle(
                              color: AppTheme.secondaryText, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Exam', style: TextStyle(fontSize: 12)),
                    onPressed: _createExamDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search & Filter Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search exams...',
                      prefixIcon:
                          Icon(Icons.search, color: AppTheme.secondaryText),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'In Progress', 'Not Started', 'Completed']
                          .map((f) {
                        final isSel = _examFilter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(f, style: const TextStyle(fontSize: 12)),
                            selected: isSel,
                            onSelected: (v) => setState(() => _examFilter = f),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Exam Cards or Empty State
              if (list.isEmpty)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryNavy.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.school_outlined,
                          color: AppTheme.primaryNavy,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        exams.isEmpty
                            ? 'No Exams Available'
                            : 'No Matching Exams',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        exams.isEmpty
                            ? 'Add an exam track or import questions to start your practice sessions.'
                            : 'Try adjusting your search query or filters.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.secondaryText,
                        ),
                      ),
                      if (exams.isEmpty) ...[
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Exam Track'),
                          onPressed: _createExamDialog,
                        ),
                      ],
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, idx) =>
                      _buildExamDashboardCard(list[idx]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. PRACTICE HISTORY
  Widget _buildHistoryScreen() {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: isMobile ? 16 : 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Practice & Exam History',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.text),
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
                  itemBuilder: (context, idx) =>
                      _buildActivityTile(performances[idx]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
