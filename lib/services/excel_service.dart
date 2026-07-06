import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:csv/csv.dart';
import '../models/question.dart';
import '../models/exam.dart';
import 'storage_service.dart';

class ExcelService {
  /// Import from an Excel file. Strict validation is applied.
  /// Expected columns per row:
  /// question | option1 | option2 | option3 | option4 | correct_index (0..3)
  /// If any rows are invalid, this function throws a String describing the errors.
  static Future<Exam?> importFromExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );

    if (result == null) return null;

    final bytes =
        result.files.single.bytes ??
        File(result.files.single.path!).readAsBytesSync();
    final filename = result.files.single.name.toLowerCase();
    const uuid = Uuid();

    // Support CSV with robust quoted field handling and flexible formats
    if (filename.endsWith('.csv')) {
      final text = String.fromCharCodes(bytes);
      return _parseCsvText(text);
    }

    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw ('Excel file has no sheets or is invalid.');
    }
    final sheet = excel.tables[excel.tables.keys.first]!;
    final rows = sheet.rows;
    if (rows.isEmpty) {
      throw ('Excel sheet is empty.');
    }
    final List<Question> qs = [];
    final List<String> errors = [];
    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final rowNum = i + 1;
      String get(int idx) {
        if (r.length > idx && r[idx] != null && r[idx]!.value != null) {
          return r[idx]!.value.toString().trim();
        }
        return '';
      }

      final qText = get(0);
      final o1 = get(1);
      final o2 = get(2);
      final o3 = get(3);
      final o4 = get(4);
      final corrRaw = get(5);

      if (qText.isEmpty) {
        errors.add('Row $rowNum: Question text empty');
        continue;
      }
      if (o1.isEmpty || o2.isEmpty || o3.isEmpty || o4.isEmpty) {
        errors.add('Row $rowNum: One or more options empty');
        continue;
      }
      final ci = int.tryParse(corrRaw);
      if (ci == null || ci < 0 || ci > 3) {
        errors.add('Row $rowNum: CorrectIndex invalid (must be 0..3)');
        continue;
      }
      qs.add(
        Question(
          id: uuid.v4(),
          question: qText,
          options: [o1, o2, o3, o4],
          correct: ci,
        ),
      );
    }
    if (errors.isNotEmpty) {
      throw (errors.join('\n'));
    }
    return Exam(id: uuid.v4(), name: 'Imported exam', questions: qs);
  }

  static Future<Exam> importFromCsvString(String csv) async {
    return _parseCsvText(csv);
  }

  static Exam _parseCsvText(String text) {
    text = text.replaceAll('\r\n', '\n');
    List<List<dynamic>> rows = CsvToListConverter(eol: '\n', shouldParseNumbers: false).convert(text);
    final List<Question> qs = [];
    final List<String> errors = [];
    bool headerSkipped = false;
    const uuid = Uuid();
    for (int i = 0; i < rows.length; i++) {
      final rowNum = i + 1;
      final parts = rows[i].map((e) => e.toString()).toList();
      
      if (parts.isEmpty || (parts.length == 1 && parts[0].trim().isEmpty)) {
        continue;
      }
      
      if (parts.length < 6) {
        errors.add('Row $rowNum: Expected at least 6 columns (question, 4 options, correct), got ${parts.length}');
        continue;
      }
      if (!headerSkipped) {
        final headerCandidate = parts.take(6).map((p) => p.toLowerCase()).toList();
        final looksLikeHeader = headerCandidate[0].contains('question') &&
            headerCandidate[1].contains('option') &&
            headerCandidate[2].contains('option') &&
            headerCandidate[3].contains('option') &&
            headerCandidate[4].contains('option') &&
            (headerCandidate[5].contains('correct') || headerCandidate[5].contains('answer'));
        if (looksLikeHeader) {
          headerSkipped = true;
          continue;
        }
      }
      final qText = parts[0].trim();
      final o1 = parts[1].trim();
      final o2 = parts[2].trim();
      final o3 = parts[3].trim();
      final o4 = parts[4].trim();
      final corrRaw = parts[5].trim();
      String? explanation;
      String? topic;
      int? difficulty;
      List<String> tags = [];
      if (parts.length > 6) {
        explanation = parts[6].trim().isEmpty ? null : parts[6].trim();
      }
      if (parts.length > 7) {
        topic = parts[7].trim().isEmpty ? null : parts[7].trim();
      }
      if (parts.length > 8) {
        final d = int.tryParse(parts[8].trim());
        if (d != null && d >= 1 && d <= 5) {
          difficulty = d;
        }
      }
      if (parts.length > 9) {
        final rawTags = parts[9].trim();
        if (rawTags.isNotEmpty) {
          tags = rawTags.split(RegExp(r'[;,]')).map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
        }
      }
      if (qText.isEmpty) {
        errors.add('Row $rowNum: Question text empty');
        continue;
      }
      if (o1.isEmpty || o2.isEmpty || o3.isEmpty || o4.isEmpty) {
        errors.add('Row $rowNum: One or more options empty');
        continue;
      }
      int? ci;
      final numVal = int.tryParse(corrRaw);
      if (numVal != null) {
        if (numVal >= 0 && numVal <= 3) ci = numVal;
        if (numVal >= 1 && numVal <= 4) ci = numVal - 1;
      }
      if (ci == null && corrRaw.isNotEmpty) {
        final letter = corrRaw.trim().toUpperCase();
        const letters = ['A', 'B', 'C', 'D'];
        final li = letters.indexOf(letter);
        if (li >= 0) ci = li;
      }
      if (ci == null && corrRaw.isNotEmpty) {
        final opts = [o1, o2, o3, o4];
        final idx = opts.indexWhere((o) => o.toLowerCase() == corrRaw.toLowerCase());
        if (idx >= 0) ci = idx;
      }
      ci ??= 0;
      qs.add(
        Question(
          id: uuid.v4(),
          question: qText,
          options: [o1, o2, o3, o4],
          correct: ci,
          explanation: explanation,
          topic: topic,
          difficulty: difficulty ?? 3,
          tags: tags,
        ),
      );
    }
    if (errors.isNotEmpty) {
      throw (errors.join('\n'));
    }
    if (qs.isEmpty) {
      throw 'No valid questions found in CSV file';
    }
    return Exam(id: uuid.v4(), name: 'Imported exam', questions: qs);
  }

  /// Export exam to Excel and save via Save dialog if available; otherwise write to downloads.
  static Future<String?> exportToExcelFile(Exam exam) async {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    for (var q in exam.questions) {
      final rowCells = [
        TextCellValue(q.question),
        TextCellValue(q.options[0]),
        TextCellValue(q.options[1]),
        TextCellValue(q.options[2]),
        TextCellValue(q.options[3]),
        IntCellValue(q.correct),
      ];
      sheet.appendRow(rowCells);
    }
    final bytes = excel.encode();
    try {
      final suggested = "${exam.name.replaceAll(' ', '_')}_${exam.id}.xlsx";
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save exam as',
        fileName: suggested,
      );
      if (path != null) {
        final f = File(path);
        f.writeAsBytesSync(bytes!);
        return f.path;
      }
    } catch (e) {
      // fallback
    }
    final downloads = await StorageService.getDownloadsDirectory();
    final file = File(
      "${downloads.path}/${exam.name.replaceAll(' ', '_')}_${exam.id}.xlsx",
    );
    file.writeAsBytesSync(bytes!);
    return file.path;
  }


}
