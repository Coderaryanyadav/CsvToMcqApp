import 'package:flutter_test/flutter_test.dart';
import 'package:csv_to_mcq_app/models/question.dart';
import 'package:csv_to_mcq_app/services/question_selection_service.dart';
import 'package:csv_to_mcq_app/services/import_service.dart';

void main() {
  group('Chapter & Topic Hierarchical Tagging & Filtering Tests', () {
    final questions = [
      Question(
        id: 'q1',
        question: 'Chapter 1 Topic A Q1',
        options: ['A', 'B', 'C', 'D'],
        correctAnswers: {0},
        chapter: 'Chapter 1',
        topic: 'Database Fundamentals',
        difficulty: 1,
      ),
      Question(
        id: 'q2',
        question: 'Chapter 1 Topic B Q2',
        options: ['A', 'B', 'C', 'D'],
        correctAnswers: {1},
        chapter: 'Chapter 1',
        topic: 'Indexing & Performance',
        difficulty: 3,
      ),
      Question(
        id: 'q3',
        question: 'Chapter 2 Topic C Q3',
        options: ['A', 'B', 'C', 'D'],
        correctAnswers: {2},
        chapter: 'Chapter 2',
        topic: 'Cloud Computing',
        difficulty: 5,
      ),
    ];

    test('discoverChapters returns sorted unique list of chapters', () {
      final chapters = QuestionSelectionService.discoverChapters(questions);
      expect(chapters, ['Chapter 1', 'Chapter 2']);
    });

    test('discoverTopics with selectedChapter filters topics dynamically', () {
      final ch1Topics = QuestionSelectionService.discoverTopics(
        questions,
        selectedChapter: 'Chapter 1',
      );
      expect(ch1Topics, ['Database Fundamentals', 'Indexing & Performance']);

      final ch2Topics = QuestionSelectionService.discoverTopics(
        questions,
        selectedChapter: 'Chapter 2',
      );
      expect(ch2Topics, ['Cloud Computing']);

      final allTopics = QuestionSelectionService.discoverTopics(
        questions,
        selectedChapter: 'All Chapters',
      );
      expect(allTopics, [
        'Cloud Computing',
        'Database Fundamentals',
        'Indexing & Performance'
      ]);
    });

    test('filterQuestions filters accurately by selectedChapter and topic', () {
      final filteredCh1 = QuestionSelectionService.filterQuestions(
        questions: questions,
        selectedChapter: 'Chapter 1',
      );
      expect(filteredCh1.length, 2);
      expect(filteredCh1.map((q) => q.id), containsAll(['q1', 'q2']));

      final filteredCh1TopicA = QuestionSelectionService.filterQuestions(
        questions: questions,
        selectedChapter: 'Chapter 1',
        selectedTopic: 'Database Fundamentals',
      );
      expect(filteredCh1TopicA.length, 1);
      expect(filteredCh1TopicA.first.id, 'q1');
    });

    test('ImportService parses Chapter column from CSV correctly', () {
      const csvContent =
          '''chapter,topic,question,option_a,option_b,option_c,option_d,correct_answer
"Chapter 1 - Algebra","Linear Equations","Solve x + 2 = 5","1","2","3","4","C"
"Chapter 2 - Geometry","Triangles","Sum of angles in a triangle?","90","180","270","360","B"''';

      final result = ImportService.parseCsv(csvContent, 'test.csv');
      expect(result.validCount, 2);
      expect(result.validQuestions[0].chapter, 'Chapter 1 - Algebra');
      expect(result.validQuestions[0].topic, 'Linear Equations');
      expect(result.validQuestions[1].chapter, 'Chapter 2 - Geometry');
      expect(result.validQuestions[1].topic, 'Triangles');
    });
  });
}
