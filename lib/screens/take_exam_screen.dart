import 'package:flutter/material.dart';
import '../models/exam.dart';
import '../models/question.dart';
import '../services/question_selection_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'exam_screen.dart';
import 'practice_mode_screen.dart';

class TakeExamScreen extends StatefulWidget {
  final List<Exam> exams;
  final String? initialExamId;
  final bool defaultToPractice;
  final bool defaultToStarred;

  const TakeExamScreen({
    super.key,
    required this.exams,
    this.initialExamId,
    this.defaultToPractice = false,
    this.defaultToStarred = false,
  });

  @override
  State<TakeExamScreen> createState() => _TakeExamScreenState();
}

class _TakeExamScreenState extends State<TakeExamScreen> {
  Exam? selectedExam;
  bool isPracticeMode = true;
  bool onlyStarred = false;
  Set<String> _bookmarkedIds = {};

  // Question Types selection state
  bool isAllQuestionTypes = true;
  Set<String> selectedQuestionTypes = {};
  List<QuestionTypeInfo> availableQuestionTypes = [];

  // Question count state
  int selectedQuestionCount = 20;
  bool isAllQuestions = false;
  bool isCustomCount = false;

  // Duration state
  int selectedDurationMin = 30; // 0 = Untimed
  bool isCustomDuration = false;

  // Shuffle & filters state
  bool shuffleQuestions = true;
  bool shuffleOptions = false;
  String selectedDifficulty = 'Any';
  String selectedChapter = 'All Chapters';
  List<String> availableChapters = ['All Chapters'];
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
    onlyStarred = widget.defaultToStarred;
    _loadBookmarks();
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

  Future<void> _loadBookmarks() async {
    final activeStudent = await StorageService.getActiveStudent();
    final ids =
        await StorageService.getBookmarkedQuestionIds(activeStudent?.id);
    if (mounted) {
      setState(() {
        _bookmarkedIds = ids;
      });
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

    // Discover supported question types in the selected exam
    availableQuestionTypes =
        QuestionTypeHelper.discoverTypes(selectedExam!.questions);
    isAllQuestionTypes = true;
    selectedQuestionTypes = availableQuestionTypes.map((t) => t.id).toSet();

    final totalQ = selectedExam!.questions.length;
    if (totalQ < 20) {
      selectedQuestionCount = totalQ > 0 ? totalQ : 10;
    } else {
      selectedQuestionCount = 20;
    }
    selectedDurationMin = selectedExam!.defaultDuration ?? 30;

    _customCountCtrl.text = '$selectedQuestionCount';
    _customDurationCtrl.text = '$selectedDurationMin';

    final chapters =
        QuestionSelectionService.discoverChapters(selectedExam!.questions);
    availableChapters = ['All Chapters', ...chapters];
    selectedChapter = 'All Chapters';

    _updateTopics();
  }

  void _updateTopics() {
    if (selectedExam == null) {
      availableTopics = ['All Topics'];
      selectedTopic = 'All Topics';
      return;
    }
    final topics = QuestionSelectionService.discoverTopics(
      selectedExam!.questions,
      selectedChapter: selectedChapter,
    );
    availableTopics = ['All Topics', ...topics];
    if (!availableTopics.contains(selectedTopic)) {
      selectedTopic = 'All Topics';
    }
  }

  QuestionAvailability get _availability {
    if (selectedExam == null) {
      return const QuestionAvailability(
        totalAvailable: 0,
        countsByType: {},
        totalStarred: 0,
      );
    }
    return QuestionSelectionService.getAvailability(
      questions: selectedExam!.questions,
      selectedChapter: selectedChapter,
      selectedTopic: selectedTopic,
      selectedDifficulty: selectedDifficulty,
      onlyStarred: onlyStarred,
      bookmarkedIds: _bookmarkedIds,
    );
  }

  int get _starredQuestionsCount => _availability.totalStarred;

  int get _availableQuestionsCount {
    if (selectedExam == null) return 0;
    final avail = _availability;
    if (isAllQuestionTypes) {
      return avail.totalAvailable;
    }
    int count = 0;
    for (final typeId in selectedQuestionTypes) {
      count += avail.getCountForType(typeId);
    }
    return count;
  }

  int get _effectiveQuestionCount {
    if (isAllQuestions) return _availableQuestionsCount;
    if (isCustomCount) {
      return int.tryParse(_customCountCtrl.text.trim()) ??
          selectedQuestionCount;
    }
    return selectedQuestionCount;
  }

  String? get _questionCountError {
    return QuestionSelectionService.validateSelection(
      availableCount: _availableQuestionsCount,
      requestedCount: _effectiveQuestionCount,
      selectedQuestionTypes: selectedQuestionTypes,
      isAllQuestionTypes: isAllQuestionTypes,
      allAvailableTypes: availableQuestionTypes,
      onlyStarred: onlyStarred,
      examName: selectedExam?.name,
    );
  }

  List<Question> _getFilteredQuestions() {
    if (selectedExam == null) return [];
    return QuestionSelectionService.filterQuestions(
      questions: selectedExam!.questions,
      selectedQuestionTypes: selectedQuestionTypes,
      isAllQuestionTypes: isAllQuestionTypes,
      selectedChapter: selectedChapter,
      selectedTopic: selectedTopic,
      selectedDifficulty: selectedDifficulty,
      onlyStarred: onlyStarred,
      bookmarkedIds: _bookmarkedIds,
      shuffleQuestions: shuffleQuestions,
      shuffleOptions: shuffleOptions,
      count: isAllQuestions ? null : _effectiveQuestionCount,
      isAllQuestions: isAllQuestions,
    );
  }

  void _startSession() {
    if (selectedExam == null) return;

    if (isCustomCount) {
      final val = int.tryParse(_customCountCtrl.text.trim());
      if (val != null && val > 0) {
        selectedQuestionCount = val;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid number of questions.'),
            backgroundColor: AppTheme.danger,
          ),
        );
        return;
      }
    }

