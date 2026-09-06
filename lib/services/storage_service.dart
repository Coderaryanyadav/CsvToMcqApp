import 'dart:convert';
import 'dart:io';
import '../models/exam.dart';
import '../models/performance.dart';
import '../models/student_profile.dart';
import '../repositories/storage_repository.dart';

class StorageService {
  static IStorageRepository _repo = IoStorageRepository();

  static void setRepository(IStorageRepository repo) {
    _repo = repo;
  }

  static Future<void> init() async {
    await _repo.init();
  }

  static Future<Directory> getDownloadsDirectory() async {
    if (_repo is IoStorageRepository) {
      return (_repo as IoStorageRepository).appDir;
    }
    return Directory.current;
  }

  // Student Profiles
  static Future<List<StudentProfile>> getAllStudents() async {
    return _repo.getAllStudents();
  }

  static Future<StudentProfile?> getStudent(String id) async {
    return _repo.getStudentById(id);
  }

  static Future<void> saveStudent(StudentProfile student) async {
    await _repo.saveStudent(student);
  }

  static Future<void> deleteStudent(String id) async {
    await _repo.deleteStudent(id);
  }

  static Future<StudentProfile?> getActiveStudent() async {
    final activeId = await _repo.getActiveStudentId();
    if (activeId == null) return null;
    return _repo.getStudentById(activeId);
  }

  static Future<void> setActiveStudent(StudentProfile student) async {
    await _repo.saveStudent(student);
    await _repo.setActiveStudentId(student.id);
  }

  static Future<List<ExamPerformance>> loadPerformancesForActiveStudent() async {
    final all = await loadAllPerformancesAsync();
    final activeStudent = await getActiveStudent();
    if (activeStudent == null) return all;
    return all.where((p) => p.studentId == null || p.studentId == activeStudent.id).toList();
  }

  static Future<List<Exam>> loadAllExams() async {
    return _repo.getAllExams();
  }

  static Future<Exam?> getExam(String id) async {
    return _repo.getExamById(id);
  }

  static Future<void> saveExam(Exam exam) async {
    await _repo.saveExam(exam);
  }

  static Future<void> deleteExam(String examId) async {
    await _repo.deleteExam(examId);
  }

  static Future<void> saveSession(
      String examId, Map<String, dynamic> session) async {
    await _repo.saveSession(examId, session);
  }

  static Future<Map<String, dynamic>?> readSession(String examId) async {
    return _repo.getSession(examId);
  }

  static Future<void> clearSession(String examId) async {
    await _repo.deleteSession(examId);
  }

  static Future<void> savePerformance(ExamPerformance performance) async {
    await _repo.savePerformance(performance);
  }

  static Future<List<ExamPerformance>> loadAllPerformancesAsync() async {
    return _repo.getAllPerformances();
  }

  static List<ExamPerformance> loadAllPerformances() {
    if (_repo is IoStorageRepository) {
      final mcqDir = (_repo as IoStorageRepository).mcqDir;
      if (!mcqDir.existsSync()) return [];
      final files = mcqDir
          .listSync()
          .where((f) =>
              f.path.contains('performance_') && f.path.endsWith('.json'))
          .toList();
      final List<ExamPerformance> list = [];
      for (var f in files) {
        try {
          final text = File(f.path).readAsStringSync();
          list.add(ExamPerformance.fromJson(
              jsonDecode(text) as Map<String, dynamic>));
        } catch (_) {}
      }
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    }
    return [];
  }

  static List<ExamPerformance> getPerformancesForExam(String examId) {
    return loadAllPerformances().where((p) => p.examId == examId).toList();
  }

  static Future<Map<String, dynamic>> loadSettings() async {
    return _repo.getSettings();
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _repo.saveSettings(settings);
  }

  static Future<void> clearAllData() async {
    await _repo.clearAllData();
  }

  static Future<void> seedStarterDataIfEmpty() async {
    // 100% dynamic database-driven: no hardcoded mock exams
  }
}
