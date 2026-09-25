import { DEFAULT_STUDENT, DEFAULT_EXAMS } from './defaultData.js';
import { Auth } from './auth.js';
import { Supabase } from './supabaseClient.js';

const STORAGE_KEYS = {
  EXAMS: 'quizpro_exams_v3',
  STUDENTS: 'quizpro_students_v3',
  ACTIVE_STUDENT_ID: 'quizpro_active_student_id_v3',
  PERFORMANCES: 'quizpro_performances_v3',
  BOOKMARKS: 'quizpro_bookmarks_v3',
  SESSIONS: 'quizpro_exam_sessions_v3',
  SETTINGS: 'quizpro_settings_v3',
  STREAKS: 'quizpro_streaks_v3',
  CLEAN_FLAG: 'quizpro_v3_clean_slate'
};

class StorageRepository {
  constructor() {
    this.init();
  }

  init() {
    // Force clean slate: remove any leftover legacy dummy exams
    if (localStorage.getItem(STORAGE_KEYS.CLEAN_FLAG) !== 'true') {
      localStorage.removeItem('quizpro_exams_v2');
      localStorage.removeItem('quizpro_students_v2');
      localStorage.removeItem('quizpro_active_student_id_v2');
      localStorage.removeItem('quizpro_performances_v2');
      localStorage.removeItem('quizpro_bookmarks_v2');
      localStorage.removeItem('quizpro_exam_sessions_v2');

      localStorage.setItem(STORAGE_KEYS.CLEAN_FLAG, 'true');
      localStorage.setItem(STORAGE_KEYS.EXAMS, JSON.stringify(DEFAULT_EXAMS)); // Empty []
      localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify([DEFAULT_STUDENT]));
      localStorage.setItem(STORAGE_KEYS.ACTIVE_STUDENT_ID, DEFAULT_STUDENT.id);
      localStorage.setItem(STORAGE_KEYS.PERFORMANCES, JSON.stringify([]));
      localStorage.setItem(STORAGE_KEYS.BOOKMARKS, JSON.stringify({}));
      localStorage.setItem(STORAGE_KEYS.SETTINGS, JSON.stringify({
        theme: 'dark',
        soundEnabled: true,
        keyboardShortcuts: true,
        showExplanationsImmediately: true
      }));
      return;
    }

    if (!localStorage.getItem(STORAGE_KEYS.EXAMS)) {
      localStorage.setItem(STORAGE_KEYS.EXAMS, JSON.stringify([]));
    }

