import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:csv_to_mcq_app/screens/home_screen.dart';
import 'package:csv_to_mcq_app/screens/exam_screen.dart';
import 'package:csv_to_mcq_app/models/question.dart';

void main() {
  testWidgets('Home screen shows loading initially', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ExamScreen allows answering and navigating', (WidgetTester tester) async {
    final questions = [
      Question(id: '1', question: 'Question 1 text', options: ['A', 'B', 'C', 'D'], correct: 0),
      Question(id: '2', question: 'Question 2 text', options: ['W', 'X', 'Y', 'Z'], correct: 1),
    ];
    
    await tester.pumpWidget(MaterialApp(
      home: ExamScreen(questions: questions, durationMin: 10),
    ));

    expect(find.text('Question 1 text'), findsOneWidget);
    
    // Tap an answer
    await tester.tap(find.text('A'));
    await tester.pump();
    
    // Tap Next
    final nextBtn = find.text('Next');
    await tester.ensureVisible(nextBtn);
    await tester.tap(nextBtn);
    await tester.pumpAndSettle();
    
    expect(find.text('Question 2 text'), findsOneWidget);
    
    // Finish Exam button should be present on last question
    expect(find.text('Finish'), findsOneWidget);
  });
}
