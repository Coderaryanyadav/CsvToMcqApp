import 'package:flutter/material.dart';
import '../services/import_service.dart';

class ImportPreviewScreen extends StatelessWidget {
  final ImportResult importResult;

  const ImportPreviewScreen({super.key, required this.importResult});

  @override
  Widget build(BuildContext context) {
    final res = importResult;
    final hasCritical = res.criticalErrors.isNotEmpty || res.validQuestions.isEmpty;
    final theme = Theme.of(context);

    final idRange = res.validQuestions.isNotEmpty
        ? 'Q${res.startQuestionNumber} – Q${res.endQuestionNumber}'
        : 'None';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Preview'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Target Exam & File Summary Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.assignment_turned_in,
                            color: theme.colorScheme.primary, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                res.targetExamName.isNotEmpty
                                    ? res.targetExamName
                                    : 'New Exam',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'File: ${res.filename}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _DetailItem(
                          label: 'Questions Found',
                          value: '${res.validQuestions.length}',
                          color: theme.colorScheme.primary,
                        ),
                        _DetailItem(
                          label: 'Starting ID',
                          value: res.validQuestions.isNotEmpty
                              ? 'Q${res.startQuestionNumber}'
                              : '—',
                        ),
                        _DetailItem(
                          label: 'Ending ID',
                          value: res.validQuestions.isNotEmpty
                              ? 'Q${res.endQuestionNumber}'
                              : '—',
                        ),
                        _DetailItem(
                          label: 'ID Range',
                          value: idRange,
                          highlight: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Stat Badges
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Valid Questions',
                    count: res.validQuestions.length,
                    color: Colors.green,
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Warnings',
                    count: res.warnings.length,
                    color: Colors.orange,
                    icon: Icons.warning_amber_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Critical Errors',
                    count: res.criticalErrors.length,
                    color: Colors.red,
                    icon: Icons.error_outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Import Confirmation Message / Info Box
            if (!hasCritical)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${res.validQuestions.length} questions will be added to ${res.targetExamName.isNotEmpty ? res.targetExamName : "the exam"} ($idRange).',
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cancel_outlined, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        res.validQuestions.isEmpty && res.criticalErrors.isEmpty
                            ? 'No valid questions found in the selected file.'
                            : 'Please fix critical errors before importing.',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // Detailed validation section
            if (res.issues.isNotEmpty) ...[
              Text(
                'Validation Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: res.issues.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final issue = res.issues[index];
                  final isWarn = issue.isWarning;
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isWarn ? Colors.orange.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isWarn ? Colors.orange.shade200 : Colors.red.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isWarn
                                    ? Colors.orange.shade700
                                    : Colors.red.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Row ${issue.row}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                issue.problem,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isWarn
                                      ? Colors.orange.shade900
                                      : Colors.red.shade900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Suggested Fix: ${issue.suggestion}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isWarn
                                ? Colors.orange.shade800
                                : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ] else if (res.criticalErrors.isNotEmpty || res.warnings.isNotEmpty) ...[
              if (res.criticalErrors.isNotEmpty) ...[
                Text(
                  'Critical Errors',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...res.criticalErrors.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $e', style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
                    )),
                const SizedBox(height: 12),
              ],
              if (res.warnings.isNotEmpty) ...[
                Text(
                  'Warnings',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...res.warnings.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $e', style: TextStyle(color: Colors.orange.shade900, fontSize: 13)),
                    )),
                const SizedBox(height: 12),
              ],
            ],

            const SizedBox(height: 24),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: hasCritical
                        ? null
                        : () {
                            Navigator.pop(context, res.validQuestions);
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.download_done),
                    label: Text(
                      hasCritical
                          ? 'Resolve Errors to Import'
                          : 'Confirm Import (${res.validQuestions.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool highlight;

  const _DetailItem({
    required this.label,
    required this.value,
    this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