    if (isCustomDuration) {
      final val = int.tryParse(_customDurationCtrl.text.trim());
      if (val != null && val >= 0) {
        selectedDurationMin = val;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Please enter a valid duration in minutes (0 for untimed).'),
            backgroundColor: AppTheme.danger,
          ),
        );
        return;
      }
    }

    final countError = _questionCountError;
    if (countError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(countError),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

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
            examId: selectedExam!.id,
            examName: selectedExam!.name,
            passingPercentage: selectedExam!.passingPercentage,
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
            selectedQuestionTypes: selectedQuestionTypes,
            isAllQuestionTypes: isAllQuestionTypes,
            shuffleQuestions: shuffleQuestions,
          ),
        ),
      );
    }
  }

  void _toggleAllQuestionTypes(bool selectAll) {
    setState(() {
      if (selectAll) {
        isAllQuestionTypes = true;
        selectedQuestionTypes = availableQuestionTypes.map((t) => t.id).toSet();
      } else {
        isAllQuestionTypes = false;
        selectedQuestionTypes = {};
      }
    });
  }

  void _toggleQuestionType(String typeId, bool isSelected) {
    setState(() {
      if (isSelected) {
        selectedQuestionTypes.add(typeId);
        if (selectedQuestionTypes.length == availableQuestionTypes.length) {
          isAllQuestionTypes = true;
        }
      } else {
        selectedQuestionTypes.remove(typeId);
        isAllQuestionTypes = false;
      }
    });
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

    final avail = _availability;

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

                // 3. QUESTION TYPES SELECTION
                _sectionTitle(
                  '3. Question Types ($_availableQuestionsCount Available)',
                  Icons.category_outlined,
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Allowed Question Types',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.primaryNavy,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => _toggleAllQuestionTypes(true),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isAllQuestionTypes
                                          ? AppTheme.accentBlue
                                              .withValues(alpha: 0.1)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Select All',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isAllQuestionTypes
                                            ? AppTheme.accentBlue
                                            : AppTheme.secondaryText,
                                      ),
                                    ),
                                  ),
                                ),
                                const Text(' • ',
                                    style: TextStyle(
                                        color: AppTheme.secondaryText)),
                                InkWell(
                                  onTap: () => _toggleAllQuestionTypes(false),
                                  borderRadius: BorderRadius.circular(6),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    child: Text(
                                      'Clear',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.secondaryText,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Master "All Question Types" Tile
                        InkWell(
                          onTap: () =>
                              _toggleAllQuestionTypes(!isAllQuestionTypes),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isAllQuestionTypes
                                  ? (isDark
                                      ? AppTheme.accentBlue
                                          .withValues(alpha: 0.15)
                                      : const Color(0xFFEFF6FF))
                                  : (isDark
                                      ? AppTheme.darkSurface
                                      : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isAllQuestionTypes
                                    ? AppTheme.accentBlue
                                    : (isDark
                                        ? AppTheme.darkBorder
                                        : AppTheme.border),
                                width: isAllQuestionTypes ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isAllQuestionTypes
                                        ? AppTheme.accentBlue
                                        : (isDark
                                            ? AppTheme.darkBorder
                                            : Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.auto_awesome_rounded,
                                    color: isAllQuestionTypes
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'All Question Types',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white
                                              : AppTheme.text,
                                        ),
                                      ),
                                      Text(
                                        'Include all ${avail.totalAvailable} questions in this track',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppTheme.darkSecondaryText
                                              : AppTheme.secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isAllQuestionTypes
                                        ? AppTheme.accentBlue
                                            .withValues(alpha: 0.15)
                                        : (isDark
                                            ? AppTheme.darkBorder
                                            : Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${avail.totalAvailable} Qs',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isAllQuestionTypes
                                          ? AppTheme.accentBlue
                                          : (isDark
                                              ? AppTheme.darkSecondaryText
                                              : AppTheme.secondaryText),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  isAllQuestionTypes
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: isAllQuestionTypes
                                      ? AppTheme.accentBlue
                                      : (isDark
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400),
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Individual Question Type Rows/Cards
                        ...availableQuestionTypes.map((typeInfo) {
                          final count = avail.getCountForType(typeInfo.id);
                          final isTypeChecked =
                              selectedQuestionTypes.contains(typeInfo.id);
                          final isExplicitlySelected =
                              !isAllQuestionTypes && isTypeChecked;
                          final isMulti =
                              typeInfo.id == QuestionTypeHelper.typeMultiple ||
                                  typeInfo.id == 'multi' ||
                                  typeInfo.id == 'multiple';

                          // Color schemes tailored to each question type
                          final Color accentColor = isMulti
                              ? const Color(0xFF7C3AED)
                              : AppTheme.accentBlue;
                          final Color iconBg = isDark
                              ? (isTypeChecked
                                  ? accentColor.withValues(alpha: 0.25)
                                  : AppTheme.darkBorder)
                              : (isTypeChecked
                                  ? (isMulti
                                      ? const Color(0xFFF3E8FF)
                                      : const Color(0xFFDBEAFE))
                                  : Colors.grey.shade100);
                          final Color iconColor = isTypeChecked
                              ? accentColor
                              : (isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade400);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () {
                                if (isAllQuestionTypes) {
                                  // Direct toggle from "All": user targets only this format
                                  setState(() {
                                    isAllQuestionTypes = false;
                                    selectedQuestionTypes = {typeInfo.id};
                                  });
                                } else {
                                  _toggleQuestionType(
                                      typeInfo.id, !isTypeChecked);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  color: isExplicitlySelected
                                      ? (isDark
                                          ? accentColor.withValues(alpha: 0.12)
                                          : (isMulti
                                              ? const Color(0xFFFAF5FF)
                                              : const Color(0xFFEFF6FF)))
                                      : (isAllQuestionTypes && isTypeChecked
                                          ? (isDark
                                              ? AppTheme.darkSurface
                                              : Colors.white)
                                          : (isDark
                                              ? AppTheme.darkSurface
                                              : Colors.grey.shade50)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isExplicitlySelected
                                        ? accentColor
                                        : (isDark
                                            ? AppTheme.darkBorder
                                            : AppTheme.border),
                                    width: isExplicitlySelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: iconBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        typeInfo.icon,
                                        color: iconColor,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        typeInfo.displayName,
                                        style: TextStyle(
                                          fontWeight: isTypeChecked
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          fontSize: 14,
                                          color: isTypeChecked
                                              ? (isDark
                                                  ? Colors.white
                                                  : AppTheme.text)
                                              : (isDark
                                                  ? AppTheme.darkSecondaryText
                                                  : AppTheme.secondaryText),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isTypeChecked
                                            ? (isDark
                                                ? accentColor.withValues(
                                                    alpha: 0.2)
                                                : (isMulti
                                                    ? const Color(0xFFEDE9FE)
                                                    : const Color(0xFFE0F2FE)))
                                            : (isDark
                                                ? AppTheme.darkBorder
                                                : Colors.grey.shade100),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$count Qs',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isTypeChecked
                                              ? accentColor
                                              : (isDark
                                                  ? AppTheme.darkSecondaryText
                                                  : AppTheme.secondaryText),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      isTypeChecked
                                          ? Icons.check_box_rounded
                                          : Icons
                                              .check_box_outline_blank_rounded,
                                      color: isTypeChecked
                                          ? (isExplicitlySelected
                                              ? accentColor
                                              : AppTheme.accentBlue)
                                          : (isDark
                                              ? Colors.grey.shade600
                                              : Colors.grey.shade400),
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

                        if (!isAllQuestionTypes &&
                            selectedQuestionTypes.isEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 18, color: Colors.orange.shade800),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Please select at least one question type.',
                                    style: TextStyle(
                                      color: Colors.brown,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 4. NUMBER OF QUESTIONS
                _sectionTitle(
                  '4. Number of Questions ($_availableQuestionsCount Available)',
                  Icons.format_list_numbered,
                ),
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
                              final isOver = count > _availableQuestionsCount;
                              return ChoiceChip(
                                label: Text('$count Questions'),
                                selected: isSel,
                                avatar: isOver
                                    ? const Icon(Icons.warning_amber_rounded,
                                        size: 16, color: Colors.orange)
                                    : null,
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
                              label: Text('All ($_availableQuestionsCount)'),
                              selected: isAllQuestions,
                              onSelected: (v) {
                                if (v) {
                                  setState(() {
                                    isAllQuestions = true;
                                    isCustomCount = false;
                                    selectedQuestionCount =
                                        _availableQuestionsCount;
                                  });
                                }
                              },
                            ),
                            ChoiceChip(
                              label: const Text('Custom'),
                              selected: isCustomCount,
                              onSelected: (v) {
                                if (v) {
                                  setState(() {
                                    isCustomCount = true;
                                    isAllQuestions = false;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        if (isCustomCount)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: TextField(
                              controller: _customCountCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText:
                                    'Custom number of questions (Max: $_availableQuestionsCount)',
                                hintText:
                                    'Enter a number (1 - $_availableQuestionsCount)',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        if (_questionCountError != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        size: 20, color: Colors.red.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _questionCountError!,
                                        style: TextStyle(
                                          color: Colors.red.shade900,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_availableQuestionsCount > 0 &&
                                    _effectiveQuestionCount >
                                        _availableQuestionsCount) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            selectedQuestionCount =
                                                _availableQuestionsCount;
                                            _customCountCtrl.text =
                                                '$_availableQuestionsCount';
                                            isAllQuestions = false;
                                          });
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red.shade900,
                                          side: BorderSide(
                                              color: Colors.red.shade400),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.tune, size: 16),
                                        label: Text(
                                            'Set to $_availableQuestionsCount Max'),
                                      ),
                                      if (!isAllQuestionTypes)
                                        TextButton(
                                          onPressed: () =>
                                              _toggleAllQuestionTypes(true),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                AppTheme.accentBlue,
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          child: const Text('Select All Types'),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 5. DURATION SELECTION
                _sectionTitle('5. Exam Duration', Icons.access_time),
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
                            ..._presetDurations.map((duration) {
                              final isSel = !isCustomDuration &&
                                  selectedDurationMin == duration;
                              final label = duration == 0
                                  ? 'Untimed (No Limit)'
                                  : '$duration Minutes';
                              return ChoiceChip(
                                label: Text(label),
                                selected: isSel,
                                onSelected: (v) {
                                  if (v) {
                                    setState(() {
                                      isCustomDuration = false;
                                      selectedDurationMin = duration;
                                    });
                                  }
                                },
                              );
                            }),
                            ChoiceChip(
                              label: const Text('Custom'),
                              selected: isCustomDuration,
                              onSelected: (v) {
                                if (v) {
                                  setState(() {
                                    isCustomDuration = true;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        if (isCustomDuration)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: TextField(
                              controller: _customDurationCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Custom duration (minutes)',
                                hintText:
                                    'Enter duration in minutes (0 for untimed)',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 6. FILTERS & OPTIONS
                _sectionTitle('6. Filters & Options', Icons.tune_rounded),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Chapter Dropdown
                        Text(
                          'Chapter',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark
                                ? AppTheme.darkSecondaryText
                                : AppTheme.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurface
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.darkBorder
                                  : AppTheme.border,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedChapter,
                              icon: const Icon(Icons.arrow_drop_down_rounded,
                                  color: AppTheme.secondaryText),
                              items: availableChapters.map((ch) {
                                return DropdownMenuItem(
                                  value: ch,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.menu_book_outlined,
                                          size: 18,
                                          color: AppTheme.secondaryText),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          ch,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    selectedChapter = v;
                                    _updateTopics();
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Topic Dropdown
                        Text(
                          'Topic / Category',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark
                                ? AppTheme.darkSecondaryText
                                : AppTheme.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurface
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? AppTheme.darkBorder
                                  : AppTheme.border,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedTopic,
                              icon: const Icon(Icons.arrow_drop_down_rounded,
                                  color: AppTheme.secondaryText),
                              items: availableTopics.map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.topic_outlined,
                                          size: 18,
                                          color: AppTheme.secondaryText),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          t,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => selectedTopic = v);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Difficulty Selection
                        Text(
                          'Difficulty Level',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark
                                ? AppTheme.darkSecondaryText
                                : AppTheme.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Any', 'Easy', 'Medium', 'Hard'].map((d) {
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
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 4),

                        // Starred Questions (Revision Mode)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: onlyStarred
                                  ? Colors.amber.shade100
                                  : (isDark
                                      ? AppTheme.darkBorder
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              onlyStarred
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: onlyStarred
                                  ? Colors.amber.shade800
                                  : AppTheme.secondaryText,
                              size: 18,
                            ),
                          ),
                          title: const Text(
                            'Starred Questions Only',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Target $_starredQuestionsCount starred question(s) in "${selectedExam?.name ?? 'Exam'}"',
                            style: const TextStyle(fontSize: 12),
                          ),
                          value: onlyStarred,
                          onChanged: (v) {
                            setState(() {
                              onlyStarred = v;
                              if (v) {
                                isAllQuestions = true;
                              }
                            });
                          },
                        ),
                        const Divider(height: 1),
                        // Shuffle Questions
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: shuffleQuestions
                                  ? AppTheme.accentBlue.withValues(alpha: 0.12)
                                  : (isDark
                                      ? AppTheme.darkBorder
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.shuffle_rounded,
                              color: shuffleQuestions
                                  ? AppTheme.accentBlue
                                  : AppTheme.secondaryText,
                              size: 18,
                            ),
                          ),
                          title: const Text(
                            'Shuffle Questions',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Randomize question sequence',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: shuffleQuestions,
                          onChanged: (v) =>
                              setState(() => shuffleQuestions = v),
                        ),
                        const Divider(height: 1),
                        // Shuffle Options
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: shuffleOptions
                                  ? const Color(0xFFEDE9FE)
                                  : (isDark
                                      ? AppTheme.darkBorder
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.alt_route_rounded,
                              color: shuffleOptions
                                  ? const Color(0xFF7C3AED)
                                  : AppTheme.secondaryText,
                              size: 18,
                            ),
                          ),
                          title: const Text(
                            'Shuffle Answer Options',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Randomize choice order (A/B/C/D) for each question',
                            style: TextStyle(fontSize: 12),
                          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
                    size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.accentBlue : null,
                    ),
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
