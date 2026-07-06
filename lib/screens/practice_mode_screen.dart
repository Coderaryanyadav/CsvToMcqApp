import 'package:flutter/material.dart';
import '../models/question.dart';

class PracticeModeScreen extends StatefulWidget {
  final List<Question> questions;
  const PracticeModeScreen({super.key, required this.questions});

  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen> {
  int current = 0;
  int? selectedAnswer;
  bool showResult = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[current];
    final isLast = current == widget.questions.length - 1;

    return Scaffold(
      appBar: AppBar(
        title:
            Text('Practice Mode - ${current + 1}/${widget.questions.length}'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Q${current + 1}',
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      q.question,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                    if (q.explanation != null && showResult) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lightbulb, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                q.explanation!,
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontSize: 14,
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
            const SizedBox(height: 16),
            ...List.generate(4, (i) {
              final isSelected = selectedAnswer == i;
              final isCorrect = i == q.correct;
              final showFeedback = showResult;

              Color? bgColor;
              Color? borderColor;
              IconData? icon;
              Color? iconColor;

              if (showFeedback) {
                if (isCorrect) {
                  bgColor = Colors.green.shade50;
                  borderColor = Colors.green;
                  icon = Icons.check_circle;
                  iconColor = Colors.green;
                } else if (isSelected && !isCorrect) {
                  bgColor = Colors.red.shade50;
                  borderColor = Colors.red;
                  icon = Icons.cancel;
                  iconColor = Colors.red;
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: showResult
                        ? null
                        : () {
                            setState(() {
                              selectedAnswer = i;
                              showResult = true;
                            });
                          },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bgColor ?? Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor ?? Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: iconColor),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              q.options[i],
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w600 : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: current > 0
                        ? () {
                            setState(() {
                              current--;
                              selectedAnswer = null;
                              showResult = false;
                            });
                          }
                        : null,
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: showResult
                        ? () {
                            if (!isLast) {
                              setState(() {
                                current++;
                                selectedAnswer = null;
                                showResult = false;
                              });
                            } else {
                              Navigator.pop(context);
                            }
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: Text(isLast ? 'Finish' : 'Next'),
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
