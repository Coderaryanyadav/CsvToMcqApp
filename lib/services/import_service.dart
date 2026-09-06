import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../models/question.dart';
import '../models/exam.dart';
import 'storage_service.dart';

class ImportErrorDetail {
  final int row;
  final String problem;
  final String suggestion;
  final bool isWarning;

  ImportErrorDetail({
    required this.row,
    required this.problem,
    required this.suggestion,
    this.isWarning = false,
  });

  @override
  String toString() => 'Row $row: $problem (Fix: $suggestion)';
}

class ImportResult {
  final List<Question> validQuestions;
  final List<ImportErrorDetail> issues;
  final List<String> criticalErrors;
  final List<String> warnings;
  final List<String> suggestions;
  final String filename;
  final String targetExamName;
  final int startQuestionNumber;
  final int endQuestionNumber;

  ImportResult({
    required this.validQuestions,
    required this.filename,
    this.targetExamName = '',
    this.startQuestionNumber = 1,
    this.endQuestionNumber = 1,
    this.issues = const [],
    this.criticalErrors = const [],
    this.warnings = const [],
    this.suggestions = const [],
  });

  int get validCount => validQuestions.length;
}

class ImportService {
  static Future<ImportResult?> pickAndPreviewFile({
    Exam? targetExam,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes = file.bytes ?? File(file.path!).readAsBytesSync();
    final filename = file.name;

    final existingQuestions = targetExam?.questions
            .map((q) => q.question.trim().toLowerCase())
            .toSet() ??
        <String>{};
    final startId = (targetExam?.questions.length ?? 0) + 1;
    final examName = targetExam?.name ?? '';

    if (filename.toLowerCase().endsWith('.csv')) {
      final text = String.fromCharCodes(bytes);
      return parseCsv(
        text,
        filename,
        startQuestionNumber: startId,
        existingQuestions: existingQuestions,
        targetExamName: examName,
      );
    } else {
      return parseExcel(
        bytes,
        filename,
        startQuestionNumber: startId,
        existingQuestions: existingQuestions,
        targetExamName: examName,
      );
    }
  }

  static ImportResult parseCsv(
    String text,
    String filename, {
    int startQuestionNumber = 1,
    Set<String>? existingQuestions,
    String targetExamName = '',
  }) {
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    List<List<dynamic>> rows =
        const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
            .convert(text);
    return processRows(
      rows,
      filename,
      startQuestionNumber: startQuestionNumber,
      existingQuestions: existingQuestions,
      targetExamName: targetExamName,
    );
  }

  static ImportResult parseExcel(
    List<int> bytes,
    String filename, {
    int startQuestionNumber = 1,
    Set<String>? existingQuestions,
    String targetExamName = '',
  }) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return ImportResult(
        validQuestions: [],
        filename: filename,
        targetExamName: targetExamName,
        criticalErrors: ['Excel file has no sheets or is invalid.'],
      );
    }
    final sheet = excel.tables[excel.tables.keys.first]!;
    final List<List<dynamic>> rows = [];
    for (var r in sheet.rows) {
      rows.add(r.map((e) => e?.value?.toString() ?? '').toList());
    }
    return processRows(
      rows,
      filename,
      startQuestionNumber: startQuestionNumber,
      existingQuestions: existingQuestions,
      targetExamName: targetExamName,
    );
  }

  static ImportResult processRows(
    List<List<dynamic>> rows,
    String filename, {
    int startQuestionNumber = 1,
    Set<String>? existingQuestions,
    String targetExamName = '',
  }) {
    final List<Question> validQuestions = [];
    final List<ImportErrorDetail> issues = [];
    final List<String> criticalErrors = [];
    final List<String> warnings = [];
    final List<String> suggestions = [];

    if (rows.isEmpty) {
      criticalErrors.add('File is completely empty.');
      return ImportResult(
        validQuestions: [],
        filename: filename,
        targetExamName: targetExamName,
        criticalErrors: criticalErrors,
      );
    }

    // 1. Identify Headers
    Map<String, int> columnMap = {};
    int startRow = 0;
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isEmpty) continue;
      bool foundQuestion = false;
      bool foundOption = false;
      for (int c = 0; c < rows[i].length; c++) {
        final val = rows[i][c].toString().trim().toLowerCase();
        if (val.isEmpty) continue;

        if (val == 'question_text' || val.contains('question') || val == 'q') {
          columnMap['question'] = c;
          foundQuestion = true;
        } else if (val == 'question_type' || val == 'type') {
          columnMap['question_type'] = c;
        } else if (val == 'option_a' ||
            val == 'option 1' ||
            val == 'a' ||
            val.contains('option a')) {
          columnMap['option_a'] = c;
          foundOption = true;
        } else if (val == 'option_b' ||
            val == 'option 2' ||
            val == 'b' ||
            val.contains('option b')) {
          columnMap['option_b'] = c;
          foundOption = true;
        } else if (val == 'option_c' ||
            val == 'option 3' ||
            val == 'c' ||
            val.contains('option c')) {
          columnMap['option_c'] = c;
          foundOption = true;
        } else if (val == 'option_d' ||
            val == 'option 4' ||
            val == 'd' ||
            val.contains('option d')) {
          columnMap['option_d'] = c;
          foundOption = true;
        } else if (val == 'correct_answer' ||
            val.contains('correct') ||
            val.contains('answer')) {
          columnMap['correct'] = c;
        } else if (val == 'explanation_a' ||
            val == 'explanation a' ||
            val == 'exp_a') {
          columnMap['explanation_a'] = c;
        } else if (val == 'explanation_b' ||
            val == 'explanation b' ||
            val == 'exp_b') {
          columnMap['explanation_b'] = c;
        } else if (val == 'explanation_c' ||
            val == 'explanation c' ||
            val == 'exp_c') {
          columnMap['explanation_c'] = c;
        } else if (val == 'explanation_d' ||
            val == 'explanation d' ||
            val == 'exp_d') {
          columnMap['explanation_d'] = c;
        } else if (val.contains('explanation')) {
          columnMap['explanation'] = c;
        } else if (val.contains('topic')) {
          columnMap['topic'] = c;
        } else if (val.contains('difficulty')) {
          columnMap['difficulty'] = c;
        } else if (val.contains('tag')) {
          columnMap['tags'] = c;
        }
      }

      if (foundQuestion && foundOption) {
        startRow = i + 1;
        break;
      }
    }

    if (columnMap.isEmpty) {
      columnMap = {
        'question': 0,
        'option_a': 1,
        'option_b': 2,
        'option_c': 3,
        'option_d': 4,
        'correct': 5,
        'explanation': 6,
        'topic': 7,
        'difficulty': 8,
        'tags': 9,
      };
      startRow = 0;
    }

    final Set<String> seenInThisFile = {};
    final Set<String> existingInTarget = existingQuestions ?? {};

    // 2. Process Data Rows
    for (int i = startRow; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty || r.every((element) => element.toString().trim().isEmpty)) {
        continue;
      }

      final rowNum = i + 1;

      String getCol(String key) {
        final idx = columnMap[key];
        if (idx == null || idx >= r.length) return '';
        return r[idx].toString().trim();
      }

      final qText = getCol('question');
      final qTypeRaw = getCol('question_type').toLowerCase();
      final oA = getCol('option_a');
      final oB = getCol('option_b');
      final oC = getCol('option_c');
      final oD = getCol('option_d');
      final correctRaw = getCol('correct');
      final expA = getCol('explanation_a');
      final expB = getCol('explanation_b');
      final expC = getCol('explanation_c');
      final expD = getCol('explanation_d');
      final genericExp = getCol('explanation');
      final topic = getCol('topic');
      final difficultyRaw = getCol('difficulty');
      final tagsRaw = getCol('tags');

      if (qText.isEmpty && oA.isEmpty && oB.isEmpty && oC.isEmpty && oD.isEmpty) {
        continue;
      }

      if (qText.isEmpty) {
        final err = 'Row $rowNum: Missing question text.';
        criticalErrors.add(err);
        issues.add(ImportErrorDetail(
          row: rowNum,
          problem: 'Missing question text',
          suggestion: 'Provide question text in question column',
        ));
        continue;
      }

      final normQ = qText.toLowerCase();
      if (seenInThisFile.contains(normQ)) {
        final err = 'Row $rowNum: Duplicate question detected in file ("$qText").';
        criticalErrors.add(err);
        issues.add(ImportErrorDetail(
          row: rowNum,
          problem: 'Duplicate question within CSV file',
          suggestion: 'Remove or rename duplicate question',
        ));
        continue;
      }
      seenInThisFile.add(normQ);

      if (existingInTarget.contains(normQ)) {
        final warn =
            'Row $rowNum: Question already exists in target exam ("$qText").';
        warnings.add(warn);
        issues.add(ImportErrorDetail(
          row: rowNum,
          problem: 'Question already exists in target exam',
          suggestion: 'Check if this question is intentional',
          isWarning: true,
        ));
      }

      final options = [oA, oB, oC, oD];
      if (options.any((o) => o.isEmpty)) {
        final err =
            'Row $rowNum: One or more options are empty for question: "$qText"';
        criticalErrors.add(err);
        issues.add(ImportErrorDetail(
          row: rowNum,
          problem: 'Missing one or more of options A/B/C/D',
          suggestion: 'Ensure all 4 option columns have text',
        ));
        continue;
      }

      final uniqueOptions = options.map((e) => e.toLowerCase()).toSet();
      if (uniqueOptions.length < 4) {
        final err =
            'Row $rowNum: Duplicate options found for question: "$qText"';
        criticalErrors.add(err);
        issues.add(ImportErrorDetail(
          row: rowNum,
          problem: 'Duplicate option texts',
          suggestion: 'Ensure all 4 options are distinct',
        ));
        continue;
      }

      if (correctRaw.isEmpty) {
        final err = 'Row $rowNum: Missing correct answer.';
        criticalErrors.add(err);
        issues.add(ImportErrorDetail(
          row: rowNum,
          problem: 'Missing correct answer',
          suggestion: 'Specify correct answer (e.g., B or A|C)',
        ));
        continue;
      }

      // Parse Correct Answers (Supports single & multiple e.g. "A|C", "A, C", "1|3", "B")
      final Set<int> parsedAnswers = {};
      final tokens = correctRaw
          .split(RegExp(r'[|;,/\s]+'))
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();

      for (var token in tokens) {
        if (token == 'a' || token == '1') {
          parsedAnswers.add(0);
        } else if (token == 'b' || token == '2') {
          parsedAnswers.add(1);
        } else if (token == 'c' || token == '3') {
          parsedAnswers.add(2);
        } else if (token == 'd' || token == '4') {
          parsedAnswers.add(3);
        } else {
          // Check if token matches option text exactly
          for (int j = 0; j < 4; j++) {
            if (options[j].toLowerCase() == token) {
              parsedAnswers.add(j);
              break;
            }
          }
        }
      }

      // If tokens didn't parse but whole raw string matches an option exactly
      if (parsedAnswers.isEmpty) {
        for (int j = 0; j < 4; j++) {
          if (options[j].toLowerCase() == correctRaw.toLowerCase()) {
            parsedAnswers.add(j);
            break;
          }
        }
      }

      if (parsedAnswers.isEmpty) {
        final err =
            'Row $rowNum: Invalid correct answer "$correctRaw". Must be A/B/C/D, 1/2/3/4, or option text (or combinations like A|C for multiple).';
        criticalErrors.add(err);
        issues.add(ImportErrorDetail(
          row: rowNum,
          problem: 'Invalid correct answer format "$correctRaw"',
          suggestion: 'Use A, B, C, D, or A|C for multiple correct answers',
        ));
        continue;
      }

      // Determine Question Type
      String questionType = 'single';
      if (qTypeRaw.contains('multi') || parsedAnswers.length > 1) {
        questionType = 'multiple';
      }

      int diff = 3;
      if (difficultyRaw.isNotEmpty) {
        final parsed = int.tryParse(difficultyRaw);
        if (parsed != null && parsed >= 1 && parsed <= 5) {
          diff = parsed;
        } else {
          warnings.add(
              'Row $rowNum: Invalid difficulty "$difficultyRaw". Defaulting to 3.');
        }
      }

      // Build 4 option explanations
      final Map<int, String> explanations = {};
      if (expA.isNotEmpty) explanations[0] = expA;
      if (expB.isNotEmpty) explanations[1] = expB;
      if (expC.isNotEmpty) explanations[2] = expC;
      if (expD.isNotEmpty) explanations[3] = expD;

      // Fallback to generic explanation if individual option explanations not given
      if (explanations.isEmpty && genericExp.isNotEmpty) {
        for (var ans in parsedAnswers) {
          explanations[ans] = genericExp;
        }
      }

      if (explanations.isEmpty) {
        suggestions.add('Row $rowNum: Missing explanation.');
      }
      if (topic.isEmpty) suggestions.add('Row $rowNum: Missing topic.');
      if (tagsRaw.isEmpty) suggestions.add('Row $rowNum: Missing tags.');

      List<String> tags = [];
      if (tagsRaw.isNotEmpty) {
        tags = tagsRaw
            .split(RegExp(r'[;,]'))
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }

      final nextNum = startQuestionNumber + validQuestions.length;
      final assignedId = 'Q$nextNum';

      validQuestions.add(Question(
        id: assignedId,
        question: qText,
        options: options,
        correctAnswers: parsedAnswers,
        questionType: questionType,
        optionExplanations: explanations,
        topic: topic.isEmpty ? null : topic,
        difficulty: diff,
        tags: tags,
      ));
    }

    if (validQuestions.isEmpty && criticalErrors.isEmpty) {
      criticalErrors.add('No valid questions found in file.');
    }

    final int startQ = startQuestionNumber;
    final int endQ = validQuestions.isNotEmpty
        ? startQuestionNumber + validQuestions.length - 1
        : startQuestionNumber;

    return ImportResult(
      validQuestions: validQuestions,
      filename: filename,
      targetExamName: targetExamName,
      startQuestionNumber: startQ,
      endQuestionNumber: endQ,
      issues: issues,
      criticalErrors: criticalErrors,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  static Future<String?> exportToCsvFile(Exam exam) async {
    final List<List<dynamic>> rows = [];
    rows.add([
      'question_text',
      'question_type',
      'option_a',
      'option_b',
      'option_c',
      'option_d',
      'correct_answer',
      'explanation_a',
      'explanation_b',
      'explanation_c',
      'explanation_d',
      'topic',
      'difficulty',
      'tags'
    ]);

    for (var q in exam.questions) {
      final correctChars = q.correctAnswers
          .map((idx) => ['A', 'B', 'C', 'D'][idx])
          .join('|');
      rows.add([
        q.question,
        q.questionType,
        q.options.isNotEmpty ? q.options[0] : '',
        q.options.length > 1 ? q.options[1] : '',
        q.options.length > 2 ? q.options[2] : '',
        q.options.length > 3 ? q.options[3] : '',
        correctChars,
        q.optionExplanations[0] ?? '',
        q.optionExplanations[1] ?? '',
        q.optionExplanations[2] ?? '',
        q.optionExplanations[3] ?? '',
        q.topic ?? '',
        q.difficulty.toString(),
        q.tags.join(';')
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);

    try {
      final suggested = "${exam.name.replaceAll(' ', '_')}_${exam.id}.csv";
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save exam as CSV',
        fileName: suggested,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (path != null) {
        final f = File(path);
        f.writeAsStringSync(csv);
        return f.path;
      }
    } catch (e) {
      // fallback
    }

    final downloads = await StorageService.getDownloadsDirectory();
    final file =
        File("${downloads.path}/${exam.name.replaceAll(' ', '_')}_${exam.id}.csv");
    file.writeAsStringSync(csv);
    return file.path;
  }
}

