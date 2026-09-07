import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';
import '../models/question.dart';
import '../models/exam.dart';

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
  final int duplicateCount;

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
    this.duplicateCount = 0,
  });

  int get validCount => validQuestions.length;
  int get errorCount => criticalErrors.length;
  int get warningCount => warnings.length;
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
    final bytes = file.bytes ??
        (file.path != null ? File(file.path!).readAsBytesSync() : <int>[]);
    final filename = file.name;

    final existingQuestions = targetExam?.questions
            .map((q) => q.question.trim().toLowerCase())
            .toSet() ??
        <String>{};
    final startId = (targetExam?.questions.length ?? 0) + 1;
    final examName = targetExam?.name ?? '';

    if (filename.toLowerCase().endsWith('.csv')) {
      String text;
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        try {
          text = latin1.decode(bytes);
        } catch (_) {
          text = String.fromCharCodes(bytes);
        }
      }
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
    // Strip UTF-8 BOM if present in any representation
    if (text.startsWith('\uFEFF')) {
      text = text.substring(1);
    } else if (text.startsWith('\u00EF\u00BB\u00BF') || text.startsWith('ï»¿')) {
      text = text.substring(3);
    }
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

  static String _normalizeHeader(String header) {
    return header
        .replaceAll('\uFEFF', '')
        .replaceAll('\u00EF\u00BB\u00BF', '')
        .replaceAll('ï»¿', '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-_\/]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
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
    int duplicateCount = 0;

    if (rows.isEmpty) {
      criticalErrors.add('File is completely empty.');
      return ImportResult(
        validQuestions: [],
        filename: filename,
        targetExamName: targetExamName,
        criticalErrors: criticalErrors,
      );
    }

    // 1. Identify Headers using normalized alias mapping
    Map<String, int> columnMap = {};
    int startRow = 0;

    final questionAliases = {
      'question',
      'question_text',
      'questiontext',
      'q',
      'prompt',
      'item'
    };
    final typeAliases = {'question_type', 'type', 'qtype', 'item_type'};
    final optAAliases = {
      'option_a',
      'option_1',
      'choice_a',
      'a',
      'opt_a',
      'choice_1'
    };
    final optBAliases = {
      'option_b',
      'option_2',
      'choice_b',
      'b',
      'opt_b',
      'choice_2'
    };
    final optCAliases = {
      'option_c',
      'option_3',
      'choice_c',
      'c',
      'opt_c',
      'choice_3'
    };
    final optDAliases = {
      'option_d',
      'option_4',
      'choice_d',
      'd',
      'opt_d',
      'choice_4'
    };
    final correctAliases = {
      'correct_answer',
      'correct_option',
      'correct',
      'answer',
      'key',
      'ans'
    };
    final expAAliases = {'explanation_a', 'exp_a', 'rationale_a'};
    final expBAliases = {'explanation_b', 'exp_b', 'rationale_b'};
    final expCAliases = {'explanation_c', 'exp_c', 'rationale_c'};
    final expDAliases = {'explanation_d', 'exp_d', 'rationale_d'};
    final expAliases = {'explanation', 'rationale', 'notes', 'feedback'};
    final topicAliases = {'topic', 'category', 'subject', 'domain'};
    final diffAliases = {'difficulty', 'level', 'diff'};
    final tagAliases = {'tags', 'tag', 'keywords'};

    for (int i = 0; i < rows.length; i++) {
      if (rows[i].isEmpty) continue;
      bool foundQuestion = false;
      bool foundOption = false;

      for (int c = 0; c < rows[i].length; c++) {
        final raw = rows[i][c].toString();
        final norm = _normalizeHeader(raw);
        if (norm.isEmpty) continue;

        if (questionAliases.contains(norm)) {
          columnMap['question'] = c;
          foundQuestion = true;
        } else if (typeAliases.contains(norm)) {
          columnMap['question_type'] = c;
        } else if (optAAliases.contains(norm)) {
          columnMap['option_a'] = c;
          foundOption = true;
        } else if (optBAliases.contains(norm)) {
          columnMap['option_b'] = c;
          foundOption = true;
        } else if (optCAliases.contains(norm)) {
          columnMap['option_c'] = c;
          foundOption = true;
        } else if (optDAliases.contains(norm)) {
          columnMap['option_d'] = c;
          foundOption = true;
        } else if (correctAliases.contains(norm)) {
          columnMap['correct'] = c;
        } else if (expAAliases.contains(norm)) {
          columnMap['explanation_a'] = c;
        } else if (expBAliases.contains(norm)) {
          columnMap['explanation_b'] = c;
        } else if (expCAliases.contains(norm)) {
          columnMap['explanation_c'] = c;
        } else if (expDAliases.contains(norm)) {
          columnMap['explanation_d'] = c;
        } else if (expAliases.contains(norm)) {
          columnMap['explanation'] = c;
        } else if (topicAliases.contains(norm)) {
          columnMap['topic'] = c;
        } else if (diffAliases.contains(norm)) {
          columnMap['difficulty'] = c;
        } else if (tagAliases.contains(norm)) {
          columnMap['tags'] = c;
        }
      }

      if (foundQuestion && foundOption) {
        startRow = i + 1;
        break;
      }
    }

    // Default positional fallback if no recognized header row found
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
      if (r.isEmpty ||
          r.every((element) => element.toString().trim().isEmpty)) {
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

      if (qText.isEmpty &&
          oA.isEmpty &&
          oB.isEmpty &&
          oC.isEmpty &&
          oD.isEmpty) {
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
        duplicateCount++;
        final err = 'Row $rowNum: Duplicate question in file ("$qText").';
        criticalErrors.add(err);
        issues.add(ImportErrorDetail(
          row: rowNum,
          problem: 'Duplicate question within file',
          suggestion: 'Remove duplicate question row',
        ));
        continue;
      }
      seenInThisFile.add(normQ);

      if (existingInTarget.contains(normQ)) {
        duplicateCount++;
        final warn =
            'Row $rowNum: Question already exists in target exam ("$qText").';
        warnings.add(warn);
        issues.add(ImportErrorDetail(
          row: rowNum,
          problem: 'Question already exists in target exam',
          suggestion: 'Verify if this is an intentional repeat',
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
          problem: 'Missing one or more options A/B/C/D',
          suggestion: 'Ensure all 4 option columns contain text',
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
          problem: 'Duplicate option texts in same question',
          suggestion: 'Ensure each of the 4 options is unique',
        ));
        continue;
      }

      if (correctRaw.isEmpty) {
        final err =
            'Row $rowNum: Missing correct answer for question: "$qText"';
        criticalErrors.add(err);
        issues.add(ImportErrorDetail(
          row: rowNum,
          problem: 'Missing correct answer',
          suggestion: 'Specify correct answer (e.g. A, B, C, D or A|C)',
        ));
        continue;
      }

      // Parse Correct Answers (Supports single & multiple e.g. "A|C", "A, C", "1|3", "B", exact option text)
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
          // Exact match option text check
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
            'Row $rowNum: Invalid correct answer "$correctRaw". Must be A/B/C/D, 1/2/3/4, or option text (e.g. A|C for multi-select).';
        criticalErrors.add(err);
        issues.add(ImportErrorDetail(
          row: rowNum,
          problem: 'Invalid correct answer value "$correctRaw"',
          suggestion: 'Specify A, B, C, D or combinations like A|C',
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
              'Row $rowNum: Invalid difficulty "$difficultyRaw". Defaulted to 3.');
        }
      }

      // Build 4 option explanations
      final Map<int, String> explanations = {};
      if (expA.isNotEmpty) explanations[0] = expA;
      if (expB.isNotEmpty) explanations[1] = expB;
      if (expC.isNotEmpty) explanations[2] = expC;
      if (expD.isNotEmpty) explanations[3] = expD;

      if (explanations.isEmpty && genericExp.isNotEmpty) {
        for (var ans in parsedAnswers) {
          explanations[ans] = genericExp;
        }
      }

      final List<String> tags = tagsRaw.isNotEmpty
          ? tagsRaw
              .split(RegExp(r'[,|;]+'))
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toList()
          : [];

      final currentDisplayNum = startQuestionNumber + validQuestions.length;
      final newQuestion = Question(
        id: const Uuid().v4(),
        question: qText,
        options: options,
        correctAnswers: parsedAnswers,
        questionType: questionType,
        optionExplanations: explanations,
        topic: topic.isNotEmpty ? topic : null,
        difficulty: diff,
        tags: tags,
        displayNumber: currentDisplayNum,
      );

      validQuestions.add(newQuestion);
    }

    return ImportResult(
      validQuestions: validQuestions,
      issues: issues,
      criticalErrors: criticalErrors,
      warnings: warnings,
      suggestions: suggestions,
      filename: filename,
      targetExamName: targetExamName,
      startQuestionNumber: startQuestionNumber,
      endQuestionNumber: startQuestionNumber + validQuestions.length - 1,
      duplicateCount: duplicateCount,
    );
  }

  static String getSampleCsvTemplate() {
    return '''question,option_a,option_b,option_c,option_d,correct_answer,question_type,topic,difficulty,tags,explanation_a,explanation_b,explanation_c,explanation_d
"What is the primary key in a database?","A unique identifier for each record","A foreign key from another table","An index for full text search","A temporary query variable","A","single","Databases",2,"SQL, DB","Correct: primary keys uniquely identify records","Incorrect","Incorrect","Incorrect"
"Which of the following are cloud providers? (Select all that apply)","Amazon Web Services (AWS)","Microsoft Windows 11","Google Cloud Platform (GCP)","Apple macOS","A|C","multiple","Cloud Computing",3,"Cloud, Infrastructure","AWS is a major cloud provider","Windows 11 is an OS","GCP is a major cloud provider","macOS is an OS"''';
  }

  static Future<String?> exportToCsvFile(Exam exam) async {
    final List<List<dynamic>> rows = [
      [
        'question',
        'option_a',
        'option_b',
        'option_c',
        'option_d',
        'correct_answer',
        'question_type',
        'topic',
        'difficulty',
        'tags',
        'explanation_a',
        'explanation_b',
        'explanation_c',
        'explanation_d',
      ]
    ];

    for (final q in exam.questions) {
      final oA = q.options.isNotEmpty ? q.options[0] : '';
      final oB = q.options.length > 1 ? q.options[1] : '';
      final oC = q.options.length > 2 ? q.options[2] : '';
      final oD = q.options.length > 3 ? q.options[3] : '';

      final correctLetters = q.correctAnswers
          .map((idx) => String.fromCharCode(65 + idx))
          .join('|');

      final expA = q.optionExplanations[0] ?? '';
      final expB = q.optionExplanations[1] ?? '';
      final expC = q.optionExplanations[2] ?? '';
      final expD = q.optionExplanations[3] ?? '';

      rows.add([
        q.question,
        oA,
        oB,
        oC,
        oD,
        correctLetters,
        q.questionType,
        q.topic ?? '',
        q.difficulty,
        q.tags.join(', '),
        expA,
        expB,
        expC,
        expD,
      ]);
    }

    final csvString = const ListToCsvConverter().convert(rows);

    final sanitizedName = exam.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Exam to CSV',
      fileName: '${sanitizedName}_questions.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsString(csvString);
      return outputFile;
    }
    return null;
  }
}