    if (!localStorage.getItem(STORAGE_KEYS.STUDENTS)) {
      localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify([DEFAULT_STUDENT]));
      localStorage.setItem(STORAGE_KEYS.ACTIVE_STUDENT_ID, DEFAULT_STUDENT.id);
    }

    if (!localStorage.getItem(STORAGE_KEYS.SETTINGS)) {
      localStorage.setItem(STORAGE_KEYS.SETTINGS, JSON.stringify({
        theme: 'dark',
        soundEnabled: true,
        keyboardShortcuts: true,
        showExplanationsImmediately: true
      }));
    }
  }

  // --- Student Profiles & User Accounts ---
  getStudents() {
    try {
      const data = localStorage.getItem(STORAGE_KEYS.STUDENTS);
      return data ? JSON.parse(data) : [DEFAULT_STUDENT];
    } catch (e) {
      console.error('Failed to load students', e);
      return [DEFAULT_STUDENT];
    }
  }

  getActiveStudent() {
    const user = Auth.getActiveUser();
    if (user) {
      return {
        id: user.id,
        name: user.name,
        avatarEmoji: user.avatarEmoji || '🎓',
        isGuest: !!user.isGuest
      };
    }
    const students = this.getStudents();
    const activeId = localStorage.getItem(STORAGE_KEYS.ACTIVE_STUDENT_ID);
    const found = students.find(s => s.id === activeId);
    return found || students[0] || DEFAULT_STUDENT;
  }

  setActiveStudentId(studentId) {
    localStorage.setItem(STORAGE_KEYS.ACTIVE_STUDENT_ID, studentId);
  }

  saveStudent(student) {
    const students = this.getStudents();
    const idx = students.findIndex(s => s.id === student.id);
    if (idx >= 0) {
      students[idx] = { ...students[idx], ...student };
    } else {
      students.push({
        id: student.id || 'student_' + Date.now(),
        name: student.name || 'Student',
        avatarEmoji: student.avatarEmoji || '🎓',
        avatarColorValue: student.avatarColorValue || '#4F46E5',
        createdAt: new Date().toISOString()
      });
    }
    localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(students));
    return students;
  }

  deleteStudent(studentId) {
    let students = this.getStudents();
    if (students.length <= 1) {
      throw new Error('At least one profile must be retained.');
    }
    students = students.filter(s => s.id !== studentId);
    localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(students));
    if (localStorage.getItem(STORAGE_KEYS.ACTIVE_STUDENT_ID) === studentId) {
      this.setActiveStudentId(students[0].id);
    }
    return students;
  }

  // --- Exams ---
  getAllExams() {
    try {
      const raw = localStorage.getItem(STORAGE_KEYS.EXAMS);
      const exams = raw ? JSON.parse(raw) : [];
      exams.forEach(exam => {
        if (exam.questions) {
          exam.questions.forEach((q, idx) => {
            q.displayNumber = idx + 1;
          });
        }
      });
      return exams;
    } catch (e) {
      console.error('Error fetching exams', e);
      return [];
    }
  }

  getExamById(id) {
    const exams = this.getAllExams();
    return exams.find(e => e.id === id) || null;
  }

  addExam(exam) {
    return this.saveExam(exam);
  }

  saveExam(exam) {
    const exams = this.getAllExams();
    const now = new Date().toISOString();
    const idx = exam && exam.id ? exams.findIndex(e => e.id === exam.id) : -1;

    const generateUUID = () => {
      if (typeof crypto !== 'undefined' && crypto.randomUUID) {
        return crypto.randomUUID();
      }
      return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
      });
    };

    const reindex = (qs) => (qs || []).map((q, i) => ({
      ...q,
      displayNumber: i + 1,
      id: q.id || generateUUID()
    }));

    if (idx >= 0) {
      exams[idx] = {
        ...exams[idx],
        ...exam,
        questions: reindex(exam.questions || exams[idx].questions),
        updatedAt: now
      };
    } else {
      const newExam = {
        id: (exam && exam.id) ? exam.id : generateUUID(),
        name: (exam && exam.name) || 'Untitled Exam',
        description: (exam && exam.description) || '',
        category: (exam && exam.category) || 'General',
        provider: (exam && exam.provider) || 'Self',
        code: (exam && exam.code) || '',
        passingPercentage: (exam && Number(exam.passingPercentage)) || 75,
        defaultDuration: (exam && exam.defaultDuration !== undefined) ? Number(exam.defaultDuration) : 30,
        createdAt: now,
        updatedAt: now,
        schemaVersion: 1,
        questions: reindex((exam && exam.questions) || [])
      };
      exams.unshift(newExam);
    }

    localStorage.setItem(STORAGE_KEYS.EXAMS, JSON.stringify(exams));

    // Background sync to Supabase if configured
    try {
      const saved = idx >= 0 ? exams[idx] : exams[0];
      Supabase.syncExamsToCloud([saved]).catch(() => {});
    } catch {}

    return exams;
  }

  setAllExams(exams) {
    localStorage.setItem(STORAGE_KEYS.EXAMS, JSON.stringify(exams || []));
    return exams;
  }

  deleteExam(id) {
    let exams = this.getAllExams();
    exams = exams.filter(e => e.id !== id);
    localStorage.setItem(STORAGE_KEYS.EXAMS, JSON.stringify(exams));
    this.deleteSession(id);
    return exams;
  }

  // Question level CRUD
  addQuestionToExam(examId, questionData) {
    const exam = this.getExamById(examId);
    if (!exam) throw new Error('Exam not found');
    if (!exam.questions) exam.questions = [];

    const newQuestion = {
      ...questionData,
      id: questionData.id || 'q_' + Date.now() + '_' + exam.questions.length,
      displayNumber: exam.questions.length + 1
    };

    exam.questions.push(newQuestion);
    this.saveExam(exam);
    return newQuestion;
  }

  updateQuestionInExam(examId, questionId, updatedData) {
    const exam = this.getExamById(examId);
    if (!exam) throw new Error('Exam not found');
    const idx = (exam.questions || []).findIndex(q => q.id === questionId);
    if (idx >= 0) {
      exam.questions[idx] = { ...exam.questions[idx], ...updatedData };
      this.saveExam(exam);
      return exam.questions[idx];
    }
    throw new Error('Question not found');
  }

  deleteQuestionFromExam(examId, questionId) {
    const exam = this.getExamById(examId);
    if (!exam) throw new Error('Exam not found');
    exam.questions = (exam.questions || []).filter(q => q.id !== questionId);
    this.saveExam(exam);
    return exam;
  }

  // --- Bookmarks (per student) ---
  getBookmarks(studentId) {
    const sId = studentId || this.getActiveStudent().id;
    try {
      const allBookmarks = JSON.parse(localStorage.getItem(STORAGE_KEYS.BOOKMARKS) || '{}');
      return new Set(allBookmarks[sId] || []);
    } catch {
      return new Set();
    }
  }

  toggleBookmark(questionId, studentId) {
    const sId = studentId || this.getActiveStudent().id;
    const allBookmarks = JSON.parse(localStorage.getItem(STORAGE_KEYS.BOOKMARKS) || '{}');
    const studentBookmarks = new Set(allBookmarks[sId] || []);

    const isBookmarked = studentBookmarks.has(questionId);
    if (isBookmarked) {
      studentBookmarks.delete(questionId);
    } else {
      studentBookmarks.add(questionId);
    }

    allBookmarks[sId] = Array.from(studentBookmarks);
    localStorage.setItem(STORAGE_KEYS.BOOKMARKS, JSON.stringify(allBookmarks));
    return !isBookmarked;
  }

  isBookmarked(questionId, studentId) {
    return this.getBookmarks(studentId).has(questionId);
  }

  // --- Exam Sessions (Live State Persistence) ---
  saveSession(examId, sessionData) {
    try {
      const sessions = JSON.parse(localStorage.getItem(STORAGE_KEYS.SESSIONS) || '{}');
      sessions[examId] = {
        ...sessionData,
        savedAt: new Date().toISOString()
      };
      localStorage.setItem(STORAGE_KEYS.SESSIONS, JSON.stringify(sessions));
    } catch (e) {
      console.warn('Failed to save session state', e);
    }
  }

  getSession(examId) {
    try {
      const sessions = JSON.parse(localStorage.getItem(STORAGE_KEYS.SESSIONS) || '{}');
      return sessions[examId] || null;
    } catch {
      return null;
    }
  }

  deleteSession(examId) {
    try {
      const sessions = JSON.parse(localStorage.getItem(STORAGE_KEYS.SESSIONS) || '{}');
      delete sessions[examId];
      localStorage.setItem(STORAGE_KEYS.SESSIONS, JSON.stringify(sessions));
    } catch (e) {
      console.warn('Failed to delete session', e);
    }
  }

  // --- Attempt History & Performance ---
  savePerformance(performance) {
    const performances = this.getPerformances();
    const activeStudent = this.getActiveStudent();

    const record = {
      ...performance,
      id: performance.id || 'perf_' + Date.now(),
      studentId: performance.studentId || activeStudent.id,
      studentName: performance.studentName || activeStudent.name,
      date: performance.date || new Date().toISOString()
    };

    performances.unshift(record);
    localStorage.setItem(STORAGE_KEYS.PERFORMANCES, JSON.stringify(performances));
    this.updateStudyStreak(record.date);

    // Background sync to Supabase if configured
    try {
      Supabase.syncPerformanceToCloud(record).catch(() => {});
    } catch {}

    return record;
  }

  getPerformances(studentId = null) {
    try {
      const raw = localStorage.getItem(STORAGE_KEYS.PERFORMANCES);
      const list = raw ? JSON.parse(raw) : [];
      if (!studentId) return list;
      return list.filter(p => p.studentId === studentId);
    } catch {
      return [];
    }
  }

  deletePerformance(id) {
    let perfs = this.getPerformances();
    perfs = perfs.filter(p => p.id !== id);
    localStorage.setItem(STORAGE_KEYS.PERFORMANCES, JSON.stringify(perfs));
    return perfs;
  }

  clearAllPerformances(studentId = null) {
    if (studentId) {
      let perfs = this.getPerformances();
      perfs = perfs.filter(p => p.studentId !== studentId);
      localStorage.setItem(STORAGE_KEYS.PERFORMANCES, JSON.stringify(perfs));
    } else {
      localStorage.setItem(STORAGE_KEYS.PERFORMANCES, JSON.stringify([]));
    }
  }

  // --- Study Streak Calculation ---
  updateStreak(dateOrStudentId) {
    return this.updateStudyStreak(typeof dateOrStudentId === 'string' && dateOrStudentId.includes('-') ? dateOrStudentId : undefined);
  }

  updateStudyStreak(attemptDateStr) {
    const student = this.getActiveStudent();
    const streaks = JSON.parse(localStorage.getItem(STORAGE_KEYS.STREAKS) || '{}');
    const studentStreak = streaks[student.id] || { currentStreak: 0, lastDate: null, history: [] };

    const todayStr = new Date(attemptDateStr || Date.now()).toISOString().split('T')[0];

    if (!studentStreak.history.includes(todayStr)) {
      studentStreak.history.push(todayStr);
      studentStreak.history.sort();

      if (studentStreak.lastDate) {
        const last = new Date(studentStreak.lastDate);
        const today = new Date(todayStr);
        const diffDays = Math.round((today - last) / (1000 * 60 * 60 * 24));

        if (diffDays === 1) {
          studentStreak.currentStreak += 1;
        } else if (diffDays > 1) {
          studentStreak.currentStreak = 1;
        }
      } else {
        studentStreak.currentStreak = 1;
      }
      studentStreak.lastDate = todayStr;
      streaks[student.id] = studentStreak;
      localStorage.setItem(STORAGE_KEYS.STREAKS, JSON.stringify(streaks));
    }

    return studentStreak.currentStreak;
  }

  getStreak(studentId = null) {
    const sId = studentId || this.getActiveStudent().id;
    const streaks = JSON.parse(localStorage.getItem(STORAGE_KEYS.STREAKS) || '{}');
    const s = streaks[sId];
    if (!s) return { currentStreak: 0, lastDate: null };

    if (!s.lastDate) return { currentStreak: 0, lastDate: null };

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const last = new Date(s.lastDate);
    last.setHours(0, 0, 0, 0);
    const diff = Math.round((today - last) / (1000 * 60 * 60 * 24));
    if (diff > 1) {
      s.currentStreak = 0;
    }
    return s;
  }

  // --- Settings ---
  getSettings() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEYS.SETTINGS) || '{}');
    } catch {
      return { theme: 'dark', soundEnabled: true, keyboardShortcuts: true };
    }
  }

  saveSettings(settings) {
    const current = this.getSettings();
    const updated = { ...current, ...settings };
    localStorage.setItem(STORAGE_KEYS.SETTINGS, JSON.stringify(updated));
    return updated;
  }

  // --- Backup & Restore ---
  exportFullBackup() {
    return {
      version: 3,
      exportDate: new Date().toISOString(),
      exams: this.getAllExams(),
      students: this.getStudents(),
      activeStudentId: localStorage.getItem(STORAGE_KEYS.ACTIVE_STUDENT_ID),
      performances: this.getPerformances(),
      bookmarks: JSON.parse(localStorage.getItem(STORAGE_KEYS.BOOKMARKS) || '{}'),
      settings: this.getSettings(),
      streaks: JSON.parse(localStorage.getItem(STORAGE_KEYS.STREAKS) || '{}')
    };
  }

  importFullBackup(backupData) {
    if (!backupData || !backupData.exams) {
      throw new Error('Invalid backup file structure: missing exams array.');
    }
    if (Array.isArray(backupData.exams)) {
      localStorage.setItem(STORAGE_KEYS.EXAMS, JSON.stringify(backupData.exams));
    }
    if (Array.isArray(backupData.students)) {
      localStorage.setItem(STORAGE_KEYS.STUDENTS, JSON.stringify(backupData.students));
    }
    if (backupData.activeStudentId) {
      localStorage.setItem(STORAGE_KEYS.ACTIVE_STUDENT_ID, backupData.activeStudentId);
    }
    if (Array.isArray(backupData.performances)) {
      localStorage.setItem(STORAGE_KEYS.PERFORMANCES, JSON.stringify(backupData.performances));
    }
    if (backupData.bookmarks) {
      localStorage.setItem(STORAGE_KEYS.BOOKMARKS, JSON.stringify(backupData.bookmarks));
    }
    if (backupData.settings) {
      localStorage.setItem(STORAGE_KEYS.SETTINGS, JSON.stringify(backupData.settings));
    }
    if (backupData.streaks) {
      localStorage.setItem(STORAGE_KEYS.STREAKS, JSON.stringify(backupData.streaks));
    }
    return true;
  }

  resetAllData() {
    localStorage.removeItem(STORAGE_KEYS.EXAMS);
    localStorage.removeItem(STORAGE_KEYS.STUDENTS);
    localStorage.removeItem(STORAGE_KEYS.ACTIVE_STUDENT_ID);
    localStorage.removeItem(STORAGE_KEYS.PERFORMANCES);
    localStorage.removeItem(STORAGE_KEYS.BOOKMARKS);
    localStorage.removeItem(STORAGE_KEYS.SESSIONS);
    localStorage.removeItem(STORAGE_KEYS.SETTINGS);
    localStorage.removeItem(STORAGE_KEYS.STREAKS);
    localStorage.removeItem(STORAGE_KEYS.CLEAN_FLAG);
    this.init();
  }
}

export const Storage = new StorageRepository();
