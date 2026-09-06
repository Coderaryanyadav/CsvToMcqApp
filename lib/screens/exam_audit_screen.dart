import 'package:flutter/material.dart';

import '../models/exam.dart';
import '../services/storage_service.dart';
import '../utils/validators.dart';
import 'add_edit_exam_screen.dart';

enum AuditSeverity { critical, warning, suggestion }

class AuditFinding {
  final AuditSeverity severity;
  final String title;
  final String details;

  const AuditFinding({
    required this.severity,
    required this.title,
    required this.details,
  });
}

class ExamAuditResult {
  final String examId;
  final String examName;
  final int totalQuestions;
  final List<AuditFinding> findings;
  final Map<int, int> difficultySpread;
  final Map<String, int> topicSpread;
  final double readinessScore;

  const ExamAuditResult({
    required this.examId,
    required this.examName,
    required this.totalQuestions,
    required this.findings,
    required this.difficultySpread,
    required this.topicSpread,
    required this.readinessScore,
  });

  int get criticalCount =>
      findings.where((f) => f.severity == AuditSeverity.critical).length;
  int get warningCount =>
      findings.where((f) => f.severity == AuditSeverity.warning).length;
  int get suggestionCount =>
      findings.where((f) => f.severity == AuditSeverity.suggestion).length;
}

class ExamAuditScreen extends StatefulWidget {
  const ExamAuditScreen({super.key});

  @override
  State<ExamAuditScreen> createState() => _ExamAuditScreenState();
}

class _ExamAuditScreenState extends State<ExamAuditScreen> {
  bool _loading = true;
  String? _error;
  List<ExamAuditResult> _audits = [];

  @override
  void initState() {
    super.initState();
    _runAudit();
  }

  Future<void> _runAudit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await StorageService.init();
      final exams = await StorageService.loadAllExams();
      final List<ExamAuditResult> results = [];

      for (final exam in exams) {
        try {
          results.add(_performExamAudit(exam));
        } catch (e) {
          results.add(
            ExamAuditResult(
              examId: exam.id,
              examName: exam.name,
              totalQuestions: 0,
              findings: [
                AuditFinding(
                  severity: AuditSeverity.critical,
                  title: 'Corrupted Exam',
                  details: 'Failed to audit exam: $e',
                ),
              ],
              difficultySpread: const {},
              topicSpread: const {},
              readinessScore: 0.0,
            ),
          );
        }
      }

      results.sort((a, b) => b.readinessScore.compareTo(a.readinessScore));

