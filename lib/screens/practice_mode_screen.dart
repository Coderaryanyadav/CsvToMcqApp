import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';

class PracticeModeScreen extends StatefulWidget {
  final List<Question> questions;
  final int durationMin;
  final String? examName;

  const PracticeModeScreen({
    super.key,
    required this.questions,
    this.durationMin = 30,
    this.examName,
  });

  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen> {
  int current = 0;
  final Map<int, Set<int>> _answers = {};
  final Map<int, bool> _revealed = {};
  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.durationMin * 60;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTimer(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _toggleOption(int index, bool isMultiple) {
    if (_revealed[current] == true) return;
    HapticFeedback.lightImpact();
    setState(() {
      final currentSet = _answers[current] ?? <int>{};
      if (isMultiple) {
        if (currentSet.contains(index)) {
          currentSet.remove(index);
        } else {
          currentSet.add(index);
        }
        _answers[current] = currentSet;
      } else {
        _answers[current] = {index};
      }
    });
  }

  void _navigateToQuestion(int index) {
    if (index >= 0 && index < widget.questions.length) {
      setState(() {
        current = index;
      });
      HapticFeedback.selectionClick();
    }
  }

  void _showQuestionNavigatorModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Practice Navigator',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.text,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildLegendItem(AppTheme.primaryNavy, Colors.white, 'Current'),
                        _buildLegendItem(const Color(0xFFDCFCE7), AppTheme.success, 'Correct'),
                        _buildLegendItem(const Color(0xFFFEE2E2), AppTheme.danger, 'Incorrect'),
                        _buildLegendItem(const Color(0xFFDBEAFE), AppTheme.primaryNavy, 'Answered'),
                        _buildLegendItem(Colors.white, AppTheme.secondaryText, 'Unanswered', isBordered: true),
                      ],
                    ),
                    const Divider(height: 24),
                    Expanded(
                      child: GridView.builder(
                        itemCount: widget.questions.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.2,
                        ),
                        itemBuilder: (_, i) {
                          final q = widget.questions[i];
                          final isCur = i == current;
                          final isRev = _revealed[i] == true;
                          final userAns = _answers[i] ?? <int>{};
                          final isAns = userAns.isNotEmpty;
                          final isCorrect = q.isAnswerCorrect(userAns);

                          Color bg = Colors.white;
                          Color fg = AppTheme.text;
                          Border? border = Border.all(color: AppTheme.border);

                          if (isCur) {
                            bg = AppTheme.primaryNavy;
                            fg = Colors.white;
                            border = null;
                          } else if (isRev) {
                            if (isCorrect) {
                              bg = const Color(0xFFDCFCE7);
                              fg = AppTheme.success;
                              border = Border.all(color: const Color(0xFF86EFAC));
                            } else {
                              bg = const Color(0xFFFEE2E2);
                              fg = AppTheme.danger;
                              border = Border.all(color: const Color(0xFFFCA5A5));
                            }
                          } else if (isAns) {
                            bg = const Color(0xFFDBEAFE);
                            fg = AppTheme.primaryNavy;
                            border = Border.all(color: const Color(0xFF93C5FD));
                          }

                          return InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              _navigateToQuestion(i);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(8),
                                border: border,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: fg,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegendItem(Color bg, Color fg, String label, {bool isBordered = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: isBordered ? Border.all(color: AppTheme.border) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.secondaryText, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice Mode')),
        body: const Center(child: Text('No questions available in this session.')),
      );
    }

    final q = widget.questions[current];
    final isLast = current == widget.questions.length - 1;
    final isMultiple = q.isMultiple;
    final isRevealed = _revealed[current] == true;
    final selected = _answers[current] ?? <int>{};
    final questionsLeft = widget.questions.length - current - 1;
    final progress = (current + 1) / widget.questions.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(widget.examName != null ? '${widget.examName} — Practice' : 'Practice Mode'),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryNavy,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        q.id,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF2FA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 15, color: AppTheme.primaryNavy),
                          const SizedBox(width: 6),
                          Text(
                            _formatTimer(_remainingSeconds),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$questionsLeft Left',
                      style: const TextStyle(
                        color: AppTheme.secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Practice',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: AppTheme.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isMultiple
                                          ? const Color(0xFFF3E8FF)
                                          : const Color(0xFFDBEAFE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isMultiple ? 'MULTIPLE SELECT' : 'SINGLE SELECT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isMultiple
                                            ? const Color(0xFF6B21A8)
                                            : AppTheme.accentBlue,
                                      ),
                                    ),
                                  ),
                                  if (q.topic != null && q.topic!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        q.topic!,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.secondaryText,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(
                                    'Question ${current + 1} of ${widget.questions.length}',
                                    style: const TextStyle(
                                      color: AppTheme.secondaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              if (isMultiple) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Select all that apply.',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: AppTheme.accentBlue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Text(
                                '${q.id}. ${q.question}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.text,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(q.options.length, (i) {
                        final isOptionSelected = selected.contains(i);
                        final isOptionCorrect = q.correctAnswers.contains(i);
                        final exp = q.getExplanation(i);

                        Color cardBg = Colors.white;
                        Color borderColor = AppTheme.border;
                        Widget? statusIcon;

                        if (isRevealed) {
                          if (isOptionCorrect) {
                            cardBg = const Color(0xFFF0FDF4);
                            borderColor = const Color(0xFF86EFAC);
                            statusIcon = const Icon(Icons.check_circle, color: AppTheme.success, size: 20);
                          } else if (isOptionSelected && !isOptionCorrect) {
                            cardBg = const Color(0xFFFEF2F2);
                            borderColor = const Color(0xFFFCA5A5);
                            statusIcon = const Icon(Icons.cancel, color: AppTheme.danger, size: 20);
                          } else {
                            cardBg = const Color(0xFFF9FAFB);
                            borderColor = const Color(0xFFE5E7EB);
                            statusIcon = const Icon(Icons.remove_circle_outline, color: Color(0xFF9CA3AF), size: 20);
                          }
                        } else if (isOptionSelected) {
                          cardBg = const Color(0xFFEBF2FA);
                          borderColor = AppTheme.accentBlue;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isRevealed ? null : () => _toggleOption(i, isMultiple),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: borderColor,
                                    width: isOptionSelected || (isRevealed && isOptionCorrect) ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (!isRevealed) ...[
                                          if (isMultiple)
                                            Icon(
                                              isOptionSelected
                                                  ? Icons.check_box
                                                  : Icons.check_box_outline_blank,
                                              color: isOptionSelected
                                                  ? AppTheme.accentBlue
                                                  : AppTheme.secondaryText,
                                              size: 22,
                                            )
                                          else
                                            Icon(
                                              isOptionSelected
                                                  ? Icons.radio_button_checked
                                                  : Icons.radio_button_unchecked,
                                              color: isOptionSelected
                                                  ? AppTheme.accentBlue
                                                  : AppTheme.secondaryText,
                                              size: 22,
                                            ),
                                          const SizedBox(width: 12),
                                        ] else if (statusIcon != null) ...[
                                          statusIcon,
                                          const SizedBox(width: 12),
                                        ],
                                        Text(
                                          '${String.fromCharCode(65 + i)} — ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isOptionSelected
                                                ? AppTheme.accentBlue
                                                : AppTheme.text,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            q.options[i],
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: isOptionSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              color: AppTheme.text,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isRevealed) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isOptionCorrect
                                              ? const Color(0xFFDCFCE7)
                                              : const Color(0xFFFEE2E2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isOptionCorrect ? '✅ Correct: ' : '❌ Incorrect: ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: isOptionCorrect
                                                    ? const Color(0xFF14532D)
                                                    : const Color(0xFF7F1D1D),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                exp != null && exp.isNotEmpty
                                                    ? exp
                                                    : (isOptionCorrect
                                                        ? 'This is a correct answer for this question.'
                                                        : 'This option is incorrect.'),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isOptionCorrect
                                                      ? const Color(0xFF14532D)
                                                      : const Color(0xFF7F1D1D),
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
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Center(
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFEBF2FA),
                            foregroundColor: AppTheme.primaryNavy,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(isRevealed ? Icons.visibility_off : Icons.lightbulb_outline, size: 18),
                          label: Text(
                            isRevealed ? 'Hide Explanations' : 'Show Answer',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: () {
                            setState(() {
                              _revealed[current] = !isRevealed;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Previous'),
                          onPressed: current > 0
                              ? () => _navigateToQuestion(current - 1)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.grid_view, size: 18),
                        label: const Text('Navigator'),
                        onPressed: _showQuestionNavigatorModal,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isLast ? AppTheme.accentBlue : AppTheme.primaryNavy,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: Icon(isLast ? Icons.check : Icons.arrow_forward, size: 18),
                          label: Text(isLast ? 'Finish Practice' : 'Next'),
                          onPressed: () {
                            if (isLast) {
                              Navigator.pop(context);
                            } else {
                              _navigateToQuestion(current + 1);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
