import 'package:flutter/material.dart';
import '../models/question.dart';
import 'practice_mode_screen.dart';

class ResultScreen extends StatelessWidget {
  final List<Question> questions;
  final Map<String, int?> answers;
  final Map<String, int>? timePerQuestion;
  
  const ResultScreen({
    super.key,
    required this.questions,
    required this.answers,
    this.timePerQuestion,
  });

  @override
  Widget build(BuildContext context) {
    int correct = 0;
    int incorrect = 0;
    int skipped = 0;
    
    final List<Question> mistakes = [];

    for (var q in questions) {
      final a = answers[q.id];
      if (a == null) {
        skipped++;
      } else if (a == q.correct) {
        correct++;
      } else {
        incorrect++;
        mistakes.add(q);
      }
    }

    final double accuracy = questions.isEmpty ? 0 : (correct / questions.length) * 100;
    final int totalTime = timePerQuestion?.values.fold(0, (sum, t) => sum! + t) ?? 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Exam Results'),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple.shade300, Colors.deepPurple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          accuracy >= 80 ? 'Great job!' : 'Keep practicing!',
                          style: const TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${accuracy.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$correct / ${questions.length} correct',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatBadge('Correct', correct, Colors.green),
                            _buildStatBadge('Wrong', incorrect, Colors.red),
                            _buildStatBadge('Skipped', skipped, Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Time: ${totalTime ~/ 60}m ${totalTime % 60}s',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepPurple,
                        ),
                        icon: const Icon(Icons.home),
                        label: const Text('Back Home'),
                        onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                      ),
                    ),
                    if (mistakes.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.refresh),
                          label: Text('Practice ${mistakes.length} Mistakes'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PracticeModeScreen(questions: mistakes),
                              ),
                            );
                          },
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: ListView.builder(
                    itemCount: questions.length,
                    itemBuilder: (context, i) {
                      final q = questions[i];
                      final a = answers[q.id];
                      final isCorrect = a != null && a == q.correct;
                      final isUnanswered = a == null;
                      
                      final borderColor = isCorrect ? Colors.green : (isUnanswered ? Colors.orange : Colors.red);
                      final bgColor = isCorrect ? Colors.green.shade50 : (isUnanswered ? Colors.orange.shade50 : Colors.red.shade50);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: borderColor, width: 2),
                        ),
                        color: bgColor,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isCorrect ? Icons.check_circle : (isUnanswered ? Icons.help_outline : Icons.cancel),
                                    color: borderColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      q.question,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              if (!isUnanswered) ...[
                                Text(
                                  'Your answer: ${q.options[a]}',
                                  style: TextStyle(
                                    color: isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              
                              if (!isCorrect)
                                Text(
                                  'Correct answer: ${q.options[q.correct]}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                
                              if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: borderColor.withAlpha(76)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.lightbulb, color: borderColor, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          q.explanation!,
                                          style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              
                              if (timePerQuestion != null && timePerQuestion![q.id] != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Time spent: ${timePerQuestion![q.id]}s',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(127)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(229),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
