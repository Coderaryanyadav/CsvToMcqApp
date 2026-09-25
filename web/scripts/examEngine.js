import { Storage } from './storage.js';

export class ExamEngine {
  constructor(options = {}) {
    this.mode = options.mode || 'practice'; // 'practice' or 'timed'
    this.exam = options.exam;
    this.questions = options.questions || (this.exam ? this.exam.questions : []);
    this.durationMinutes = options.durationMinutes !== undefined ? options.durationMinutes : (this.exam ? this.exam.defaultDuration : 30);
    this.passingPercentage = this.exam ? this.exam.passingPercentage : 75;
    
    this.currentIndex = 0;
    this.userAnswers = {}; // { questionId: Set<number> }
    this.revealedPractice = {}; // { questionId: boolean }
    this.flaggedForReview = new Set(); // Set of questionIds
    this.questionTimes = {}; // { questionId: seconds }
    this.currentQuestionStart = Date.now();

    this.timer = null;
    this.totalSeconds = (this.durationMinutes || 0) * 60;
    this.remainingSeconds = this.totalSeconds;
    this.elapsedSeconds = 0;
    this.isCompleted = false;

    this.onStateChange = options.onStateChange || (() => {});
    this.onComplete = options.onComplete || (() => {});

    this.init();
  }

  init() {
    this.questions.forEach(q => {
      this.userAnswers[q.id] = new Set();
      this.questionTimes[q.id] = 0;
    });

    // Check if there was an active session to restore in timed exam mode
    if (this.exam && this.mode === 'timed') {
      const saved = Storage.getSession(this.exam.id);
      if (saved && saved.userAnswers && !saved.completed) {
        Object.entries(saved.userAnswers).forEach(([qId, ansArr]) => {
          this.userAnswers[qId] = new Set(ansArr);
        });
        if (saved.flagged) {
          this.flaggedForReview = new Set(saved.flagged);
        }
        if (saved.remainingSeconds !== undefined) {
          this.remainingSeconds = saved.remainingSeconds;
        }
        if (saved.currentIndex !== undefined && saved.currentIndex < this.questions.length) {
          this.currentIndex = saved.currentIndex;
        }
      }
    }

    this.startTimer();
  }

  startTimer() {
    if (this.timer) clearInterval(this.timer);
    this.currentQuestionStart = Date.now();

    this.timer = setInterval(() => {
      if (this.isCompleted) {
        clearInterval(this.timer);
        return;
      }

      this.elapsedSeconds++;

      if (this.mode === 'timed' && this.durationMinutes > 0) {
        if (this.remainingSeconds > 0) {
          this.remainingSeconds--;
        } else {
          // Time expired! Close confirm modal if open & auto-submit
          document.getElementById('modalSubmitConfirm')?.classList.remove('open');
          this.submitExam(true);
          return;
        }
      }

      // Auto-save session periodically in timed exam
      if (this.mode === 'timed' && this.exam && this.elapsedSeconds % 5 === 0) {
        this.saveCurrentSession();
      }

      this.onStateChange({ type: 'tick', remaining: this.remainingSeconds, elapsed: this.elapsedSeconds });
    }, 1000);
  }

  saveCurrentSession() {
    if (!this.exam) return;
    const answersExport = {};
    Object.entries(this.userAnswers).forEach(([k, v]) => {
      answersExport[k] = Array.from(v);
    });

    Storage.saveSession(this.exam.id, {
      examId: this.exam.id,
      currentIndex: this.currentIndex,
      remainingSeconds: this.remainingSeconds,
      elapsedSeconds: this.elapsedSeconds,
      userAnswers: answersExport,
      flagged: Array.from(this.flaggedForReview),
      completed: this.isCompleted
    });
  }

  getCurrentQuestion() {
    return this.questions[this.currentIndex] || null;
  }

  selectOption(optionIndex) {
    if (this.isCompleted) return;
    const q = this.getCurrentQuestion();
    if (!q) return;

    const currentSet = this.userAnswers[q.id] || new Set();
    const isMulti = q.questionType === 'multiple' || (q.correctAnswers && q.correctAnswers.length > 1);

    if (isMulti) {
      // Multi-select: toggle
      if (currentSet.has(optionIndex)) {
        currentSet.delete(optionIndex);
      } else {
        currentSet.add(optionIndex);
      }
      this.userAnswers[q.id] = currentSet;
    } else {
      // Single select: always set to chosen option
      currentSet.clear();
      currentSet.add(optionIndex);
      this.userAnswers[q.id] = currentSet;

      // In practice mode, single choice immediately reveals
      if (this.mode === 'practice') {
        this.revealedPractice[q.id] = true;
      }
    }

    this.onStateChange({ type: 'answer_changed', questionId: q.id, answers: this.userAnswers[q.id] });
  }

  revealPracticeAnswer() {
    const q = this.getCurrentQuestion();
    if (!q) return;
    this.revealedPractice[q.id] = true;
    this.onStateChange({ type: 'practice_revealed', questionId: q.id });
  }

