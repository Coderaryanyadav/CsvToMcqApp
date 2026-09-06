import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:csv/csv.dart';
import '../models/question.dart';
import '../models/exam.dart';
import 'storage_service.dart';

class ImportResult {
  final List<Question> validQuestions;
  final List<String> criticalErrors;
  final List<String> warnings;
  final List<String> suggestions;
  final String filename;

  ImportResult({
    required this.validQuestions,
    required this.filename,
    this.criticalErrors = const [],
    this.warnings = const [],
    this.suggestions = const [],
  });
}

class ImportService {
  static Future<ImportResult?> pickAndPreviewFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    final bytes = file.bytes ?? File(file.path!).readAsBytesSync();
    final filename = file.name.toLowerCase();

    if (filename.endsWith('.csv')) {
      final text = String.fromCharCodes(bytes);
      return parseCsv(text, filename);
    } else {
      return parseExcel(bytes, filename);
    }
  }

  static ImportResult parseCsv(String text, String filename) {
    text = text.replaceAll('\r\n', '\n');
    List<List<dynamic>> rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(text);
    return processRows(rows, filename);
  }

  static ImportResult parseExcel(List<int> bytes, String filename) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      return ImportResult(validQuestions: [], filename: filename, criticalErrors: ['Excel file has no sheets or is invalid.']);
    }
    final sheet = excel.tables[excel.tables.keys.first]!;
    final List<List<dynamic>> rows = [];
    for (var r in sheet.rows) {
      rows.add(r.map((e) => e?.value?.toString() ?? '').toList());
    }
    return processRows(rows, filename);
  }

  static ImportResult processRows(List<List<dynamic>> rows, String filename) {
    final List<Question> validQuestions = [];
    final List<String> criticalErrors = [];
    final List<String> warnings = [];
    final List<String> suggestions = [];
    const uuid = Uuid();

    if (rows.isEmpty) {
      criticalErrors.add('File is completely empty.');
      return ImportResult(validQuestions: [], filename: filename, criticalErrors: criticalErrors);
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
        
        if (val.contains('question') || val == 'q') { columnMap['question'] = c; foundQuestion = true; }
        else if (val == 'option a' || val == 'option 1' || val == 'a' || val.contains('option a')) { columnMap['option_a'] = c; foundOption = true; }
        else if (val == 'option b' || val == 'option 2' || val == 'b' || val.contains('option b')) { columnMap['option_b'] = c; foundOption = true; }
        else if (val == 'option c' || val == 'option 3' || val == 'c' || val.contains('option c')) { columnMap['option_c'] = c; foundOption = true; }
        else if (val == 'option d' || val == 'option 4' || val == 'd' || val.contains('option d')) { columnMap['option_d'] = c; foundOption = true; }
        else if (val.contains('correct') || val.contains('answer')) { columnMap['correct'] = c; }
        else if (val.contains('explanation')) { columnMap['explanation'] = c; }
        else if (val.contains('topic')) { columnMap['topic'] = c; }
        else if (val.contains('difficulty')) { columnMap['difficulty'] = c; }
        else if (val.contains('tag')) { columnMap['tags'] = c; }
      }
      
      if (foundQuestion && foundOption) {
        startRow = i + 1;
        break;
      }
    }

    if (columnMap.isEmpty) {
      columnMap = {
        'question': 0, 'option_a': 1, 'option_b': 2, 'option_c': 3, 'option_d': 4,
        'correct': 5, 'explanation': 6, 'topic': 7, 'difficulty': 8, 'tags': 9
      };
      startRow = 0;
    }

    Set<String> seenQuestions = {};

    // 2. Process Data Rows
    for (int i = startRow; i < rows.length; i++) {
      final r = rows[i];
      if (r.isEmpty || r.every((element) => element.toString().trim().isEmpty)) continue;
      
      final rowNum = i + 1;
      
      String getCol(String key) {
        final idx = columnMap[key];
        if (idx == null || idx >= r.length) return '';
        return r[idx].toString().trim();
      }

      final qText = getCol('question');
      final oA = getCol('option_a');
      final oB = getCol('option_b');
      final oC = getCol('option_c');
      final oD = getCol('option_d');
      final correctRaw = getCol('correct');
      final explanation = getCol('explanation');
      final topic = getCol('topic');
      final difficultyRaw = getCol('difficulty');
      final tagsRaw = getCol('tags');

      if (qText.isEmpty && oA.isEmpty && oB.isEmpty && oC.isEmpty && oD.isEmpty) continue;

      if (qText.isEmpty) {
        criticalErrors.add('Row $rowNum: Missing question text.');
        continue;
      }

      if (seenQuestions.contains(qText.toLowerCase())) {
        criticalErrors.add('Row $rowNum: Duplicate question detected ("$qText").');
        continue;
      }
      seenQuestions.add(qText.toLowerCase());

      final options = [oA, oB, oC, oD];
      if (options.any((o) => o.isEmpty)) {
        criticalErrors.add('Row $rowNum: One or more options are empty for question: "$qText"');
        continue;
      }

      final uniqueOptions = options.map((e) => e.toLowerCase()).toSet();
      if (uniqueOptions.length < 4) {
        criticalErrors.add('Row $rowNum: Duplicate options found for question: "$qText"');
        continue;
      }

      if (correctRaw.isEmpty) {
        criticalErrors.add('Row $rowNum: Missing correct answer.');
        continue;
      }

      int? correctIndex;
      final cLower = correctRaw.toLowerCase();
      
      if (cLower == 'a' || cLower == '1') { correctIndex = 0; }
      else if (cLower == 'b' || cLower == '2') { correctIndex = 1; }
      else if (cLower == 'c' || cLower == '3') { correctIndex = 2; }
      else if (cLower == 'd' || cLower == '4') { correctIndex = 3; }
      
      if (correctIndex == null) {
        for (int j = 0; j < 4; j++) {
          if (options[j].toLowerCase() == cLower) {
            correctIndex = j;
            break;
          }
        }
      }

      if (correctIndex == null) {
        criticalErrors.add('Row $rowNum: Invalid correct answer "$correctRaw". Must be A/B/C/D, 1/2/3/4, or match an option exactly.');
        continue;
      }

      int diff = 3;
      if (difficultyRaw.isNotEmpty) {
        final parsed = int.tryParse(difficultyRaw);
        if (parsed != null && parsed >= 1 && parsed <= 5) {
          diff = parsed;
        } else {
          warnings.add('Row $rowNum: Invalid difficulty "$difficultyRaw". Defaulting to 3.');
        }
      }

      if (explanation.isEmpty) suggestions.add('Row $rowNum: Missing explanation.');
      if (topic.isEmpty) suggestions.add('Row $rowNum: Missing topic.');
      if (tagsRaw.isEmpty) suggestions.add('Row $rowNum: Missing tags.');

      List<String> tags = [];
      if (tagsRaw.isNotEmpty) {
        tags = tagsRaw.split(RegExp(r'[;,]')).map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      }

      validQuestions.add(Question(
        id: uuid.v4(),
        question: qText,
        options: options,
        correct: correctIndex,
        explanation: explanation.isEmpty ? null : explanation,
        topic: topic.isEmpty ? null : topic,
        difficulty: diff,
        tags: tags,
      ));
    }

    if (validQuestions.isEmpty && criticalErrors.isEmpty) {
      criticalErrors.add('No valid questions found in file.');
    }

    return ImportResult(
      validQuestions: validQuestions,
      filename: filename,
      criticalErrors: criticalErrors,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  static Future<String?> exportToCsvFile(Exam exam) async {
    final List<List<dynamic>> rows = [];
    rows.add(['Question', 'Option A', 'Option B', 'Option C', 'Option D', 'Correct Answer', 'Explanation', 'Topic', 'Difficulty', 'Tags']);
    
    for (var q in exam.questions) {
      final correctChar = ['A', 'B', 'C', 'D'][q.correct];
      rows.add([
        q.question,
        q.options[0],
        q.options[1],
        q.options[2],
        q.options[3],
        correctChar,
        q.explanation ?? '',
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
        allowedExtensions: ['csv']
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
    final file = File("${downloads.path}/${exam.name.replaceAll(' ', '_')}_${exam.id}.csv");
    file.writeAsStringSync(csv);
    return file.path;
  }
}