      if (!mounted) return;
      setState(() {
        _audits = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  ExamAuditResult _performExamAudit(Exam exam) {
    final findings = <AuditFinding>[];
    final total = exam.questions.length;

    // Check Exam Metadata
    final examErrors = ExamValidator.validate(exam);
    for (final err in examErrors) {
      findings.add(
        AuditFinding(
          severity: AuditSeverity.critical,
          title: 'Exam Validation Issue',
          details: err,
        ),
      );
    }

    if (total == 0) {
      findings.add(
        const AuditFinding(
          severity: AuditSeverity.critical,
          title: 'No Questions',
          details:
              'This exam contains 0 questions. Add questions before publishing.',
        ),
      );
      return ExamAuditResult(
        examId: exam.id,
        examName: exam.name,
        totalQuestions: 0,
        findings: findings,
        difficultySpread: const {},
        topicSpread: const {},
        readinessScore: 0.0,
      );
    }

    // Question-level validation
    int invalidQuestions = 0;
    int missingExplanations = 0;
    int missingTopics = 0;
    int missingTags = 0;
    int veryLongContent = 0;

    final seenQuestions = <String, int>{};
    final difficultySpread = <int, int>{};
    final topicSpread = <String, int>{};

    for (var i = 0; i < exam.questions.length; i++) {
      final q = exam.questions[i];
      final qIndex = i + 1;

      // Critical Question Validator errors
      final qErrors = QuestionValidator.validate(q);
      if (qErrors.isNotEmpty) {
        invalidQuestions++;
        findings.add(
          AuditFinding(
            severity: AuditSeverity.critical,
            title: 'Q$qIndex Invalid',
            details: qErrors.join(', '),
          ),
        );
      }

      // Check Duplicates
      final norm =
          q.question.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
      if (norm.isNotEmpty) {
        if (seenQuestions.containsKey(norm)) {
          findings.add(
            AuditFinding(
              severity: AuditSeverity.critical,
              title: 'Duplicate Question',
              details:
                  'Q$qIndex duplicates Q${seenQuestions[norm]}: "${q.question.length > 50 ? '${q.question.substring(0, 50)}...' : q.question}"',
            ),
          );
        } else {
          seenQuestions[norm] = qIndex;
        }
      }

      // Warnings
      if (q.explanation == null || q.explanation!.trim().isEmpty) {
        missingExplanations++;
      }
      if (q.topic == null || q.topic!.trim().isEmpty) {
        missingTopics++;
      } else {
        topicSpread[q.topic!.trim()] = (topicSpread[q.topic!.trim()] ?? 0) + 1;
      }
      if (q.tags.isEmpty) {
        missingTags++;
      }
      if (q.question.length > 500) {
        veryLongContent++;
      }

      // Difficulty spread
      difficultySpread[q.difficulty] =
          (difficultySpread[q.difficulty] ?? 0) + 1;
    }

    if (missingExplanations > 0) {
      findings.add(
        AuditFinding(
          severity: AuditSeverity.warning,
          title: 'Missing Explanations ($missingExplanations/$total)',
          details:
              'Explanations significantly boost student comprehension and learning.',
        ),
      );
    }
    if (missingTopics > 0) {
      findings.add(
        AuditFinding(
          severity: AuditSeverity.warning,
          title: 'Missing Topics ($missingTopics/$total)',
          details:
              'Assign topics to allow category-based filtering and weak-area analytics.',
        ),
      );
    }
    if (missingTags > 0) {
      findings.add(
        AuditFinding(
          severity: AuditSeverity.warning,
          title: 'Uncategorized Tags ($missingTags/$total)',
          details: 'Tags help cross-cutting search and practice modes.',
        ),
      );
    }
    if (veryLongContent > 0) {
      findings.add(
        AuditFinding(
          severity: AuditSeverity.warning,
          title: 'Very Long Questions ($veryLongContent)',
          details:
              'Some questions exceed 500 characters. Check readability on mobile screens.',
        ),
      );
    }

    // Suggestions
    if (difficultySpread.keys.length < 2 && total >= 10) {
      findings.add(
        const AuditFinding(
          severity: AuditSeverity.suggestion,
          title: 'Difficulty Diversity',
          details:
              'Consider varying difficulty levels (Easy, Medium, Hard) for better assessment balance.',
        ),
      );
    }
    if (topicSpread.keys.length < 2 && total >= 10) {
      findings.add(
        const AuditFinding(
          severity: AuditSeverity.suggestion,
          title: 'Topic Diversity',
          details:
              'All questions belong to a single topic. Adding more topics helps granular learning tracking.',
        ),
      );
    }

    // Calculate readiness score
    double score = 1.0;
    if (invalidQuestions > 0) {
      score -= (invalidQuestions / total) * 0.5;
    }
    if (seenQuestions.length < total) {
      final duplicatesCount = total - seenQuestions.length;
      score -= (duplicatesCount / total) * 0.3;
    }
    if (missingExplanations > 0) {
      score -= (missingExplanations / total) * 0.15;
    }
    if (missingTopics > 0) {
      score -= (missingTopics / total) * 0.1;
    }
    if (examErrors.isNotEmpty) {
      score -= 0.3;
    }

    final finalScore = (score.clamp(0.0, 1.0) * 100).roundToDouble() / 100.0;

    return ExamAuditResult(
      examId: exam.id,
      examName: exam.name,
      totalQuestions: total,
      findings: findings,
      difficultySpread: difficultySpread,
      topicSpread: topicSpread,
      readinessScore: finalScore,
    );
  }

  Future<void> _openEditor(String examId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditExamScreen(examId: examId),
      ),
    );
    if (!mounted) return;
    await _runAudit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Quality Audit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rerun Audit',
            onPressed: _runAudit,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _runAudit,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 48, color: colorScheme.error),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colorScheme.error),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            onPressed: _runAudit,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _audits.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.fact_check_outlined,
                                size: 56,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No exams to audit',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Import or create an exam to run quality and readiness checks.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _audits.length,
                        itemBuilder: (context, index) {
                          final audit = _audits[index];
                          return _ExamAuditCard(
                            audit: audit,
                            onFix: () => _openEditor(audit.examId),
                          );
                        },
                      ),
      ),
    );
  }
}

class _ExamAuditCard extends StatelessWidget {
  final ExamAuditResult audit;
  final VoidCallback onFix;

  const _ExamAuditCard({
    required this.audit,
    required this.onFix,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final readinessPercent = (audit.readinessScore * 100).toInt();

    Color readinessColor = Colors.green;
    if (readinessPercent < 50) {
      readinessColor = Colors.red;
    } else if (readinessPercent < 80) {
      readinessColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        audit.examName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${audit.totalQuestions} questions',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onFix,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Edit / Fix'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: audit.readinessScore,
                      minHeight: 8,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(readinessColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$readinessPercent% Ready',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: readinessColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (audit.criticalCount > 0)
                  _BadgeChip(
                    label: '${audit.criticalCount} Critical',
                    icon: Icons.error_rounded,
                    color: Colors.red,
                  ),
                if (audit.warningCount > 0)
                  _BadgeChip(
                    label: '${audit.warningCount} Warnings',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.amber.shade800,
                  ),
                if (audit.suggestionCount > 0)
                  _BadgeChip(
                    label: '${audit.suggestionCount} Suggestions',
                    icon: Icons.lightbulb_outline_rounded,
                    color: Colors.blue,
                  ),
                if (audit.findings.isEmpty)
                  const _BadgeChip(
                    label: 'Clean — Ready for Students',
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.green,
                  ),
              ],
            ),
            if (audit.findings.isNotEmpty) ...[
              const Divider(height: 24),
              ...audit.findings.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        f.severity == AuditSeverity.critical
                            ? Icons.cancel_rounded
                            : f.severity == AuditSeverity.warning
                                ? Icons.warning_rounded
                                : Icons.info_outline_rounded,
                        size: 16,
                        color: f.severity == AuditSeverity.critical
                            ? Colors.red
                            : f.severity == AuditSeverity.warning
                                ? Colors.amber.shade800
                                : Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface,
                            ),
                            children: [
                              TextSpan(
                                text: '${f.title}: ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: f.details),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (audit.difficultySpread.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Difficulty Distribution',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: audit.difficultySpread.entries.map((entry) {
                  final label = entry.key == 1
                      ? 'Easy'
                      : entry.key == 2
                          ? 'Medium'
                          : entry.key == 3
                              ? 'Hard'
                              : 'Level ${entry.key}';
                  return Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('$label: ${entry.value}'),
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _BadgeChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
