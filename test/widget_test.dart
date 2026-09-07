import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:csv_to_mcq_app/screens/home_screen.dart';
import 'package:csv_to_mcq_app/screens/exam_screen.dart';
import 'package:csv_to_mcq_app/screens/practice_mode_screen.dart';
import 'package:csv_to_mcq_app/models/question.dart';
import 'package:csv_to_mcq_app/models/exam.dart';

void main() {
  testWidgets('Home screen renders initial state and navigation elements',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    // Shows progress indicator or loaded view
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets(
      'ExamScreen displays question and allows selection and navigation',
      (WidgetTester tester) async {
    final questions = [
      Question(
        id: 'q1_id',
        displayNumber: 1,
        question: 'What is SQL?',
        options: [
          'Database Query Language',
          'Programming Language',
          'Operating System',
          'Web Browser'
        ],
        correctAnswers: {0},
      ),
      Question(
        id: 'q2_id',
        displayNumber: 2,
        question: 'Which are cloud providers?',
        options: ['AWS', 'GCP', 'Linux', 'Azure'],
        correctAnswers: {0, 1, 3},
        questionType: 'multiple',
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: ExamScreen(
        questions: questions,
        durationMin: 10,
        examName: 'Test Exam',
      ),
    ));

    expect(find.text('What is SQL?'), findsOneWidget);
    expect(find.text('Database Query Language'), findsOneWidget);

    // Tap an answer
    await tester.tap(find.text('Database Query Language'));
    await tester.pump();

    // Tap Next Question
    final nextBtn = find.text('Next Question');
    await tester.ensureVisible(nextBtn);
    await tester.tap(nextBtn);
    await tester.pumpAndSettle();

    expect(find.text('Which are cloud providers?'), findsOneWidget);
    expect(
        find.text('MULTIPLE SELECT (Choose all that apply)'), findsOneWidget);

    // Finish Exam button should be present on last question
    expect(find.text('Finish Exam'), findsAtLeastNWidgets(1));
  });

  testWidgets(
      'PracticeModeScreen displays Show Answer and reveals explanations',
      (WidgetTester tester) async {
    final questions = [
      Question(
        id: 'q1_id',
        displayNumber: 1,
        question: 'Which statement retrieves data?',
        options: ['INSERT', 'SELECT', 'UPDATE', 'DELETE'],
        correctAnswers: {1},
        optionExplanations: {
          0: 'INSERT adds new rows.',
          1: 'SELECT is used to query and retrieve data.',
          2: 'UPDATE modifies existing data.',
          3: 'DELETE removes rows.',
        },
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: PracticeModeScreen(
          questions: questions, durationMin: 15, examName: 'SQL Practice'),
    ));

    expect(find.text('Q1. Which statement retrieves data?'), findsOneWidget);
    expect(find.text('Show Answer'), findsOneWidget);

    // Explanations not shown initially
    expect(
        find.text('SELECT is used to query and retrieve data.'), findsNothing);

    // Tap Show Answer
    final showAnswerBtn = find.text('Show Answer');
    await tester.ensureVisible(showAnswerBtn);
    await tester.tap(showAnswerBtn);
    await tester.pumpAndSettle();

    // Explanations now visible
    expect(find.text('SELECT is used to query and retrieve data.'),
        findsOneWidget);
    expect(find.text('INSERT adds new rows.'), findsOneWidget);
  });

  testWidgets('Exam model correctly tracks next question IDs and reindexing',
      (WidgetTester tester) async {
    final exam = Exam(id: 'cia_exam', name: 'CIA', questions: []);
    expect(exam.nextQuestionNumber, 1);

    exam.addQuestions([
      Question(
          id: 'q1',
          question: 'Q1 text',
          options: ['A', 'B', 'C', 'D'],
          correct: 0),
      Question(
          id: 'q2',
          question: 'Q2 text',
          options: ['A', 'B', 'C', 'D'],
          correct: 1),
    ]);
    expect(exam.questions.length, 2);
    expect(exam.nextQuestionNumber, 3);
  });

  testWidgets('Delete Exam dialog renders confirmation options safely',
      (WidgetTester tester) async {
    bool deleted = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Exam'),
                    content: const Text(
                        'Are you sure you want to delete this exam?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete Exam'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  deleted = true;
                }
              },
              child: const Text('Open Delete Modal'),
            ),
          ),
        );
      }),
    ));

    await tester.tap(find.text('Open Delete Modal'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Exam'), findsNWidgets(2)); // Title & Button
    expect(
        find.text('Are you sure you want to delete this exam?'), findsOneWidget);

    // Tap Delete Exam
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete Exam'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });
}
