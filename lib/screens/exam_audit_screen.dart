import 'dart:io';

import 'package:flutter/material.dart';

import '../models/exam.dart';
import '../models/question.dart';
import '../services/storage_service.dart';
import 'add_edit_exam_screen.dart';

class ExamAuditScreen extends StatefulWidget {
  const ExamAuditScreen({super.key});

  @override
  State<ExamAuditScreen> createState() => _ExamAuditScreenState();
}

class _ExamAuditScreenState extends State<ExamAuditScreen> {
  bool loading = true;
  String? error;
  List<_ExamAuditResult> audits = [];

  @override
  void initState() {
    super.initState();
    _runAudit();
  }

  Future<void> _runAudit() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await StorageService.init();
      final files = StorageService.listExamFiles();
      final List<_ExamAuditResult> results = [];
      for (final entity in files) {
        final filename = entity.path.split(Platform.pathSeparator).last;
        try {
          final json = await StorageService.readExamFile(filename);
          final exam = Exam.fromJson(json);
          results.add(_auditExam(exam));
        } catch (e) {
          results.add(
            _ExamAuditResult.error(
              filename.replaceAll('.json', ''),
              'Failed to audit: $e',
            ),
          );
        }
      }
      results.sort(
        (a, b) => b.completenessScore.compareTo(a.completenessScore),
      );
      if (!mounted) return;
      setState(() {
        audits = results;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  _ExamAuditResult _auditExam(Exam exam) {
    final total = exam.questions.length;
    if (total == 0) {
      return _ExamAuditResult(
        examId: exam.id,
        examName: exam.name,
        totalQuestions: 0,
        missingExplanations: 0,
        missingTopics: 0,
        missingTags: 0,
        duplicateQuestions: const [],
        difficultyBuckets: const {},
        actionItems: const ['Add questions to this exam.'],
        completenessScore: 0,
      );
    }

    final missingExp = exam.questions
        .where((q) => q.explanation == null || q.explanation!.trim().isEmpty)
        .length;
    final missingTopics =
        exam.questions.where((q) => q.topic == null || q.topic!.trim().isEmpty).length;
    final missingTags =
        exam.questions.where((q) => q.tags.isEmpty).length;

    final duplicates = <String>[];
    final seen = <String, Question>{};
    for (final q in exam.questions) {
      final norm = q.question.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
      if (norm.isEmpty) continue;
      if (seen.containsKey(norm)) {
        duplicates.add(q.question);
      } else {
        seen[norm] = q;
      }
    }

    final difficultyBuckets = <int, int>{};
    for (var i = 1; i <= 5; i++) {
      difficultyBuckets[i] = exam.questions.where((q) => q.difficulty == i).length;
    }

    final issues = <String>[];
    if (missingExp > 0) {
      issues.add('$missingExp missing explanations');
    }
    if (missingTopics > 0) {
      issues.add('$missingTopics missing topics');
    }
    if (missingTags > 0) {
      issues.add('$missingTags uncategorized questions');
    }
    if (duplicates.isNotEmpty) {
      issues.add('${duplicates.length} duplicate question(s)');
    }

    final completenessPenalty = (missingExp + missingTopics + missingTags) / (total * 3);
    final completenessScore = (1 - completenessPenalty).clamp(0.0, 1.0);

    if (issues.isEmpty) {
      issues.add('All checks passed.');
    }

    return _ExamAuditResult(
      examId: exam.id,
      examName: exam.name,
      totalQuestions: total,
      missingExplanations: missingExp,
      missingTopics: missingTopics,
      missingTags: missingTags,
      duplicateQuestions: duplicates,
      difficultyBuckets: difficultyBuckets,
      actionItems: issues,
      completenessScore: double.parse(completenessScore.toStringAsFixed(2)),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Audit'),
        backgroundColor: Colors.deepPurple,
      ),
      body: RefreshIndicator(
        onRefresh: _runAudit,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            error!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ),
                    ],
                  )
                : audits.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(Icons.fact_check_outlined,
                                      size: 48, color: Colors.deepPurple.shade200),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No exams found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Upload or create an exam first to run the audit.',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: audits.length,
                        itemBuilder: (context, index) {
                          final audit = audits[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              audit.examName,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${audit.totalQuestions} questions',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: audit.totalQuestions == 0
                                            ? null
                                            : () => _openEditor(audit.examId),
                                        icon: const Icon(Icons.build_outlined, size: 18),
                                        label: const Text('Fix'),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  LinearProgressIndicator(
                                    value: audit.completenessScore,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      audit.completenessScore > 0.8
                                          ? Colors.green
                                          : audit.completenessScore > 0.5
                                              ? Colors.orange
                                              : Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Readiness ${(audit.completenessScore * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(color: Colors.grey.shade700),
                                  ),
                                  const Divider(height: 24),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: audit.actionItems
                                        .map(
                                          (item) => Chip(
                                            label: Text(item),
                                            backgroundColor: item == 'All checks passed.'
                                                ? Colors.green.shade50
                                                : Colors.orange.shade50,
                                            labelStyle: TextStyle(
                                              color: item == 'All checks passed.'
                                                  ? Colors.green.shade700
                                                  : Colors.orange.shade700,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                  if (audit.difficultyBuckets.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      'Difficulty spread',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      children: audit.difficultyBuckets.entries
                                          .map(
                                            (entry) => Chip(
                                              avatar: CircleAvatar(
                                                backgroundColor: Colors.deepPurple.shade100,
                                                child: Text(
                                                  entry.key.toString(),
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                              label: Text('${entry.value}'),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                  if (audit.duplicateQuestions.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      'Duplicates detected',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...audit.duplicateQuestions.take(3).map(
                                          (q) => Text(
                                            '• $q',
                                            style: TextStyle(color: Colors.red.shade600),
                                          ),
                                        ),
                                    if (audit.duplicateQuestions.length > 3)
                                      Text(
                                        '+ ${audit.duplicateQuestions.length - 3} more',
                                        style: TextStyle(color: Colors.red.shade600),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _ExamAuditResult {
  final String examId;
  final String examName;
  final int totalQuestions;
  final int missingExplanations;
  final int missingTopics;
  final int missingTags;
  final List<String> duplicateQuestions;
  final Map<int, int> difficultyBuckets;
  final List<String> actionItems;
  final double completenessScore;

  const _ExamAuditResult({
    required this.examId,
    required this.examName,
    required this.totalQuestions,
    required this.missingExplanations,
    required this.missingTopics,
    required this.missingTags,
    required this.duplicateQuestions,
    required this.difficultyBuckets,
    required this.actionItems,
    required this.completenessScore,
  });

  factory _ExamAuditResult.error(String examId, String message) {
    return _ExamAuditResult(
      examId: examId,
      examName: examId,
      totalQuestions: 0,
      missingExplanations: 0,
      missingTopics: 0,
      missingTags: 0,
      duplicateQuestions: const [],
      difficultyBuckets: const {},
      actionItems: [message],
      completenessScore: 0,
    );
  }
}