  isRevealed(questionId) {
    return !!this.revealedPractice[questionId];
  }

  toggleFlag(questionId = null) {
    const qId = questionId || (this.getCurrentQuestion() ? this.getCurrentQuestion().id : null);
    if (!qId) return;

    if (this.flaggedForReview.has(qId)) {
      this.flaggedForReview.delete(qId);
    } else {
      this.flaggedForReview.add(qId);
    }

    this.onStateChange({ type: 'flag_changed', questionId: qId, isFlagged: this.flaggedForReview.has(qId) });
  }

  isFlagged(questionId) {
    return this.flaggedForReview.has(questionId);
  }

  goToQuestion(index) {
    if (index < 0 || index >= this.questions.length) return;
    this.recordTimeSpent();
    this.currentIndex = index;
    this.currentQuestionStart = Date.now();
    this.onStateChange({ type: 'navigated', currentIndex: this.currentIndex });
  }

  next() {
    if (this.currentIndex < this.questions.length - 1) {
      this.goToQuestion(this.currentIndex + 1);
    }
  }

  prev() {
    if (this.currentIndex > 0) {
      this.goToQuestion(this.currentIndex - 1);
    }
  }

  recordTimeSpent() {
    const q = this.getCurrentQuestion();
    if (!q) return;
    const diff = Math.round((Date.now() - this.currentQuestionStart) / 1000);
    this.questionTimes[q.id] = (this.questionTimes[q.id] || 0) + Math.max(0, diff);
  }

  isQuestionAnswered(questionId) {
    const ans = this.userAnswers[questionId];
    return ans && ans.size > 0;
  }

  isQuestionCorrect(question) {
    const userAns = this.userAnswers[question.id] || new Set();
    const correctAns = new Set(question.correctAnswers || []);
    if (userAns.size === 0 || userAns.size !== correctAns.size) return false;
    for (let a of correctAns) {
      if (!userAns.has(a)) return false;
    }
    return true;
  }

  submitExam(isAuto = false) {
    if (this.isCompleted) return;
    this.isCompleted = true;
    this.recordTimeSpent();
    if (this.timer) clearInterval(this.timer);

    let correctCount = 0;
    let incorrectCount = 0;
    let unansweredCount = 0;

    const questionResults = {};
    const topicPerformance = {};
    const difficultyPerformance = {};
    const questionSnapshots = {};
    const weakTopics = new Set();
    const missedQuestions = [];

    this.questions.forEach(q => {
      const isAnswered = this.isQuestionAnswered(q.id);
      const isCorrect = this.isQuestionCorrect(q);
      const topic = q.topic || 'General';
      const diff = (q.difficulty || 3).toString();

      if (!topicPerformance[topic]) topicPerformance[topic] = { correct: 0, total: 0 };
      topicPerformance[topic].total++;

      if (!difficultyPerformance[diff]) difficultyPerformance[diff] = { correct: 0, total: 0 };
      difficultyPerformance[diff].total++;

      if (!isAnswered) {
        unansweredCount++;
        questionResults[q.id] = false;
        weakTopics.add(topic);
        missedQuestions.push(q);
      } else if (isCorrect) {
        correctCount++;
        questionResults[q.id] = true;
        topicPerformance[topic].correct++;
        difficultyPerformance[diff].correct++;
      } else {
        incorrectCount++;
        questionResults[q.id] = false;
        weakTopics.add(topic);
        missedQuestions.push(q);
      }

      questionSnapshots[q.id] = {
        id: q.id,
        question: q.question,
        options: q.options,
        correctAnswers: q.correctAnswers,
        userAnswers: Array.from(this.userAnswers[q.id] || []),
        optionExplanations: q.optionExplanations,
        explanation: q.explanation,
        topic: q.topic,
        difficulty: q.difficulty,
        isCorrect
      };
    });

    const total = this.questions.length;
    const percentage = total > 0 ? Math.round((correctCount / total) * 100) : 0;
    const passed = percentage >= this.passingPercentage;

    const performanceRecord = {
      examId: this.exam ? this.exam.id : 'practice_' + Date.now(),
      examName: this.exam ? this.exam.name : 'Practice Session',
      totalQuestions: total,
      correct: correctCount,
      incorrect: incorrectCount,
      unanswered: unansweredCount,
      durationSeconds: this.elapsedSeconds,
      timePerQuestion: this.questionTimes,
      questionResults,
      weakTopics: Array.from(weakTopics),
      passingPercentage: this.passingPercentage,
      score: percentage,
      passed,
      topicPerformance,
      difficultyPerformance,
      questionSnapshots,
      missedQuestions,
      mode: this.mode,
      autoSubmitted: isAuto
    };

    Storage.savePerformance(performanceRecord);

    if (this.exam) {
      Storage.deleteSession(this.exam.id);
    }

    this.onComplete(performanceRecord);
    return performanceRecord;
  }

  destroy() {
    if (this.timer) clearInterval(this.timer);
  }
}
