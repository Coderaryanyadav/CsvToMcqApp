import { Storage } from './storage.js';
import { ExamEngine } from './examEngine.js';
import { parseCSVString, parseExcelArrayBuffer, processRows, generateSampleCsvContent } from './importEngine.js';
import { createSampleDemoExam } from './defaultData.js';
import { Auth } from './auth.js';
import { Sound } from './sound.js';
import { ConfettiCelebration } from './confetti.js';
import { Supabase } from './supabaseClient.js';
import { Icons } from './icons.js';

class QuizProApp {
  constructor() {
    this.currentView = 'exams';
    this.activeEngine = null;
    this.importPreviewData = null;
    this.init();
  }

  init() {
    this.initTheme();
    this.initEventListeners();
    if (this.checkAuthenticationGate()) {
      this.renderHeaderInfo();
      this.switchView('dashboard');
    }
  }

  checkAuthenticationGate() {
    const isAuth = Auth.isAuthenticated();
    const modal = document.getElementById('modalAuth');
    const closeBtn = document.getElementById('btnAuthClose');

    if (!isAuth) {
      if (modal) {
        modal.classList.add('open', 'modal-locked');
        if (closeBtn) closeBtn.style.display = 'none';
        this.switchAuthTab('login');
      }
      return false;
    } else {
      if (modal) {
        modal.classList.remove('open', 'modal-locked');
        if (closeBtn) closeBtn.style.display = 'inline-flex';
      }
      return true;
    }
  }

  onAuthSuccess(message = 'Authenticated successfully') {
    const modal = document.getElementById('modalAuth');
    modal?.classList.remove('open', 'modal-locked');
    this.renderHeaderInfo();
    this.switchView('dashboard');
    this.showToast(message, 'success');
  }

  // --- Themes ---
  initTheme() {
    const settings = Storage.getSettings();
    const theme = settings.theme || 'dark';
    document.documentElement.setAttribute('data-theme', theme);
    this.updateThemeToggleIcon(theme);
  }

  toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme') || 'dark';
    const next = current === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    Storage.saveSettings({ theme: next });
    this.updateThemeToggleIcon(next);
  }

  updateThemeToggleIcon(theme) {
    const btn = document.getElementById('themeToggleBtn');
    if (btn) {
      btn.innerHTML = theme === 'dark' ? '☀️' : '🌙';
      btn.title = `Switch to ${theme === 'dark' ? 'Light' : 'Dark'} Mode`;
    }
  }

  // --- Header Profile, Auth & Streak ---
  renderHeaderInfo() {
    const activeSession = Auth.getActiveUser();
    const user = activeSession || Storage.getActiveStudent();
    const streak = Storage.getStreak(user.id);
    const isRegistered = activeSession && !activeSession.isGuest;

    const avatarEl = document.getElementById('activeStudentAvatar');
    const nameEl = document.getElementById('activeStudentName');
    const streakEl = document.getElementById('activeStreakDisplay');
    const btnHeaderLogin = document.getElementById('btnHeaderLogin');

    const initials = (user.name || 'User')
      .split(' ')
      .filter(Boolean)
      .map(n => n[0])
      .join('')
      .slice(0, 2)
      .toUpperCase();

    if (avatarEl) {
      avatarEl.textContent = initials || 'AY';
      avatarEl.classList.add('avatar-initials');
    }
    if (nameEl) {
      nameEl.textContent = user.name || 'Scholar';
    }
    if (streakEl) {
      streakEl.innerHTML = `${Icons.flame('', 13)} <span>${streak.currentStreak || 0}d streak</span>`;
    }
    if (btnHeaderLogin) {
      btnHeaderLogin.style.display = isRegistered ? 'none' : 'inline-flex';
    }

    // Dropdown details
    const menuAvatar = document.getElementById('menuAvatar');
    const menuName = document.getElementById('menuName');
    const menuEmail = document.getElementById('menuEmail');
    const menuLogoutBtn = document.getElementById('menuBtnLogout');
    const menuSwitchBtn = document.getElementById('menuBtnSwitchAccount');

    if (menuAvatar) {
      menuAvatar.textContent = initials || 'AY';
      menuAvatar.classList.add('avatar-initials');
    }
    if (menuName) menuName.textContent = user.name || 'Scholar';
    if (menuEmail) menuEmail.textContent = user.email || 'scholar@quizpro.local';
    if (menuLogoutBtn) menuLogoutBtn.innerHTML = `${Icons.arrowLeft('', 14)} Sign Out`;
    if (menuSwitchBtn) menuSwitchBtn.innerHTML = `${Icons.lock('', 14)} Switch Account`;

    // Sound toggle state
    const soundBtn = document.getElementById('btnSoundToggle');
    if (soundBtn) {
      soundBtn.innerHTML = Sound.enabled ? Icons.volume('', 15) : Icons.volumeMute('', 15);
      soundBtn.title = Sound.enabled ? 'Mute Sound Effects' : 'Enable Sound Effects';
    }
  }

  // --- Router / View Switching ---
  switchView(viewName = 'dashboard', params = {}) {
    if (!viewName) viewName = 'dashboard';
    if (!this.checkAuthenticationGate()) {
      return;
    }

    // Teardown active exam engine if navigating away from quiz/exam
    if (this.activeEngine && viewName !== 'practice' && viewName !== 'exam') {
      this.activeEngine.destroy();
      this.activeEngine = null;
    }

    document.querySelectorAll('.view-section').forEach(sec => sec.classList.remove('active'));
    document.querySelectorAll('.nav-tab-btn').forEach(btn => btn.classList.remove('active'));

    const targetSec = document.getElementById(`view-${viewName}`) || document.getElementById('view-dashboard');
    const targetTab = document.querySelector(`.nav-tab-btn[data-view="${viewName}"]`) || document.querySelector('.nav-tab-btn[data-view="dashboard"]');

    if (targetSec) targetSec.classList.add('active');
    if (targetTab) targetTab.classList.add('active');

    this.currentView = viewName;
    window.scrollTo({ top: 0, behavior: 'smooth' });

    switch (viewName) {
      case 'dashboard':
        this.renderDashboard();
        break;
      case 'exams':
        this.renderExamsCatalog();
        break;
      case 'question_bank':
        this.renderQuestionBank();
        break;
      case 'history':
        this.renderHistory();
        break;
      case 'analytics':
        this.renderAnalytics();
        break;
      case 'settings':
        this.renderSettings();
        break;
      case 'practice':
        this.startPracticeSession(params);
        break;
      case 'exam':
        this.startTimedExamSession(params);
        break;
      case 'results':
        this.renderResultsScreen(params.performance);
        break;
    }
  }

  // ==========================================================================
  // VIEW: Executive Dashboard (Replica of Flutter Home Screen)
  // ==========================================================================
  renderDashboard() {
    const student = Storage.getActiveStudent();
    const exams = Storage.getAllExams();
    const perfs = Storage.getPerformances();
    const bookmarks = Storage.getBookmarks(student ? student.id : null);

    // Update welcome heading
    const titleEl = document.getElementById('dashWelcomeTitle');
    const subEl = document.getElementById('dashWelcomeSub');
    if (titleEl) {
      titleEl.textContent = student ? `Welcome, ${student.name}! ${student.avatarEmoji || '🎓'}` : 'Welcome to QuizPro! 🎓';
    }
    if (subEl) {
      subEl.textContent = student ? 'Here is your active practice progress and performance overview.' : 'Create and manage your MCQ question banks, practice, and track performance.';
    }

    // KPI Metrics calculation matching Flutter home_screen.dart
    let totalQuestionsAnswered = 0;
    let totalCorrect = 0;
    let totalStudySecs = 0;

    perfs.forEach(p => {
      totalQuestionsAnswered += (p.totalQuestions || 0);
      totalCorrect += (p.correct || 0);
      totalStudySecs += (p.durationSeconds || 0);
    });

    const avgAccuracy = totalQuestionsAnswered > 0 ? Math.round((totalCorrect / totalQuestionsAnswered) * 100) : 0;
    const streak = Storage.getStreak();

    const mAnswered = document.getElementById('dashMetricAnswered');
    const mAccuracy = document.getElementById('dashMetricAccuracy');
    const mTime = document.getElementById('dashMetricTime');
    const mStreak = document.getElementById('dashMetricStreak');

    if (mAnswered) mAnswered.textContent = totalQuestionsAnswered.toLocaleString();
    if (mAccuracy) mAccuracy.textContent = `${avgAccuracy}%`;
    if (mTime) mTime.textContent = `${Math.round(totalStudySecs / 60)}m`;
    if (mStreak) mStreak.textContent = `${streak.currentStreak || 0} Days 🔥`;

    // Starred count
    let totalStarred = 0;
    exams.forEach(e => {
      (e.questions || []).forEach(q => {
        if (bookmarks.has(q.id)) totalStarred++;
      });
    });

    const starredCountEl = document.getElementById('dashStarredCount');
    if (starredCountEl) starredCountEl.textContent = totalStarred;

    // Render Recent Exams Grid (Limit 4)
    const examsGrid = document.getElementById('dashExamsGrid');
    if (examsGrid) {
      if (exams.length === 0) {
        examsGrid.innerHTML = `
          <div style="grid-column: 1/-1; text-align: center; padding: 2.5rem; background: var(--bg-card); border-radius: var(--radius-lg); border: 1px dashed var(--border-color);">
            <p style="color: var(--text-muted); margin-bottom: 1rem;">No examination tracks yet in your repository.</p>
            <button class="btn btn-primary btn-sm" id="btnDashEmptyCreate">${Icons.plus('', 13)} Create First Exam</button>
          </div>
        `;
        document.getElementById('btnDashEmptyCreate')?.addEventListener('click', () => this.openAddExamModal());
      } else {
        examsGrid.innerHTML = exams.slice(0, 4).map(exam => {
          const qCount = (exam.questions || []).length;
          const starredInExam = (exam.questions || []).filter(q => bookmarks.has(q.id)).length;

          return `
            <div class="exam-card" style="padding: 1.25rem;">
              <div class="exam-card-header" style="margin-bottom: 0.6rem;">
                <span class="exam-category-tag">${this.escapeHtml(exam.category || 'General')}</span>
                <div style="display: flex; gap: 0.35rem; align-items: center;">
                  ${starredInExam > 0 ? `<span class="meta-pill" style="font-size: 0.72rem; color: #F59E0B; border-color: rgba(245, 158, 11, 0.35);">⭐ ${starredInExam}</span>` : ''}
                  <span style="font-size: 0.78rem; color: var(--text-muted);">${qCount} Qs</span>
                </div>
              </div>
              <h4 style="font-size: 1.1rem; font-weight: 700; margin: 0 0 0.35rem;">${this.escapeHtml(exam.name)}</h4>
              <p style="font-size: 0.82rem; color: var(--text-muted); margin-bottom: 1rem; line-height: 1.4;">${this.escapeHtml(exam.description || 'No description provided.')}</p>
              
              <div style="display: flex; gap: 0.5rem; margin-top: auto;">
                ${qCount === 0 ? `
                  <button class="btn btn-secondary btn-sm btn-dash-import" data-id="${exam.id}" style="flex: 1.2;">
                    ${Icons.upload('', 12)} Import
                  </button>
                  <button class="btn btn-primary btn-sm btn-dash-add-q" data-id="${exam.id}" style="flex: 1;">
                    ${Icons.plus('', 12)} Add Q
                  </button>
                ` : `
                  <button class="btn btn-secondary btn-sm btn-dash-practice" data-id="${exam.id}" style="flex: 1;">
                    ${Icons.play('', 12)} Practice
                  </button>
                  <button class="btn btn-primary btn-sm btn-dash-exam" data-id="${exam.id}" style="flex: 1;">
                    ${Icons.clock('', 12)} Timed Exam
                  </button>
                `}
              </div>
            </div>
          `;
        }).join('');

        examsGrid.querySelectorAll('.btn-dash-import').forEach(btn => {
          btn.addEventListener('click', (e) => {
            const id = e.currentTarget.dataset.id;
            this.openImportModal(id);
          });
        });

        examsGrid.querySelectorAll('.btn-dash-add-q').forEach(btn => {
          btn.addEventListener('click', (e) => {
            const id = e.currentTarget.dataset.id;
            this.openAddQuestionModal(id);
          });
        });

        examsGrid.querySelectorAll('.btn-dash-practice').forEach(btn => {
          btn.addEventListener('click', (e) => {
            const id = e.currentTarget.dataset.id;
            this.openSessionLauncherModal({ examId: id, defaultMode: 'practice' });
          });
        });

        examsGrid.querySelectorAll('.btn-dash-exam').forEach(btn => {
          btn.addEventListener('click', (e) => {
            const id = e.currentTarget.dataset.id;
            this.openSessionLauncherModal({ examId: id, defaultMode: 'exam' });
          });
        });
      }
    }

    // Render Recent Session Attempts
    const recentHistory = document.getElementById('dashRecentHistoryContainer');
    if (recentHistory) {
      if (perfs.length === 0) {
        recentHistory.innerHTML = `
          <div style="text-align: center; padding: 2rem; background: var(--bg-card); border-radius: var(--radius-lg); border: 1px solid var(--border-color); color: var(--text-muted); font-size: 0.88rem;">
            No practice sessions or exam attempts recorded yet. Launch a session to begin tracking progress!
          </div>
        `;
      } else {
        recentHistory.innerHTML = `
          <div style="overflow-x: auto; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: var(--radius-lg);">
            <table class="analytics-table" style="font-size: 0.84rem;">
              <thead>
                <tr>
                  <th>Date &amp; Time</th>
                  <th>Examination</th>
                  <th>Mode</th>
                  <th>Score</th>
                  <th>Result</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                ${perfs.slice(0, 5).map(p => {
                  const isPass = p.passed;
                  const missedCount = (p.missedQuestions || []).length;
                  return `
                    <tr>
                      <td style="color: var(--text-muted);">${new Date(p.date).toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })}</td>
                      <td><strong>${this.escapeHtml(p.examName)}</strong></td>
                      <td>
                        <span class="q-badge" style="font-size: 0.72rem; text-transform: uppercase;">
                          ${p.mode === 'practice' ? '🎓 Practice' : '⏱️ Timed'}
                        </span>
                      </td>
                      <td><span style="font-weight: 800; font-size: 0.95rem; color: ${isPass ? 'var(--success)' : 'var(--danger)'};">${p.score}%</span></td>
                      <td>
                        <span class="badge ${isPass ? 'badge-pass' : 'badge-fail'}" style="font-size: 0.72rem; padding: 0.2rem 0.5rem; border-radius: var(--radius-full);">
                          ${isPass ? 'Passed' : 'Needs Work'}
                        </span>
                      </td>
                      <td>
                        <div style="display: flex; gap: 0.4rem;">
                          <button class="btn btn-secondary btn-sm btn-view-audit" data-id="${p.id}" style="padding: 0.25rem 0.6rem; font-size: 0.76rem;">Audit</button>
                          ${missedCount > 0 ? `<button class="btn btn-warning btn-sm btn-dash-drill-mistakes" data-id="${p.id}" style="padding: 0.25rem 0.6rem; font-size: 0.76rem; font-weight: 700;">Mistakes (${missedCount})</button>` : ''}
                        </div>
                      </td>
                    </tr>
                  `;
                }).join('')}
              </tbody>
            </table>
          </div>
        `;

        recentHistory.querySelectorAll('.btn-view-audit').forEach(btn => {
          btn.addEventListener('click', (e) => {
            const perfId = e.currentTarget.dataset.id;
            this.openAuditModal(perfId);
          });
        });

        recentHistory.querySelectorAll('.btn-dash-drill-mistakes').forEach(btn => {
          btn.addEventListener('click', (e) => {
            const perfId = e.currentTarget.dataset.id;
            const perf = perfs.find(p => p.id === perfId);
            if (perf && perf.missedQuestions && perf.missedQuestions.length > 0) {
              this.switchView('practice', {
                examId: perf.examId,
                customQuestions: perf.missedQuestions
              });
            }
          });
        });
      }
    }
  }

  // ==========================================================================
  // VIEW: Exams Catalog
  // ==========================================================================
  renderExamsCatalog() {
    const container = document.getElementById('examsCatalogGrid');
    if (!container) return;

    const exams = Storage.getAllExams();
    const performances = Storage.getPerformances();

    if (exams.length === 0) {
      container.innerHTML = `
        <div style="grid-column: 1/-1; text-align: center; padding: 4.5rem 1.5rem; background: var(--bg-card); border: 1px dashed var(--border-color); border-radius: var(--radius-xl);">
          <div style="display: inline-flex; align-items: center; justify-content: center; width: 64px; height: 64px; border-radius: 50%; background: var(--bg-subtle); border: 1px solid var(--border-color); margin-bottom: 1.25rem; color: var(--text-muted);">
            ${Icons.book('', 28)}
          </div>
          <h2 style="font-size: 1.3rem; font-weight: 700; margin-bottom: 0.5rem; letter-spacing: -0.015em;">No Examinations in Repository</h2>
          <p style="color: var(--text-muted); margin-bottom: 1.75rem; max-width: 440px; margin-left: auto; margin-right: auto; font-size: 0.9rem; line-height: 1.6;">
            Create your custom examination, import questions from CSV or Excel, or quickly load a sample certification test to get started.
          </p>
          <div style="display: flex; gap: 0.75rem; justify-content: center; flex-wrap: wrap;">
            <button class="btn btn-primary" id="btnEmptyCreateExam">${Icons.plus('', 14)} Create First Exam</button>
            <button class="btn btn-secondary" id="btnEmptyImportExam">${Icons.upload('', 14)} Import Questions File</button>
            <button class="btn btn-secondary" id="btnEmptyLoadSample">${Icons.sparkles('', 14)} Load Sample Test</button>
          </div>
        </div>
      `;
      document.getElementById('btnEmptyCreateExam')?.addEventListener('click', () => this.openAddExamModal());
      document.getElementById('btnEmptyImportExam')?.addEventListener('click', () => this.openImportModal());
      document.getElementById('btnEmptyLoadSample')?.addEventListener('click', () => {
        const sample = createSampleDemoExam();
        Storage.saveExam(sample);
        this.showToast('Sample Exam loaded with questions! Click Practice or Timed Exam to start.', 'success');
        this.switchView('exams');
      });
      return;
    }

    container.innerHTML = exams.map(exam => {
      const qCount = exam.questions ? exam.questions.length : 0;
      const examPerfs = performances.filter(p => p.examId === exam.id);
      const attemptsCount = examPerfs.length;
      const bestScore = attemptsCount > 0 ? Math.max(...examPerfs.map(p => p.score || 0)) : null;

      return `
        <div class="exam-card" data-exam-id="${exam.id}">
          <div>
            <div class="exam-card-header">
              <span class="exam-category-tag">${this.escapeHtml(exam.category || 'General')}</span>
              <div style="display: flex; gap: 0.35rem;">
                <button class="icon-btn btn-sm btn-card-import-icon" title="Import Questions (CSV/Excel)" data-id="${exam.id}">${Icons.upload('', 12)}</button>
                <button class="icon-btn btn-sm btn-card-add-q" title="Add Question Manually" data-id="${exam.id}">${Icons.plus('', 12)}</button>
                <button class="icon-btn btn-sm btn-edit-exam" title="Edit Exam Settings" data-id="${exam.id}">${Icons.edit('', 12)}</button>
                <button class="icon-btn btn-sm btn-delete-exam" title="Delete Exam" data-id="${exam.id}">${Icons.trash('', 12)}</button>
              </div>
            </div>
            <h3 class="exam-card-title">${this.escapeHtml(exam.name)}</h3>
            <p class="exam-card-desc">${this.escapeHtml(exam.description || 'No description provided.')}</p>
            
            <div class="exam-meta-pills">
              <span class="meta-pill">${Icons.database('', 12)} ${qCount} Questions</span>
              <span class="meta-pill">${Icons.clock('', 12)} ${exam.defaultDuration ? exam.defaultDuration + ' Min' : 'Untimed'}</span>
              <span class="meta-pill">${Icons.target('', 12)} Pass: ${exam.passingPercentage}%</span>
              ${attemptsCount > 0 ? `<span class="meta-pill" style="color: var(--accent-blue)">${Icons.star('', 12, true)} Best: ${bestScore}% (${attemptsCount} test${attemptsCount > 1 ? 's' : ''})</span>` : ''}
            </div>
          </div>

          ${qCount === 0 ? `
            <div class="exam-empty-prompt">
              <div class="exam-empty-banner">
                ${Icons.info('', 14)}
                <span>No questions yet. Import questions to begin.</span>
              </div>
              <div style="display: flex; gap: 0.5rem; width: 100%;">
                <button class="btn btn-primary btn-card-import-action" data-id="${exam.id}" style="flex: 1.2; font-size: 0.85rem; padding: 0.55rem 0.75rem;">
                  ${Icons.upload('', 13)} Import Questions
                </button>
                <button class="btn btn-secondary btn-card-add-q-action" data-id="${exam.id}" style="flex: 1; font-size: 0.85rem; padding: 0.55rem 0.75rem;">
                  ${Icons.plus('', 13)} Add Question
                </button>
              </div>
            </div>
          ` : `
            <div class="exam-card-actions">
              <button class="btn btn-secondary btn-practice-exam" data-id="${exam.id}" style="flex: 1;">
                ${Icons.play('', 12)} Practice (${qCount})
              </button>
              <button class="btn btn-primary btn-take-exam" data-id="${exam.id}" style="flex: 1;">
                ${Icons.clock('', 12)} Timed Exam
              </button>
            </div>
          `}
        </div>
      `;
    }).join('');

    // Attach card event listeners
    container.querySelectorAll('.btn-card-add-q, .btn-card-add-q-action').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const id = e.currentTarget.dataset.id;
        this.openAddQuestionModal(id);
      });
    });

    container.querySelectorAll('.btn-card-import-icon, .btn-card-import-action').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const id = e.currentTarget.dataset.id;
        this.openImportModal(id);
      });
    });

    container.querySelectorAll('.btn-practice-exam').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const id = e.currentTarget.dataset.id;
        const exam = Storage.getExamById(id);
        if (!exam || !exam.questions || exam.questions.length === 0) {
          this.showToast('This exam has no questions yet. Click ➕ to add questions!', 'info');
          return;
        }
        this.openSessionLauncherModal({ examId: id, defaultMode: 'practice' });
      });
    });

    container.querySelectorAll('.btn-take-exam').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const id = e.currentTarget.dataset.id;
        const exam = Storage.getExamById(id);
        if (!exam || !exam.questions || exam.questions.length === 0) {
          this.showToast('This exam has no questions yet. Click ➕ to add questions!', 'info');
          return;
        }
        this.openSessionLauncherModal({ examId: id, defaultMode: 'exam' });
      });
    });

    container.querySelectorAll('.btn-edit-exam').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const id = e.currentTarget.dataset.id;
        this.openAddExamModal(id);
      });
    });

    container.querySelectorAll('.btn-delete-exam').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const id = e.currentTarget.dataset.id;
        if (confirm('Are you sure you want to delete this exam and all its questions?')) {
          Storage.deleteExam(id);
          this.showToast('Exam deleted', 'success');
          this.renderExamsCatalog();
        }
      });
    });
  }

  // ==========================================================================
  // VIEW: Interactive Practice Arena
  // ==========================================================================
  startPracticeSession({ examId = null, filterType = 'all', customQuestions = null, durationMinutes = 0 }) {
    let exam = null;
    let questions = [];

    if (customQuestions && customQuestions.length > 0) {
      questions = [...customQuestions];
      if (examId) exam = Storage.getExamById(examId);
    } else if (examId) {
      exam = Storage.getExamById(examId);
      if (exam) questions = [...exam.questions];
    } else {
      const allExams = Storage.getAllExams();
      allExams.forEach(e => questions.push(...e.questions));
    }

    if (filterType === 'bookmarked') {
      const activeStudent = Storage.getActiveStudent();
      const bookmarks = Storage.getBookmarks(activeStudent.id);
      questions = questions.filter(q => bookmarks.has(q.id));
    }

    if (questions.length === 0) {
      this.showToast('No questions available to practice.', 'info');
      this.switchView('exams');
      return;
    }

    this.activeEngine = new ExamEngine({
      mode: 'practice',
      exam,
      questions,
      durationMinutes: durationMinutes || 0,
      onStateChange: () => this.renderPracticeCard(),
      onComplete: (perf) => this.switchView('results', { performance: perf })
    });

    this.renderPracticeCard();
  }

  renderPracticeCard() {
    const arena = document.getElementById('practiceArena');
    if (!arena || !this.activeEngine) return;

    const q = this.activeEngine.getCurrentQuestion();
    if (!q) return;

    const total = this.activeEngine.questions.length;
    const curIdx = this.activeEngine.currentIndex;
    const activeStudent = Storage.getActiveStudent();
    const isBookmarked = Storage.isBookmarked(q.id, activeStudent.id);
    const userAns = this.activeEngine.userAnswers[q.id] || new Set();
    const isRevealed = this.activeEngine.isRevealed(q.id);
    const isMulti = q.questionType === 'multiple' || (q.correctAnswers && q.correctAnswers.length > 1);

    const progressPct = ((curIdx + 1) / total) * 100;

    arena.innerHTML = `
      <div class="arena-container">
        <div class="arena-topbar">
          <div class="arena-exam-info">
            <h2>📘 ${this.escapeHtml(this.activeEngine.exam ? this.activeEngine.exam.name : 'Practice Mode')}</h2>
            <span>Question ${curIdx + 1} of ${total}</span>
          </div>
          <div class="arena-hud">
            <button class="icon-btn" id="btnTogglePracticeBookmark" title="Toggle Bookmark" style="color: ${isBookmarked ? '#F59E0B' : 'inherit'}">
              ${isBookmarked ? '⭐' : '☆'}
            </button>
            <button class="btn btn-secondary btn-sm" id="btnFinishPractice">Finish Practice</button>
          </div>
        </div>

        <div class="progress-bar-container">
          <div class="progress-bar-fill" style="width: ${progressPct}%"></div>
        </div>

        <div class="question-card">
          <div class="question-card-header">
            <div class="q-meta-group">
              <span class="q-badge">Q${curIdx + 1}</span>
              ${q.topic ? `<span class="q-badge" style="color: var(--accent-blue)">🏷️ ${this.escapeHtml(q.topic)}</span>` : ''}
              <span class="q-badge ${isMulti ? 'type-multi' : ''}">${isMulti ? '☑️ Multi-Select (Choose all that apply)' : '🔘 Single Choice'}</span>
            </div>
            <span style="font-size: 0.8rem; color: var(--text-faint)">
              Difficulty: ${'★'.repeat(q.difficulty || 3)}${'☆'.repeat(5 - (q.difficulty || 3))}
            </span>
          </div>

          <h3 class="q-title">${this.escapeHtml(q.question)}</h3>

          <div class="options-list">
            ${q.options.map((optText, optIdx) => {
              const letter = String.fromCharCode(65 + optIdx);
              const isSelected = userAns.has(optIdx);
              const isCorrectOpt = q.correctAnswers && q.correctAnswers.includes(optIdx);
              
              let stateClass = '';
              if (isRevealed) {
                if (isCorrectOpt) stateClass = 'is-correct';
                else if (isSelected && !isCorrectOpt) stateClass = 'is-incorrect';
              } else if (isSelected) {
                stateClass = 'selected';
              }

              const explanation = q.optionExplanations ? q.optionExplanations[optIdx] : null;

              return `
                <div class="option-item ${stateClass}" data-opt-idx="${optIdx}">
                  <div class="option-letter">${letter}</div>
                  <div style="flex-grow: 1;">
                    <div class="option-text">${this.escapeHtml(optText)}</div>
                    ${isRevealed && explanation ? `<div class="option-explanation-inline">💡 ${this.escapeHtml(explanation)}</div>` : ''}
                  </div>
                  ${isRevealed ? (isCorrectOpt ? '<span style="color: var(--success); font-weight: 800;">✓</span>' : (isSelected ? '<span style="color: var(--danger); font-weight: 800;">✗</span>' : '')) : ''}
                </div>
              `;
            }).join('')}
          </div>

          ${isMulti && !isRevealed ? `
            <div style="text-align: right; margin-top: 1rem;">
              <button class="btn btn-primary btn-sm" id="btnCheckMultiAnswer" ${userAns.size === 0 ? 'disabled' : ''}>
                Check Answer
              </button>
            </div>
          ` : ''}

          ${isRevealed && (q.explanation || (q.optionExplanations && Object.keys(q.optionExplanations).length > 0)) ? `
            <div class="general-explanation-card">
              <div class="explanation-header">💡 Comprehensive Rationale</div>
              <div class="explanation-body">${this.escapeHtml(q.explanation || Object.values(q.optionExplanations)[0])}</div>
            </div>
          ` : ''}
        </div>

        <div class="arena-nav-bar">
          <button class="btn btn-secondary" id="btnPracticePrev" ${curIdx === 0 ? 'disabled' : ''}>
            ← Previous
          </button>
          
          <div style="display: flex; gap: 0.5rem; align-items: center;">
            <button class="icon-btn" id="btnTogglePaletteDrawer" title="Question Palette">🔢</button>
            <span style="font-size: 0.85rem; color: var(--text-muted);">${curIdx + 1} / ${total}</span>
          </div>

          <button class="btn btn-primary" id="btnPracticeNext" ${curIdx === total - 1 ? 'disabled' : ''}>
            Next →
          </button>
        </div>

        <div class="palette-drawer" id="practicePaletteDrawer" style="display: none;">
          <div class="palette-title">
            <span>Question Quick Navigator</span>
            <span style="font-size: 0.75rem; text-transform: none; color: var(--text-faint);">Click any box to jump</span>
          </div>
          <div class="palette-grid">
            ${this.activeEngine.questions.map((ques, idx) => {
              const isAns = this.activeEngine.isQuestionAnswered(ques.id);
              const isCur = idx === curIdx;
              return `
                <button class="palette-btn ${isAns ? 'answered' : ''} ${isCur ? 'current' : ''}" data-idx="${idx}">
                  ${idx + 1}
                </button>
              `;
            }).join('')}
          </div>
        </div>
      </div>
    `;

    // Event attachments for practice
    arena.querySelectorAll('.option-item').forEach(el => {
      el.addEventListener('click', (e) => {
        const optIdx = parseInt(e.currentTarget.dataset.optIdx, 10);
        Sound.playClick();
        this.activeEngine.selectOption(optIdx);

        // Sound on reveal in single choice
        if (!isMulti) {
          const isCorrect = q.correctAnswers && q.correctAnswers.includes(optIdx);
          if (isCorrect) Sound.playCorrect();
          else Sound.playWrong();
        }
      });
    });

    document.getElementById('btnCheckMultiAnswer')?.addEventListener('click', () => {
      this.activeEngine.revealPracticeAnswer();
      const isCorrect = this.activeEngine.isQuestionCorrect(q);
      if (isCorrect) Sound.playCorrect();
      else Sound.playWrong();
    });

    document.getElementById('btnTogglePracticeBookmark')?.addEventListener('click', () => {
      const activeStudent = Storage.getActiveStudent();
      const isNowBookmarked = Storage.toggleBookmark(q.id, activeStudent.id);
      this.showToast(isNowBookmarked ? 'Bookmarked question' : 'Removed bookmark', 'success');
      this.renderPracticeCard();
    });

    document.getElementById('btnPracticePrev')?.addEventListener('click', () => this.activeEngine.prev());
    document.getElementById('btnPracticeNext')?.addEventListener('click', () => this.activeEngine.next());
    document.getElementById('btnFinishPractice')?.addEventListener('click', () => {
      if (confirm('Finish practice session and see results?')) {
        this.activeEngine.submitExam(false);
      }
    });

    document.getElementById('btnTogglePaletteDrawer')?.addEventListener('click', () => {
      const d = document.getElementById('practicePaletteDrawer');
      if (d) d.style.display = d.style.display === 'none' ? 'block' : 'none';
    });

    arena.querySelectorAll('.palette-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const idx = parseInt(e.currentTarget.dataset.idx, 10);
        this.activeEngine.goToQuestion(idx);
      });
    });
  }

  // ==========================================================================
  // VIEW: Timed Exam Simulator
  // ==========================================================================
  startTimedExamSession({ examId = null, customQuestions = null, durationMinutes = null }) {
    let exam = examId ? Storage.getExamById(examId) : null;
    let questions = customQuestions && customQuestions.length > 0 ? [...customQuestions] : (exam ? [...exam.questions] : []);

    if (!questions || questions.length === 0) {
      this.showToast('This exam has no questions.', 'info');
      this.switchView('exams');
      return;
    }

    const dur = durationMinutes !== null && durationMinutes !== undefined
      ? durationMinutes
      : (exam && exam.defaultDuration ? exam.defaultDuration : 30);

    this.activeEngine = new ExamEngine({
      mode: 'timed',
      exam,
      questions,
      durationMinutes: dur,
      onStateChange: (state) => {
        if (state.type === 'tick') {
          this.updateExamTimerDisplay(state.remaining);
        } else {
          this.renderTimedExamCard();
        }
      },
      onComplete: (perf) => this.switchView('results', { performance: perf })
    });

    this.renderTimedExamCard();
  }

  renderTimedExamCard() {
    const arena = document.getElementById('examArena');
    if (!arena || !this.activeEngine) return;

    const q = this.activeEngine.getCurrentQuestion();
    if (!q) return;

    const total = this.activeEngine.questions.length;
    const curIdx = this.activeEngine.currentIndex;
    const userAns = this.activeEngine.userAnswers[q.id] || new Set();
    const isFlagged = this.activeEngine.isFlagged(q.id);
    const isMulti = q.questionType === 'multiple' || (q.correctAnswers && q.correctAnswers.length > 1);

    const progressPct = ((curIdx + 1) / total) * 100;

    arena.innerHTML = `
      <div class="arena-container">
        <div class="arena-topbar">
          <div class="arena-exam-info">
            <h2>⏱️ ${this.escapeHtml(this.activeEngine.exam.name)}</h2>
            <span>Question ${curIdx + 1} of ${total}</span>
          </div>

          <div class="arena-hud">
            <div class="timer-box" id="examCountdownBox">
              ⏱️ <span id="examCountdownTime">${this.formatDuration(this.activeEngine.remainingSeconds)}</span>
            </div>
            <button class="btn btn-danger btn-sm" id="btnOpenSubmitConfirm">Submit Exam</button>
          </div>
        </div>

        <div class="progress-bar-container">
          <div class="progress-bar-fill" style="width: ${progressPct}%"></div>
        </div>

        <div class="question-card">
          <div class="question-card-header">
            <div class="q-meta-group">
              <span class="q-badge">Question ${curIdx + 1}</span>
              ${q.topic ? `<span class="q-badge" style="color: var(--accent-blue)">🏷️ ${this.escapeHtml(q.topic)}</span>` : ''}
              <span class="q-badge ${isMulti ? 'type-multi' : ''}">${isMulti ? '☑️ Select all that apply' : '🔘 Select one'}</span>
            </div>
            <button class="btn btn-secondary btn-sm" id="btnToggleFlagReview" style="color: ${isFlagged ? '#F59E0B' : 'inherit'}">
              ${isFlagged ? '🚩 Flagged' : '🏳️ Flag for Review'}
            </button>
          </div>

          <h3 class="q-title">${this.escapeHtml(q.question)}</h3>

          <div class="options-list">
            ${q.options.map((optText, optIdx) => {
              const letter = String.fromCharCode(65 + optIdx);
              const isSelected = userAns.has(optIdx);

              return `
                <div class="option-item ${isSelected ? 'selected' : ''}" data-opt-idx="${optIdx}">
                  <div class="option-letter">${letter}</div>
                  <div class="option-text">${this.escapeHtml(optText)}</div>
                </div>
              `;
            }).join('')}
          </div>
        </div>

        <div class="arena-nav-bar">
          <button class="btn btn-secondary" id="btnExamPrev" ${curIdx === 0 ? 'disabled' : ''}>
            ← Previous
          </button>
          
          <div style="display: flex; gap: 0.5rem; align-items: center;">
            <button class="icon-btn" id="btnToggleExamPalette" title="Question Palette">🔢</button>
            <span style="font-size: 0.85rem; color: var(--text-muted);">${curIdx + 1} / ${total}</span>
          </div>

          <button class="btn btn-primary" id="btnExamNext" ${curIdx === total - 1 ? 'disabled' : ''}>
            Next →
          </button>
        </div>

        <div class="palette-drawer" id="examPaletteDrawer">
          <div class="palette-title">
            <span>Exam Navigator Palette</span>
            <div style="display: flex; gap: 0.85rem; font-size: 0.75rem;">
              <span><span style="color: var(--primary)">●</span> Answered</span>
              <span><span style="color: var(--text-faint)">○</span> Unanswered</span>
              <span>🚩 Flagged</span>
            </div>
          </div>
          <div class="palette-grid">
            ${this.activeEngine.questions.map((ques, idx) => {
              const isAns = this.activeEngine.isQuestionAnswered(ques.id);
              const isCur = idx === curIdx;
              const isFlg = this.activeEngine.isFlagged(ques.id);
              return `
                <button class="palette-btn ${isAns ? 'answered' : ''} ${isCur ? 'current' : ''} ${isFlg ? 'flagged' : ''}" data-idx="${idx}">
                  ${idx + 1}
                </button>
              `;
            }).join('')}
          </div>
        </div>
      </div>
    `;

    // Event attachments
    arena.querySelectorAll('.option-item').forEach(el => {
      el.addEventListener('click', (e) => {
        const optIdx = parseInt(e.currentTarget.dataset.optIdx, 10);
        Sound.playClick();
        this.activeEngine.selectOption(optIdx);
      });
    });

    document.getElementById('btnToggleFlagReview')?.addEventListener('click', () => {
      this.activeEngine.toggleFlag();
    });

    document.getElementById('btnExamPrev')?.addEventListener('click', () => this.activeEngine.prev());
    document.getElementById('btnExamNext')?.addEventListener('click', () => this.activeEngine.next());

    document.getElementById('btnToggleExamPalette')?.addEventListener('click', () => {
      const d = document.getElementById('examPaletteDrawer');
      if (d) d.style.display = d.style.display === 'none' ? 'block' : 'none';
    });

    arena.querySelectorAll('.palette-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const idx = parseInt(e.currentTarget.dataset.idx, 10);
        this.activeEngine.goToQuestion(idx);
      });
    });

    document.getElementById('btnOpenSubmitConfirm')?.addEventListener('click', () => {
      this.openSubmitConfirmModal();
    });
  }

  updateExamTimerDisplay(remaining) {
    const el = document.getElementById('examCountdownTime');
    const box = document.getElementById('examCountdownBox');
    if (el) el.textContent = this.formatDuration(remaining);
    if (box) {
      if (remaining <= 300) {
        box.classList.add('warning');
      } else {
        box.classList.remove('warning');
      }
    }
  }

  openSubmitConfirmModal() {
    if (!this.activeEngine) return;
    const total = this.activeEngine.questions.length;
    let answered = 0;
    this.activeEngine.questions.forEach(q => {
      if (this.activeEngine.isQuestionAnswered(q.id)) answered++;
    });
    const unanswered = total - answered;
    const flagged = this.activeEngine.flaggedForReview.size;

    const modal = document.getElementById('modalSubmitConfirm');
    const body = document.getElementById('submitConfirmBody');
    if (!modal || !body) return;

    body.innerHTML = `
      <p style="margin-bottom: 1.25rem;">Are you ready to submit your exam? Here is your completion summary:</p>
      <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; text-align: center; margin-bottom: 1.5rem;">
        <div style="background: var(--bg-subtle); padding: 1rem; border-radius: var(--radius-md);">
          <div style="font-size: 1.5rem; font-weight: 800; color: var(--primary);">${answered}</div>
          <div style="font-size: 0.75rem; color: var(--text-muted);">Answered</div>
        </div>
        <div style="background: var(--bg-subtle); padding: 1rem; border-radius: var(--radius-md);">
          <div style="font-size: 1.5rem; font-weight: 800; color: ${unanswered > 0 ? 'var(--danger)' : 'var(--success)'};">${unanswered}</div>
          <div style="font-size: 0.75rem; color: var(--text-muted);">Unanswered</div>
        </div>
        <div style="background: var(--bg-subtle); padding: 1rem; border-radius: var(--radius-md);">
          <div style="font-size: 1.5rem; font-weight: 800; color: #F59E0B;">${flagged}</div>
          <div style="font-size: 0.75rem; color: var(--text-muted);">Flagged</div>
        </div>
      </div>
      ${unanswered > 0 ? `<p style="color: var(--danger); font-size: 0.85rem;">⚠️ You have ${unanswered} unanswered question(s). These will be counted as incorrect.</p>` : ''}
    `;

    modal.classList.add('open');
  }

  // ==========================================================================
  // VIEW: Results & Audit Screen
  // ==========================================================================
  renderResultsScreen(perf) {
    const container = document.getElementById('resultsContainer');
    if (!container || !perf) return;

    const isPass = perf.passed;
    const scoreColor = isPass ? 'var(--success)' : 'var(--danger)';
    const scoreGlow = isPass ? 'rgba(16, 185, 129, 0.35)' : 'rgba(239, 68, 68, 0.35)';

    if (isPass) {
      Sound.playFanfare();
      ConfettiCelebration.firePassingCelebration();
    }

    const missed = (perf.missedQuestions || []);

    container.innerHTML = `
      <div style="max-width: 960px; margin: 0 auto;">
        <div class="result-card-hero">
          <div class="result-badge ${isPass ? 'pass' : 'fail'}">
            ${isPass ? '🎉 Passed' : '⚠️ Needs Practice'}
          </div>

          <div class="score-circle" style="--score-pct: ${perf.score}; --score-color: ${scoreColor}; --score-glow: ${scoreGlow};">
            <span class="score-num" style="color: ${scoreColor};">${perf.score}%</span>
            <span class="score-label">Final Score</span>
          </div>

          <h2 style="font-size: 1.5rem; font-weight: 800; margin-bottom: 0.5rem;">${this.escapeHtml(perf.examName)}</h2>
          <p style="color: var(--text-muted); font-size: 0.9rem; max-width: 500px; margin: 0 auto;">
            ${isPass 
              ? 'Outstanding performance! You successfully met and exceeded the passing threshold.' 
              : `Passing threshold is ${perf.passingPercentage}%. Review your incorrect answers below to master these concepts.`}
          </p>

          <div class="result-stats-row">
            <div class="result-stat-item">
              <span class="stat-value" style="color: var(--success);">${perf.correct}</span>
              <span class="stat-title">Correct</span>
            </div>
            <div class="result-stat-item">
              <span class="stat-value" style="color: var(--danger);">${perf.incorrect}</span>
              <span class="stat-title">Incorrect</span>
            </div>
            <div class="result-stat-item">
              <span class="stat-value" style="color: var(--text-faint);">${perf.unanswered}</span>
              <span class="stat-title">Unanswered</span>
            </div>
            <div class="result-stat-item">
              <span class="stat-value">${this.formatDuration(perf.durationSeconds)}</span>
              <span class="stat-title">Time Spent</span>
            </div>
          </div>

          <div style="display: flex; gap: 0.75rem; justify-content: center; margin-top: 2rem; flex-wrap: wrap;">
            ${missed.length > 0 ? `<button class="btn btn-outline-primary" id="btnDrillMissed">🎯 Drill Missed Questions (${missed.length})</button>` : ''}
            <button class="btn btn-secondary" id="btnRetakeExam">🔄 Retake Test</button>
            <button class="btn btn-primary" id="btnBackToCatalog">📚 Back to Catalog</button>
          </div>
        </div>

        <!-- Detailed Audit Questions -->
        <div class="page-banner" style="margin-bottom: 1.25rem;">
          <div>
            <h3 style="font-size: 1.25rem; font-weight: 800;">Detailed Question Breakdown</h3>
            <p style="color: var(--text-muted); font-size: 0.85rem;">Review each question with correct answers and explanations.</p>
          </div>
        </div>

        <div style="display: flex; flex-direction: column; gap: 1.25rem;">
          ${Object.entries(perf.questionSnapshots || {}).map(([qId, snap], idx) => {
            const isQCorrect = snap.isCorrect;
            const userAnswers = new Set(snap.userAnswers || []);
            const correctAnswers = new Set(snap.correctAnswers || []);

            return `
              <div class="question-card" style="border-left: 4px solid ${isQCorrect ? 'var(--success)' : 'var(--danger)'};">
                <div class="question-card-header">
                  <div class="q-meta-group">
                    <span class="q-badge">Question ${idx + 1}</span>
                    ${snap.topic ? `<span class="q-badge">🏷️ ${this.escapeHtml(snap.topic)}</span>` : ''}
                    <span class="q-badge" style="color: ${isQCorrect ? 'var(--success)' : 'var(--danger)'}; font-weight: 800;">
                      ${isQCorrect ? '✓ Correct' : '✗ Missed'}
                    </span>
                  </div>
                </div>

                <h4 style="font-size: 1.1rem; font-weight: 700; margin-bottom: 1.25rem;">${this.escapeHtml(snap.question)}</h4>

                <div class="options-list">
                  ${snap.options.map((optText, optIdx) => {
                    const letter = String.fromCharCode(65 + optIdx);
                    const isSelected = userAnswers.has(optIdx);
                    const isCorrect = correctAnswers.has(optIdx);

                    let itemClass = '';
                    if (isCorrect) itemClass = 'is-correct';
                    else if (isSelected && !isCorrect) itemClass = 'is-incorrect';

                    const exp = snap.optionExplanations ? snap.optionExplanations[optIdx] : null;

                    return `
                      <div class="option-item ${itemClass}">
                        <div class="option-letter">${letter}</div>
                        <div style="flex-grow: 1;">
                          <div class="option-text">${this.escapeHtml(optText)}</div>
                          ${exp ? `<div class="option-explanation-inline">💡 ${this.escapeHtml(exp)}</div>` : ''}
                        </div>
                        ${isCorrect ? '<span style="color: var(--success); font-weight: 800;">✓ Correct Key</span>' : (isSelected ? '<span style="color: var(--danger); font-weight: 800;">Your Choice</span>' : '')}
                      </div>
                    `;
                  }).join('')}
                </div>

                ${snap.explanation ? `
                  <div class="general-explanation-card">
                    <div class="explanation-header">💡 Comprehensive Rationale</div>
                    <div class="explanation-body">${this.escapeHtml(snap.explanation)}</div>
                  </div>
                ` : ''}
              </div>
            `;
          }).join('')}
        </div>
      </div>
    `;

    document.getElementById('btnDrillMissed')?.addEventListener('click', () => {
      this.switchView('practice', { customQuestions: missed, examId: perf.examId });
    });

    document.getElementById('btnRetakeExam')?.addEventListener('click', () => {
      this.switchView('exam', { examId: perf.examId });
    });

    document.getElementById('btnBackToCatalog')?.addEventListener('click', () => {
      this.switchView('exams');
    });
  }

  // ==========================================================================
  // VIEW: Question Bank Browser
  // ==========================================================================
  renderQuestionBank() {
    const listContainer = document.getElementById('qbListContainer');
    if (!listContainer) return;

    const exams = Storage.getAllExams();
    const activeStudent = Storage.getActiveStudent();
    const bookmarks = Storage.getBookmarks(activeStudent.id);

    const allQuestions = [];
    const allTopics = new Set();

    exams.forEach(exam => {
      (exam.questions || []).forEach(q => {
        allQuestions.push({ ...q, examId: exam.id, examName: exam.name });
        if (q.topic && q.topic.trim()) allTopics.add(q.topic.trim());
      });
    });

    // Populate category filter dropdown fresh every render
    const catSelect = document.getElementById('qbCategoryFilter');
    if (catSelect) {
      const currentSelected = catSelect.value;
      catSelect.innerHTML = `<option value="all">All Examinations (${allQuestions.length} questions)</option>`;
      exams.forEach(e => {
        const opt = document.createElement('option');
        opt.value = e.id;
        opt.textContent = `${e.name} (${(e.questions || []).length})`;
        if (e.id === currentSelected) opt.selected = true;
        catSelect.appendChild(opt);
      });
    }

    // Populate topic filter dropdown fresh every render
    const topicSelect = document.getElementById('qbTopicFilter');
    if (topicSelect) {
      const currentTopic = topicSelect.value;
      topicSelect.innerHTML = `<option value="all">All Topics (${allTopics.size})</option>`;
      Array.from(allTopics).sort().forEach(top => {
        const opt = document.createElement('option');
        opt.value = top;
        opt.textContent = top;
        if (top === currentTopic) opt.selected = true;
        topicSelect.appendChild(opt);
      });
    }

    const searchInput = document.getElementById('qbSearchInput')?.value.toLowerCase().trim() || '';
    const categoryFilter = catSelect?.value || 'all';
    const topicFilter = topicSelect?.value || 'all';
    const typeFilter = document.getElementById('qbTypeFilter')?.value || 'all';
    const starredOnly = document.getElementById('btnQbToggleStarred')?.classList.contains('active');

    let filtered = allQuestions.filter(q => {
      const matchSearch = !searchInput || 
                          q.question.toLowerCase().includes(searchInput) ||
                          (q.topic && q.topic.toLowerCase().includes(searchInput)) ||
                          (q.tags && q.tags.some(t => t.toLowerCase().includes(searchInput)));
      const matchExam = categoryFilter === 'all' || q.examId === categoryFilter;
      const matchTopic = topicFilter === 'all' || (q.topic && q.topic.trim() === topicFilter);

      let matchType = true;
      if (typeFilter === 'single') {
        matchType = q.questionType === 'single' || (!q.questionType && (!q.correctAnswers || q.correctAnswers.length <= 1));
      } else if (typeFilter === 'multiple') {
        matchType = q.questionType === 'multiple' || (q.correctAnswers && q.correctAnswers.length > 1);
      } else if (typeFilter === 'true_false') {
        matchType = q.questionType === 'true_false';
      }

      const matchStarred = !starredOnly || bookmarks.has(q.id);

      return matchSearch && matchExam && matchTopic && matchType && matchStarred;
    });

    if (allQuestions.length === 0) {
      listContainer.innerHTML = `
        <div style="text-align: center; padding: 4rem 1.5rem; background: var(--bg-card); border-radius: var(--radius-xl); border: 1px dashed var(--border-color);">
          <div style="font-size: 3rem; margin-bottom: 0.75rem;">🗃️</div>
          <h3 style="font-size: 1.3rem; margin-bottom: 0.5rem;">Your Question Bank is Empty</h3>
          <p style="color: var(--text-muted); margin-bottom: 1.5rem;">Add questions manually or import your study materials.</p>
          <button class="btn btn-primary" id="btnEmptyQbAdd">+ Add First Question</button>
        </div>
      `;
      document.getElementById('btnEmptyQbAdd')?.addEventListener('click', () => this.openAddQuestionModal());
      return;
    }

    if (filtered.length === 0) {
      listContainer.innerHTML = `
        <div style="text-align: center; padding: 3rem 1rem; color: var(--text-muted);">
          <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">🔍</div>
          <p>No questions matched your search criteria.</p>
        </div>
      `;
      return;
    }

    listContainer.innerHTML = filtered.map(q => {
      const isBookmarked = bookmarks.has(q.id);
      return `
        <div class="question-card" style="margin-bottom: 1rem; padding: 1.25rem;">
          <div class="question-card-header">
            <div class="q-meta-group">
              <span class="q-badge" style="color: var(--primary);">📚 ${this.escapeHtml(q.examName)}</span>
              ${q.topic ? `<span class="q-badge">🏷️ ${this.escapeHtml(q.topic)}</span>` : ''}
              <span class="q-badge">${q.questionType === 'multiple' ? '☑️ Multi' : '🔘 Single'}</span>
              <span style="font-size: 0.8rem; color: var(--text-faint);">Diff: ${'★'.repeat(q.difficulty || 3)}</span>
            </div>
            <div style="display: flex; gap: 0.35rem; align-items: center;">
              <button class="icon-btn btn-sm btn-qb-bookmark" data-id="${q.id}" title="Toggle Bookmark" style="color: ${isBookmarked ? '#F59E0B' : 'inherit'}">
                ${isBookmarked ? '⭐' : '☆'}
              </button>
              <button class="icon-btn btn-sm btn-qb-edit" data-exam-id="${q.examId}" data-q-id="${q.id}" title="Edit Question">✏️</button>
              <button class="icon-btn btn-sm btn-qb-delete" data-exam-id="${q.examId}" data-q-id="${q.id}" title="Delete Question">🗑️</button>
            </div>
          </div>
          <div style="font-weight: 700; margin-bottom: 0.75rem; font-size: 1rem;">${this.escapeHtml(q.question)}</div>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 0.5rem; font-size: 0.85rem; color: var(--text-muted);">
            ${q.options.map((opt, i) => {
              const isCorrect = q.correctAnswers && q.correctAnswers.includes(i);
              return `
                <div style="padding: 0.4rem 0.6rem; border-radius: var(--radius-sm); background: var(--bg-subtle); border: 1px solid ${isCorrect ? 'var(--success-border)' : 'var(--border-subtle)'}; color: ${isCorrect ? 'var(--success)' : 'inherit'};">
                  <strong>${String.fromCharCode(65 + i)}:</strong> ${this.escapeHtml(opt)}
                </div>
              `;
            }).join('')}
          </div>
          ${q.explanation ? `<div style="font-size: 0.8rem; color: var(--text-faint); margin-top: 0.75rem; border-top: 1px solid var(--border-subtle); padding-top: 0.5rem;">💡 ${this.escapeHtml(q.explanation)}</div>` : ''}
        </div>
      `;
    }).join('');

    listContainer.querySelectorAll('.btn-qb-bookmark').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const qId = e.currentTarget.dataset.id;
        Storage.toggleBookmark(qId, activeStudent.id);
        this.renderQuestionBank();
      });
    });

    listContainer.querySelectorAll('.btn-qb-edit').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const examId = e.currentTarget.dataset.examId;
        const qId = e.currentTarget.dataset.qId;
        this.openAddQuestionModal(examId, qId);
      });
    });

    listContainer.querySelectorAll('.btn-qb-delete').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const examId = e.currentTarget.dataset.examId;
        const qId = e.currentTarget.dataset.qId;
        if (confirm('Delete this question from examination?')) {
          Storage.deleteQuestionFromExam(examId, qId);
          this.showToast('Question deleted', 'success');
          this.renderQuestionBank();
        }
      });
    });
  }

  // ==========================================================================
  // VIEW: Practice & Exam History (Replica of Flutter History Screen)
  // ==========================================================================
  renderHistory(filter = 'all') {
    const container = document.getElementById('historyListContainer');
    if (!container) return;

    const student = Storage.getActiveStudent();
    const allPerfs = Storage.getPerformances(student.id);

    // Update active filter button
    document.querySelectorAll('.hist-filter-btn').forEach(btn => {
      if (btn.dataset.filter === filter) {
        btn.className = 'btn btn-sm btn-primary hist-filter-btn';
      } else {
        btn.className = 'btn btn-sm btn-secondary hist-filter-btn';
      }
    });

    let perfs = allPerfs;
    if (filter === 'exam') perfs = allPerfs.filter(p => p.mode === 'timed' || p.mode === 'exam');
    else if (filter === 'practice') perfs = allPerfs.filter(p => p.mode === 'practice');
    else if (filter === 'passed') perfs = allPerfs.filter(p => p.passed);
    else if (filter === 'failed') perfs = allPerfs.filter(p => !p.passed);

    if (perfs.length === 0) {
      container.innerHTML = `
        <div style="text-align: center; padding: 3.5rem 1.5rem; background: var(--bg-card); border-radius: var(--radius-xl); border: 1px dashed var(--border-color);">
          <div style="font-size: 2.75rem; margin-bottom: 0.75rem;">📜</div>
          <h3 style="font-size: 1.25rem; font-weight: 700; margin-bottom: 0.5rem;">No Attempt History Found</h3>
          <p style="color: var(--text-muted); font-size: 0.9rem; max-width: 420px; margin: 0 auto 1.5rem;">
            ${allPerfs.length === 0 ? 'You have not completed any practice sessions or exam simulations yet.' : 'No sessions match this filter criteria.'}
          </p>
          <button class="btn btn-primary" id="btnHistStartNewSession">Launch New Session</button>
        </div>
      `;
      document.getElementById('btnHistStartNewSession')?.addEventListener('click', () => {
        this.openSessionLauncherModal({ defaultMode: 'practice' });
      });
      return;
    }

    container.innerHTML = `
      <div style="display: flex; flex-direction: column; gap: 0.85rem;">
        ${perfs.map(p => {
          const isPass = p.passed;
          const isTimed = p.mode === 'timed' || p.mode === 'exam';
          const missedCount = (p.missedQuestions || []).length;
          const dateStr = new Date(p.date).toLocaleString([], {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
          });

          return `
            <div class="question-card" style="padding: 1.25rem 1.5rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 1rem; border-left: 4px solid ${isPass ? 'var(--success)' : 'var(--danger)'};">
              <div style="display: flex; flex-direction: column; gap: 0.35rem;">
                <div style="display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap;">
                  <span class="q-badge" style="font-size: 0.72rem; text-transform: uppercase;">
                    ${isTimed ? '⏱️ Timed Simulation' : '🎓 Interactive Practice'}
                  </span>
                  <span class="badge ${isPass ? 'badge-pass' : 'badge-fail'}" style="font-size: 0.72rem; padding: 0.2rem 0.55rem; border-radius: var(--radius-full);">
                    ${isPass ? 'PASSED' : 'NEEDS WORK'}
                  </span>
                  <span style="font-size: 0.78rem; color: var(--text-muted);">${dateStr}</span>
                </div>
                <h3 style="font-size: 1.15rem; font-weight: 700; margin: 0;">${this.escapeHtml(p.examName)}</h3>
                <div style="display: flex; gap: 1rem; font-size: 0.82rem; color: var(--text-muted); flex-wrap: wrap;">
                  <span>Score: <strong style="color: ${isPass ? 'var(--success)' : 'var(--danger)'}; font-size: 0.95rem;">${p.score}%</strong></span>
                  <span>Correct: <strong>${p.correct} / ${p.totalQuestions}</strong></span>
                  <span>Duration: <strong>${this.formatDuration(p.durationSeconds || 0)}</strong></span>
                  ${missedCount > 0 ? `<span style="color: var(--danger);">Missed: <strong>${missedCount} Qs</strong></span>` : ''}
                </div>
              </div>

              <div style="display: flex; gap: 0.5rem; align-items: center; flex-wrap: wrap;">
                <button class="btn btn-secondary btn-sm btn-hist-audit" data-id="${p.id}" style="font-weight: 600;">
                  🔍 Audit Breakdown
                </button>
                ${missedCount > 0 ? `
                  <button class="btn btn-warning btn-sm btn-hist-drill" data-id="${p.id}" style="font-weight: 700;">
                    🎯 Drill Mistakes (${missedCount})
                  </button>
                ` : ''}
                <button class="btn btn-primary btn-sm btn-hist-retake" data-id="${p.examId}" style="font-weight: 600;">
                  🔄 Retake
                </button>
              </div>
            </div>
          `;
        }).join('')}
      </div>
    `;

    container.querySelectorAll('.btn-hist-audit').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const id = e.currentTarget.dataset.id;
        this.openAuditModal(id);
      });
    });

    container.querySelectorAll('.btn-hist-drill').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const id = e.currentTarget.dataset.id;
        const perf = allPerfs.find(p => p.id === id);
        if (perf && perf.missedQuestions && perf.missedQuestions.length > 0) {
          this.switchView('practice', {
            examId: perf.examId,
            customQuestions: perf.missedQuestions
          });
        }
      });
    });

    container.querySelectorAll('.btn-hist-retake').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const examId = e.currentTarget.dataset.id;
        this.openSessionLauncherModal({ examId });
      });
    });
  }

  // ==========================================================================
  // MODAL: Exam Audit (Replica of Flutter ExamAuditScreen)
  // ==========================================================================
  openAuditModal(perfId) {
    const student = Storage.getActiveStudent();
    const perfs = Storage.getPerformances(student.id);
    const perf = perfs.find(p => p.id === perfId);

    if (!perf) {
      this.showToast('Performance record not found.', 'error');
      return;
    }

    this.activeAuditPerf = perf;
    this.activeAuditFilter = 'all';

    const modal = document.getElementById('modalExamAudit');
    const titleEl = document.getElementById('auditModalTitle');
    const subEl = document.getElementById('auditModalSub');
    const summaryCard = document.getElementById('auditSummaryCard');
    const mistakesBtn = document.getElementById('btnAuditPracticeMistakes');
    const retakeBtn = document.getElementById('btnAuditRetakeExam');

    if (titleEl) titleEl.textContent = `Performance Audit: ${perf.examName}`;
    if (subEl) subEl.textContent = `Attempted on ${new Date(perf.date).toLocaleString()} • Duration: ${this.formatDuration(perf.durationSeconds || 0)}`;

    const isPass = perf.passed;
    const missedCount = (perf.missedQuestions || []).length;
    const totalQ = perf.totalQuestions || 0;
    const correctQ = perf.correct || 0;
    const unansQ = perf.unanswered || 0;
    const wrongQ = Math.max(0, totalQ - correctQ - unansQ);

    if (summaryCard) {
      summaryCard.innerHTML = `
        <div style="display: flex; align-items: center; gap: 1rem;">
          <div style="font-size: 2.2rem; font-weight: 800; color: ${isPass ? 'var(--success)' : 'var(--danger)'};">
            ${perf.score}%
          </div>
          <div>
            <div style="font-weight: 700; font-size: 1.05rem;">
              <span class="badge ${isPass ? 'badge-pass' : 'badge-fail'}">${isPass ? 'PASSED' : 'NEEDS IMPROVEMENT'}</span>
            </div>
            <div style="font-size: 0.8rem; color: var(--text-muted); margin-top: 0.2rem;">
              Passing Benchmark: ${perf.passingPercentage || 75}%
            </div>
          </div>
        </div>

        <div style="display: flex; gap: 1.25rem; font-size: 0.85rem; flex-wrap: wrap;">
          <div><span style="color: var(--text-muted);">Total:</span> <strong>${totalQ}</strong></div>
          <div><span style="color: var(--success);">Correct:</span> <strong>${correctQ}</strong></div>
          <div><span style="color: var(--danger);">Incorrect:</span> <strong>${wrongQ}</strong></div>
          <div><span style="color: var(--text-muted);">Skipped:</span> <strong>${unansQ}</strong></div>
        </div>
      `;
    }

    if (mistakesBtn) {
      if (missedCount > 0) {
        mistakesBtn.style.display = 'inline-flex';
        mistakesBtn.textContent = `🎯 Practice ${missedCount} Mistakes`;
        mistakesBtn.onclick = () => {
          modal.classList.remove('open');
          this.switchView('practice', {
            examId: perf.examId,
            customQuestions: perf.missedQuestions
          });
        };
      } else {
        mistakesBtn.style.display = 'none';
      }
    }

    if (retakeBtn) {
      retakeBtn.onclick = () => {
        modal.classList.remove('open');
        this.openSessionLauncherModal({ examId: perf.examId });
      };
    }

    // Set filter pills active state
    document.querySelectorAll('.audit-filter-pill').forEach(btn => {
      btn.className = btn.dataset.auditFilter === 'all' ? 'btn btn-sm btn-primary audit-filter-pill' : 'btn btn-sm btn-secondary audit-filter-pill';
    });

    this.renderAuditQuestionsList('all');
    modal?.classList.add('open');
  }

  renderAuditQuestionsList(filter = 'all') {
    const container = document.getElementById('auditQuestionsList');
    if (!container || !this.activeAuditPerf) return;

    this.activeAuditFilter = filter;
    const perf = this.activeAuditPerf;
    const snapshots = perf.questionSnapshots || {};
    const student = Storage.getActiveStudent();
    const bookmarks = Storage.getBookmarks(student.id);

    let items = Object.values(snapshots);

    if (filter === 'correct') {
      items = items.filter(s => s.isCorrect);
    } else if (filter === 'incorrect') {
      items = items.filter(s => !s.isCorrect && s.userAnswers && s.userAnswers.length > 0);
    } else if (filter === 'unanswered') {
      items = items.filter(s => !s.userAnswers || s.userAnswers.length === 0);
    }

    if (items.length === 0) {
      container.innerHTML = `
        <div style="text-align: center; padding: 2rem; color: var(--text-muted);">
          No questions in this filter view.
        </div>
      `;
      return;
    }

    container.innerHTML = items.map((snap, idx) => {
      const isCorrect = snap.isCorrect;
      const userAnswers = new Set(snap.userAnswers || []);
      const correctAnswers = new Set(snap.correctAnswers || []);
      const isUnanswered = userAnswers.size === 0;
      const isBookmarked = bookmarks.has(snap.id);

      return `
        <div class="question-card" style="padding: 1.15rem; border-left: 4px solid ${isCorrect ? 'var(--success)' : (isUnanswered ? 'var(--text-muted)' : 'var(--danger)')};">
          <div class="question-card-header" style="margin-bottom: 0.65rem;">
            <div class="q-meta-group">
              <span class="q-badge" style="font-weight: 700;">Question #${idx + 1}</span>
              ${snap.topic ? `<span class="q-badge">🏷️ ${this.escapeHtml(snap.topic)}</span>` : ''}
              <span class="q-badge" style="font-weight: 700; color: ${isCorrect ? 'var(--success)' : (isUnanswered ? 'var(--text-muted)' : 'var(--danger)')};">
                ${isCorrect ? '✓ Correct' : (isUnanswered ? '⚪ Skipped' : '✗ Missed')}
              </span>
            </div>
            <button class="icon-btn btn-sm btn-audit-bookmark" data-id="${snap.id}" title="Toggle Bookmark" style="color: ${isBookmarked ? '#F59E0B' : 'inherit'};">
              ${isBookmarked ? '⭐' : '☆'}
            </button>
          </div>

          <div style="font-weight: 700; font-size: 0.98rem; margin-bottom: 0.85rem; line-height: 1.45;">
            ${this.escapeHtml(snap.question)}
          </div>

          <div class="options-list" style="gap: 0.45rem;">
            ${(snap.options || []).map((optText, optIdx) => {
              const letter = String.fromCharCode(65 + optIdx);
              const isUserChoice = userAnswers.has(optIdx);
              const isKey = correctAnswers.has(optIdx);

              let itemClass = '';
              if (isKey) itemClass = 'is-correct';
              else if (isUserChoice && !isKey) itemClass = 'is-incorrect';

              const exp = snap.optionExplanations ? snap.optionExplanations[optIdx] : null;

              return `
                <div class="option-item ${itemClass}" style="padding: 0.55rem 0.85rem; font-size: 0.86rem;">
                  <div class="option-letter" style="width: 24px; height: 24px; font-size: 0.78rem;">${letter}</div>
                  <div style="flex-grow: 1;">
                    <div class="option-text">${this.escapeHtml(optText)}</div>
                    ${exp ? `<div class="option-explanation-inline" style="font-size: 0.78rem; margin-top: 0.3rem;">💡 ${this.escapeHtml(exp)}</div>` : ''}
                  </div>
                  <div style="font-size: 0.78rem; font-weight: 700;">
                    ${isKey ? '<span style="color: var(--success);">✓ Correct Key</span>' : ''}
                    ${isUserChoice && !isKey ? '<span style="color: var(--danger);">Your Choice</span>' : ''}
                  </div>
                </div>
              `;
            }).join('')}
          </div>

          ${snap.explanation ? `
            <div class="general-explanation-card" style="margin-top: 0.75rem; padding: 0.65rem 0.85rem; font-size: 0.82rem;">
              <div class="explanation-header" style="font-size: 0.82rem; margin-bottom: 0.25rem;">💡 Explanation</div>
              <div class="explanation-body">${this.escapeHtml(snap.explanation)}</div>
            </div>
          ` : ''}
        </div>
      `;
    }).join('');

    container.querySelectorAll('.btn-audit-bookmark').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const qId = e.currentTarget.dataset.id;
        Storage.toggleBookmark(qId, student.id);
        this.renderAuditQuestionsList(this.activeAuditFilter);
      });
    });
  }

  // ==========================================================================
  // MODAL: Session Launcher & Configuration (Replica of Flutter TakeExamScreen)
  // ==========================================================================
  openSessionLauncherModal({ examId = null, defaultMode = 'practice', onlyStarred = false } = {}) {
    const modal = document.getElementById('modalSessionLauncher');
    if (!modal) return;

    const exams = Storage.getAllExams();
    const examSelect = document.getElementById('launcherExamSelect');
    
    if (examSelect) {
      examSelect.innerHTML = exams.map(e => `
        <option value="${e.id}" ${e.id === examId ? 'selected' : ''}>
          ${this.escapeHtml(e.name)} (${(e.questions || []).length} Qs)
        </option>
      `).join('');

      if (!examId && exams.length > 0) {
        examSelect.value = exams[0].id;
      }
    }

    // Set Mode
    this.launcherMode = defaultMode;
    this.updateLauncherModeUI(defaultMode);

    // Refresh Topics
    const activeExamId = examSelect ? examSelect.value : examId;
    this.refreshLauncherTopics(activeExamId);

    // Reset filters
    const diffSelect = document.getElementById('launcherDifficultySelect');
    if (diffSelect) diffSelect.value = 'ALL';

    const typeSelect = document.getElementById('launcherTypeSelect');
    if (typeSelect) typeSelect.value = 'ALL';

    const starredToggle = document.getElementById('launcherStarredToggle');
    if (starredToggle) starredToggle.checked = !!onlyStarred;

    // Reset Question Count Pills
    document.querySelectorAll('#launcherCountPills .count-pill').forEach(btn => {
      btn.className = btn.dataset.count === 'all' ? 'btn btn-sm btn-primary count-pill active' : 'btn btn-sm btn-secondary count-pill';
    });
    const customCountWrap = document.getElementById('launcherCustomCountWrapper');
    if (customCountWrap) customCountWrap.style.display = 'none';

    // Reset Duration Pills according to mode
    this.updateLauncherDurationPillsUI();

    // Availability update
    this.updateLauncherAvailability();

    modal.classList.add('open');
  }

  updateLauncherModeUI(mode) {
    this.launcherMode = mode;
    const btnPractice = document.getElementById('btnModePractice');
    const btnExam = document.getElementById('btnModeExam');
    const modeBadge = document.getElementById('sessionModeIndicator');

    if (mode === 'practice') {
      btnPractice?.classList.add('active');
      btnExam?.classList.remove('active');
      if (modeBadge) {
        modeBadge.textContent = 'Interactive Practice';
        modeBadge.style.background = 'rgba(99, 102, 241, 0.15)';
        modeBadge.style.color = '#818CF8';
      }
    } else {
      btnExam?.classList.add('active');
      btnPractice?.classList.remove('active');
      if (modeBadge) {
        modeBadge.textContent = 'Timed Examination';
        modeBadge.style.background = 'rgba(245, 158, 11, 0.15)';
        modeBadge.style.color = '#F59E0B';
      }
    }

    this.updateLauncherDurationPillsUI();
  }

  updateLauncherDurationPillsUI() {
    const isExam = this.launcherMode === 'exam';
    const examSelect = document.getElementById('launcherExamSelect');
    const examId = examSelect ? examSelect.value : null;
    const exam = examId ? Storage.getExamById(examId) : null;
    const defaultExamDur = exam && exam.defaultDuration ? exam.defaultDuration : 30;

    const targetDuration = isExam ? (defaultExamDur || 30).toString() : '0';

    document.querySelectorAll('#launcherDurationPills .duration-pill').forEach(btn => {
      if (btn.dataset.duration === targetDuration) {
        btn.className = 'btn btn-sm btn-primary duration-pill active';
      } else {
        btn.className = 'btn btn-sm btn-secondary duration-pill';
      }
    });

    const customDurWrap = document.getElementById('launcherCustomDurationWrapper');
    if (customDurWrap) customDurWrap.style.display = 'none';

    const durLabel = document.getElementById('launcherDurationLabel');
    if (durLabel) {
      durLabel.textContent = isExam ? `Recommended: ${defaultExamDur} Min` : 'Practice is typically untimed';
    }
  }

  refreshLauncherTopics(examId) {
    const topicSelect = document.getElementById('launcherTopicSelect');
    if (!topicSelect) return;

    const exam = Storage.getExamById(examId);
    const questions = exam ? (exam.questions || []) : [];
    const topics = new Set();
    questions.forEach(q => {
      if (q.topic && q.topic.trim()) topics.add(q.topic.trim());
    });

    topicSelect.innerHTML = `<option value="ALL">All Topics (${topics.size} discovered)</option>` +
      Array.from(topics).sort().map(t => `<option value="${this.escapeHtml(t)}">${this.escapeHtml(t)}</option>`).join('');
  }

  updateLauncherAvailability() {
    const banner = document.getElementById('launcherAvailabilityBanner');
    const examSelect = document.getElementById('launcherExamSelect');
    const topicSelect = document.getElementById('launcherTopicSelect');
    const diffSelect = document.getElementById('launcherDifficultySelect');
    const typeSelect = document.getElementById('launcherTypeSelect');
    const starredToggle = document.getElementById('launcherStarredToggle');

    if (!banner || !examSelect) return;

    const exam = Storage.getExamById(examSelect.value);
    if (!exam || !exam.questions) {
      banner.style.background = 'rgba(239, 68, 68, 0.1)';
      banner.style.color = '#EF4444';
      banner.innerHTML = '⚠️ No questions found in this examination track.';
      return;
    }

    const student = Storage.getActiveStudent();
    const bookmarks = Storage.getBookmarks(student.id);

    const chosenTopic = topicSelect ? topicSelect.value : 'ALL';
    const chosenDiff = diffSelect ? diffSelect.value : 'ALL';
    const chosenType = typeSelect ? typeSelect.value : 'ALL';
    const isStarred = starredToggle ? starredToggle.checked : false;

    const matched = exam.questions.filter(q => {
      if (isStarred && !bookmarks.has(q.id)) return false;
      if (chosenTopic !== 'ALL' && (!q.topic || q.topic.trim() !== chosenTopic)) return false;
      
      if (chosenDiff !== 'ALL') {
        const d = q.difficulty || 3;
        if (chosenDiff === 'easy' && d > 2) return false;
        if (chosenDiff === 'medium' && (d < 3 || d > 4)) return false;
        if (chosenDiff === 'hard' && d < 5) return false;
      }

      if (chosenType !== 'ALL') {
        if (chosenType === 'single') {
          const isSingle = q.questionType === 'single' || (!q.questionType && (!q.correctAnswers || q.correctAnswers.length <= 1));
          if (!isSingle) return false;
        } else if (chosenType === 'multiple') {
          const isMulti = q.questionType === 'multiple' || (q.correctAnswers && q.correctAnswers.length > 1);
          if (!isMulti) return false;
        } else if (chosenType === 'true_false') {
          if (q.questionType !== 'true_false') return false;
        }
      }

      return true;
    });

    const count = matched.length;
    const badge = document.getElementById('launcherCountBadge');
    if (badge) badge.textContent = `${count} questions match your filter`;

    if (count === 0) {
      banner.style.background = 'rgba(239, 68, 68, 0.1)';
      banner.style.color = '#EF4444';
      banner.innerHTML = `⚠️ <strong>0 Questions Available:</strong> Try broadening your filters or turning off "Bookmarked Questions Only".`;
    } else {
      banner.style.background = 'rgba(16, 185, 129, 0.12)';
      banner.style.color = '#10B981';
      banner.innerHTML = `✓ <strong>${count} Questions Ready:</strong> Tailored session matching all criteria.`;
    }
  }

  executeLaunchSession() {
    const examSelect = document.getElementById('launcherExamSelect');
    const topicSelect = document.getElementById('launcherTopicSelect');
    const diffSelect = document.getElementById('launcherDifficultySelect');
    const typeSelect = document.getElementById('launcherTypeSelect');
    const starredToggle = document.getElementById('launcherStarredToggle');
    const shuffleQ = document.getElementById('launcherShuffleQuestions')?.checked ?? true;
    const shuffleOpt = document.getElementById('launcherShuffleOptions')?.checked ?? true;

    if (!examSelect) return;
    const examId = examSelect.value;
    const exam = Storage.getExamById(examId);

    if (!exam || !exam.questions || exam.questions.length === 0) {
      this.showToast('Selected exam has no questions.', 'error');
      return;
    }

    const student = Storage.getActiveStudent();
    const bookmarks = Storage.getBookmarks(student.id);

    const chosenTopic = topicSelect ? topicSelect.value : 'ALL';
    const chosenDiff = diffSelect ? diffSelect.value : 'ALL';
    const chosenType = typeSelect ? typeSelect.value : 'ALL';
    const isStarred = starredToggle ? starredToggle.checked : false;

    let matched = exam.questions.filter(q => {
      if (isStarred && !bookmarks.has(q.id)) return false;
      if (chosenTopic !== 'ALL' && (!q.topic || q.topic.trim() !== chosenTopic)) return false;
      
      if (chosenDiff !== 'ALL') {
        const d = q.difficulty || 3;
        if (chosenDiff === 'easy' && d > 2) return false;
        if (chosenDiff === 'medium' && (d < 3 || d > 4)) return false;
        if (chosenDiff === 'hard' && d < 5) return false;
      }

      if (chosenType !== 'ALL') {
        if (chosenType === 'single') {
          const isSingle = q.questionType === 'single' || (!q.questionType && (!q.correctAnswers || q.correctAnswers.length <= 1));
          if (!isSingle) return false;
        } else if (chosenType === 'multiple') {
          const isMulti = q.questionType === 'multiple' || (q.correctAnswers && q.correctAnswers.length > 1);
          if (!isMulti) return false;
        } else if (chosenType === 'true_false') {
          if (q.questionType !== 'true_false') return false;
        }
      }

      return true;
    });

    if (matched.length === 0) {
      this.showToast('No questions match your filter criteria.', 'error');
      return;
    }

    // Question count limit
    const activeCountBtn = document.querySelector('#launcherCountPills .count-pill.active');
    const countVal = activeCountBtn ? activeCountBtn.dataset.count : 'all';
    let targetCount = matched.length;

    if (countVal === 'custom') {
      const customVal = parseInt(document.getElementById('launcherCustomCountInput')?.value, 10);
      if (!isNaN(customVal) && customVal > 0) {
        targetCount = Math.min(customVal, matched.length);
      }
    } else if (countVal !== 'all') {
      const parsed = parseInt(countVal, 10);
      if (!isNaN(parsed) && parsed > 0) {
        targetCount = Math.min(parsed, matched.length);
      }
    }

    // Shuffling questions
    let finalQuestions = matched.map(q => JSON.parse(JSON.stringify(q)));
    if (shuffleQ) {
      for (let i = finalQuestions.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [finalQuestions[i], finalQuestions[j]] = [finalQuestions[j], finalQuestions[i]];
      }
    }

    // Slice to target count
    finalQuestions = finalQuestions.slice(0, targetCount);

    // Shuffling options if requested (preserving correct answer mapping)
    if (shuffleOpt) {
      finalQuestions = finalQuestions.map(q => {
        if (!q.options || q.options.length <= 1) return q;
        const correctSet = new Set(q.correctAnswers || []);
        const indexedOptions = q.options.map((opt, idx) => ({
          text: opt,
          isCorrect: correctSet.has(idx),
          explanation: q.optionExplanations ? q.optionExplanations[idx] : null
        }));

        for (let i = indexedOptions.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [indexedOptions[i], indexedOptions[j]] = [indexedOptions[j], indexedOptions[i]];
        }

        const newOptions = indexedOptions.map(o => o.text);
        const newCorrectAnswers = [];
        const newOptionExplanations = [];
        indexedOptions.forEach((o, newIdx) => {
          if (o.isCorrect) newCorrectAnswers.push(newIdx);
          if (o.explanation) newOptionExplanations[newIdx] = o.explanation;
        });

        return {
          ...q,
          options: newOptions,
          correctAnswers: newCorrectAnswers,
          optionExplanations: newOptionExplanations.length > 0 ? newOptionExplanations : q.optionExplanations
        };
      });
    }

    // Duration limit
    const activeDurBtn = document.querySelector('#launcherDurationPills .duration-pill.active');
    const durVal = activeDurBtn ? activeDurBtn.dataset.duration : '0';
    let targetDuration = 0;

    if (durVal === 'custom') {
      const customVal = parseInt(document.getElementById('launcherCustomDurationInput')?.value, 10);
      if (!isNaN(customVal) && customVal > 0) targetDuration = customVal;
    } else {
      const parsed = parseInt(durVal, 10);
      if (!isNaN(parsed) && parsed > 0) targetDuration = parsed;
    }

    // Close launcher modal
    document.getElementById('modalSessionLauncher')?.classList.remove('open');

    // Launch Session
    if (this.launcherMode === 'exam') {
      this.switchView('exam', {
        examId,
        customQuestions: finalQuestions,
        durationMinutes: targetDuration > 0 ? targetDuration : (exam.defaultDuration || 30)
      });
    } else {
      this.switchView('practice', {
        examId,
        customQuestions: finalQuestions,
        durationMinutes: targetDuration
      });
    }
  }

  // ==========================================================================
  // VIEW: Analytics & History
  // ==========================================================================
  renderAnalytics() {
    const student = Storage.getActiveStudent();
    const perfs = Storage.getPerformances(student.id);

    const totalTests = perfs.length;
    const passedTests = perfs.filter(p => p.passed).length;
    const avgScore = totalTests > 0 ? Math.round(perfs.reduce((acc, p) => acc + (p.score || 0), 0) / totalTests) : 0;
    const passRate = totalTests > 0 ? Math.round((passedTests / totalTests) * 100) : 0;

    const totalEl = document.getElementById('statTotalExams');
    const passRateEl = document.getElementById('statPassRate');
    const avgScoreEl = document.getElementById('statAvgScore');
    const tableBody = document.getElementById('analyticsHistoryTableBody');

    if (totalEl) totalEl.textContent = totalTests;
    if (passRateEl) passRateEl.textContent = `${passRate}%`;
    if (avgScoreEl) avgScoreEl.textContent = `${avgScore}%`;

    if (tableBody) {
      if (perfs.length === 0) {
        tableBody.innerHTML = `<tr><td colspan="6" style="text-align: center; color: var(--text-muted); padding: 2.5rem;">No exam attempts recorded yet. Start practicing or take a timed test to track analytics.</td></tr>`;
      } else {
        tableBody.innerHTML = perfs.map(p => {
          const dateStr = new Date(p.date).toLocaleDateString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
          return `
            <tr>
              <td><strong>${this.escapeHtml(p.examName)}</strong></td>
              <td>${dateStr}</td>
              <td><span style="font-weight: 700; color: ${p.passed ? 'var(--success)' : 'var(--danger)'};">${p.score}%</span></td>
              <td>${p.correct} / ${p.totalQuestions}</td>
              <td>${this.formatDuration(p.durationSeconds)}</td>
              <td><span class="q-badge" style="color: ${p.passed ? 'var(--success)' : 'var(--danger)'};">${p.passed ? 'PASSED' : 'FAILED'}</span></td>
            </tr>
          `;
        }).join('');
      }
    }
  }

  // ==========================================================================
  // VIEW: Settings & Profile Management
  // ==========================================================================
  renderSettings() {
    const student = Storage.getActiveStudent();
    const students = Storage.getStudents();
    const listEl = document.getElementById('settingsProfilesList');

    if (listEl) {
      listEl.innerHTML = students.map(s => {
        const isActive = s.id === student.id;
        return `
          <div style="display: flex; align-items: center; justify-content: space-between; padding: 0.85rem 1rem; border-radius: var(--radius-md); background: var(--bg-subtle); border: 1px solid ${isActive ? 'var(--primary)' : 'var(--border-color)'}; margin-bottom: 0.6rem;">
            <div style="display: flex; align-items: center; gap: 0.75rem;">
              <span style="font-size: 1.4rem;">${s.avatarEmoji || '🎓'}</span>
              <div>
                <div style="font-weight: 700;">${this.escapeHtml(s.name)} ${isActive ? '<span class="brand-badge" style="font-size: 0.65rem;">Active</span>' : ''}</div>
                <div style="font-size: 0.75rem; color: var(--text-muted);">Created ${new Date(s.createdAt).toLocaleDateString()}</div>
              </div>
            </div>
            <div style="display: flex; gap: 0.4rem; align-items: center;">
              ${!isActive ? `<button class="btn btn-secondary btn-sm btn-activate-profile" data-id="${s.id}">Switch</button>` : ''}
              <button class="icon-btn btn-sm btn-edit-profile" data-id="${s.id}" title="Edit Profile">✏️</button>
              ${students.length > 1 ? `<button class="icon-btn btn-sm btn-delete-profile" data-id="${s.id}" title="Delete Profile">🗑️</button>` : ''}
            </div>
          </div>
        `;
      }).join('');

      listEl.querySelectorAll('.btn-activate-profile').forEach(btn => {
        btn.addEventListener('click', (e) => {
          const id = e.currentTarget.dataset.id;
          Storage.setActiveStudentId(id);
          this.renderHeaderInfo();
          this.renderSettings();
          this.showToast('Profile activated', 'success');
        });
      });

      listEl.querySelectorAll('.btn-edit-profile').forEach(btn => {
        btn.addEventListener('click', (e) => {
          const id = e.currentTarget.dataset.id;
          this.openStudentProfileModal(id);
        });
      });

      listEl.querySelectorAll('.btn-delete-profile').forEach(btn => {
        btn.addEventListener('click', (e) => {
          const id = e.currentTarget.dataset.id;
          if (confirm('Delete this profile and its records?')) {
            try {
              Storage.deleteStudent(id);
              this.renderHeaderInfo();
              this.renderSettings();
              this.showToast('Profile deleted', 'success');
            } catch (err) {
              alert(err.message);
            }
          }
        });
      });
    }

    // Render Supabase Cloud Settings
    const supabaseCfg = Supabase.getConfig();
    const urlInput = document.getElementById('supabaseInputUrl');
    const keyInput = document.getElementById('supabaseInputKey');
    const statusBadge = document.getElementById('supabaseStatusBadge');

    if (urlInput) urlInput.value = supabaseCfg.url || '';
    if (keyInput) keyInput.value = supabaseCfg.anonKey || '';
    if (statusBadge) {
      if (Supabase.isConfigured()) {
        statusBadge.textContent = '🟢 Cloud Connected';
        statusBadge.style.background = 'rgba(16, 185, 129, 0.15)';
        statusBadge.style.color = '#10B981';
      } else {
        statusBadge.textContent = '⚪ Local Mode';
        statusBadge.style.background = 'rgba(100, 116, 139, 0.2)';
        statusBadge.style.color = 'var(--text-muted)';
      }
    }
  }

  // ==========================================================================
  // AUTHENTICATION MODAL & LOGIC
  // ==========================================================================
  openAuthModal(tab = 'login') {
    const modal = document.getElementById('modalAuth');
    if (!modal) return;
    this.setAuthAlert(null);
    this.switchAuthTab(tab);
    modal.classList.add('open');
  }

  setAuthAlert(message, type = 'error') {
    const alertBox = document.getElementById('authAlertBox');
    if (!alertBox) return;
    if (!message) {
      alertBox.style.display = 'none';
      alertBox.textContent = '';
      return;
    }
    alertBox.className = `auth-alert ${type}`;
    alertBox.textContent = message;
    alertBox.style.display = 'flex';
  }

  switchAuthTab(tab) {
    this.setAuthAlert(null);
    const btnLogin = document.getElementById('btnAuthTabLogin');
    const btnReg = document.getElementById('btnAuthTabRegister');
    const formLogin = document.getElementById('formAuthLogin');
    const formReg = document.getElementById('formAuthRegister');
    const title = document.getElementById('authModalTitle');

    if (tab === 'login') {
      btnLogin?.classList.add('active');
      btnReg?.classList.remove('active');
      if (formLogin) formLogin.style.display = 'block';
      if (formReg) formReg.style.display = 'none';
      if (title) title.textContent = 'Welcome Back to QuizPro';
    } else {
      btnReg?.classList.add('active');
      btnLogin?.classList.remove('active');
      if (formReg) formReg.style.display = 'block';
      if (formLogin) formLogin.style.display = 'none';
      if (title) title.textContent = 'Create Your Free Account';
    }
  }

  // ==========================================================================
  // MODALS
  // ==========================================================================

  // --- Add / Edit Question Modal ---
  openAddQuestionModal(examId = null, questionId = null) {
    const exams = Storage.getAllExams();
    if (exams.length === 0) {
      this.showToast('Please create an examination first before adding questions.', 'info');
      this.openAddExamModal();
      return;
    }

    const modal = document.getElementById('modalAddQuestion');
    const select = document.getElementById('qInputExamSelect');
    const titleEl = document.getElementById('addQuestionModalTitle');
    const editIdInput = document.getElementById('qEditId');
    const editExamInput = document.getElementById('qEditExamId');
    const textInput = document.getElementById('qInputText');
    const typeSelect = document.getElementById('qInputType');
    const diffSelect = document.getElementById('qInputDifficulty');
    const topicInput = document.getElementById('qInputTopic');
    const tagsInput = document.getElementById('qInputTags');
    const optA = document.getElementById('qOptA');
    const optB = document.getElementById('qOptB');
    const optC = document.getElementById('qOptC');
    const optD = document.getElementById('qOptD');
    const expInput = document.getElementById('qInputExplanation');
    const checkBoxes = document.querySelectorAll('.q-correct-check');

    // Populate exam choices
    select.innerHTML = exams.map(e => `<option value="${e.id}">${this.escapeHtml(e.name)}</option>`).join('');

    if (examId) select.value = examId;

    if (questionId && examId) {
      const exam = Storage.getExamById(examId);
      const q = exam?.questions.find(item => item.id === questionId);
      if (q) {
        titleEl.textContent = 'Edit Question';
        editIdInput.value = q.id;
        editExamInput.value = examId;
        textInput.value = q.question;
        typeSelect.value = q.questionType || 'single';
        diffSelect.value = q.difficulty || 3;
        topicInput.value = q.topic || '';
        tagsInput.value = (q.tags || []).join(', ');
        optA.value = q.options[0] || '';
        optB.value = q.options[1] || '';
        optC.value = q.options[2] || '';
        optD.value = q.options[3] || '';
        expInput.value = q.explanation || (q.optionExplanations ? Object.values(q.optionExplanations)[0] : '');

        checkBoxes.forEach(cb => {
          const val = parseInt(cb.value, 10);
          cb.checked = (q.correctAnswers || []).includes(val);
        });

        modal.classList.add('open');
        return;
      }
    }

    // New Question state
    titleEl.textContent = '+ Add Question';
    editIdInput.value = '';
    editExamInput.value = '';
    textInput.value = '';
    typeSelect.value = 'single';
    diffSelect.value = '3';
    topicInput.value = '';
    tagsInput.value = '';
    optA.value = '';
    optB.value = '';
    optC.value = '';
    optD.value = '';
    expInput.value = '';

    checkBoxes.forEach((cb, idx) => {
      cb.checked = (idx === 0);
    });

    modal.classList.add('open');
  }

  handleSaveQuestion() {
    const qId = document.getElementById('qEditId').value;
    const examId = document.getElementById('qInputExamSelect').value;
    const text = document.getElementById('qInputText').value.trim();

    if (!text) {
      alert('Please enter question prompt.');
      return;
    }

    const optA = document.getElementById('qOptA').value.trim();
    const optB = document.getElementById('qOptB').value.trim();
    const optC = document.getElementById('qOptC').value.trim();
    const optD = document.getElementById('qOptD').value.trim();

    const options = [optA, optB];
    if (optC) options.push(optC);
    if (optD) options.push(optD);

    if (!optA || !optB) {
      alert('Please provide at least Option A and Option B.');
      return;
    }

    const correctAnswers = [];
    document.querySelectorAll('.q-correct-check:checked').forEach(cb => {
      const idx = parseInt(cb.value, 10);
      if (idx < options.length) correctAnswers.push(idx);
    });

    if (correctAnswers.length === 0) {
      alert('Please check at least one correct answer.');
      return;
    }

    const type = document.getElementById('qInputType').value;
    const difficulty = parseInt(document.getElementById('qInputDifficulty').value, 10);
    const topic = document.getElementById('qInputTopic').value.trim();
    const tagsRaw = document.getElementById('qInputTags').value.trim();
    const tags = tagsRaw ? tagsRaw.split(/[,;]/).map(t => t.trim()).filter(Boolean) : [];
    const explanation = document.getElementById('qInputExplanation').value.trim();

    const qData = {
      id: qId || undefined,
      question: text,
      questionType: type,
      options,
      correctAnswers,
      topic,
      difficulty,
      tags,
      explanation,
      optionExplanations: explanation ? { [correctAnswers[0]]: explanation } : {}
    };

    if (qId) {
      Storage.updateQuestionInExam(examId, qId, qData);
      this.showToast('Question updated', 'success');
    } else {
      Storage.addQuestionToExam(examId, qData);
      this.showToast('Question added to exam', 'success');
    }

    document.getElementById('modalAddQuestion')?.classList.remove('open');
    this.renderDashboard();
    this.renderExamsCatalog();
    this.renderQuestionBank();
  }

  // --- Student Profile Modal ---
  openStudentProfileModal(studentId = null) {
    const modal = document.getElementById('modalStudentProfile');
    const titleEl = document.getElementById('studentProfileModalTitle');
    const idInput = document.getElementById('profileEditId');
    const nameInput = document.getElementById('profileInputName');
    const emojiInput = document.getElementById('profileInputEmoji');

    if (!modal) return;

    if (studentId) {
      const student = Storage.getStudents().find(s => s.id === studentId);
      if (student) {
        titleEl.textContent = 'Edit Profile';
        idInput.value = student.id;
        nameInput.value = student.name;
        emojiInput.value = student.avatarEmoji || '🎓';
      }
    } else {
      titleEl.textContent = 'Create Student Profile';
      idInput.value = '';
      nameInput.value = '';
      emojiInput.value = '🎓';
    }

    document.querySelectorAll('.emoji-choice').forEach(btn => {
      btn.style.borderColor = (btn.dataset.emoji === emojiInput.value) ? 'var(--primary)' : 'var(--border-color)';
    });

    modal.classList.add('open');
  }

  handleSaveStudentProfile() {
    const id = document.getElementById('profileEditId').value;
    const name = document.getElementById('profileInputName').value.trim();
    const avatarEmoji = document.getElementById('profileInputEmoji').value || '🎓';

    if (!name) {
      alert('Please enter student name.');
      return;
    }

    if (id) {
      Storage.saveStudent({ id, name, avatarEmoji });
      Auth.updateProfile({ name, avatarEmoji });
    } else {
      Storage.saveStudent({ name, avatarEmoji });
    }

    document.getElementById('modalStudentProfile')?.classList.remove('open');
    this.renderHeaderInfo();
    this.renderSettings();
    this.showToast('Profile saved successfully', 'success');
  }

  // --- Import Modal ---
  openImportModal(targetExamId = null) {
    const modal = document.getElementById('modalImport');
    const select = document.getElementById('importTargetExamSelect');
    if (!modal) return;

    const exams = Storage.getAllExams();
    select.innerHTML = `
      <option value="NEW">✨ Create New Exam From File</option>
      ${exams.map(e => `<option value="${e.id}">Append to: ${this.escapeHtml(e.name)}</option>`).join('')}
    `;

    if (targetExamId && exams.some(e => e.id === targetExamId)) {
      select.value = targetExamId;
    } else {
      select.value = 'NEW';
    }

    document.getElementById('importPreviewArea').style.display = 'none';
    document.getElementById('btnConfirmImport').style.display = 'none';
    document.getElementById('importPasteTextarea').value = '';
    const fileBadge = document.getElementById('importFileBadge');
    if (fileBadge) fileBadge.textContent = '';
    const dropzoneTitle = document.getElementById('importDropzoneTitle');
    if (dropzoneTitle) dropzoneTitle.textContent = 'Drag & Drop CSV or Excel (.xlsx) file here';
    const dropzoneSub = document.getElementById('importDropzoneSubtitle');
    if (dropzoneSub) dropzoneSub.textContent = 'or click to browse from your device';
    this.importPreviewData = null;

    modal.classList.add('open');
  }

  openAddExamModal(examId = null) {
    const modal = document.getElementById('modalAddExam');
    if (!modal) return;

    const titleEl = document.getElementById('addExamModalTitle');
    const idInput = document.getElementById('examInputId');
    const nameInput = document.getElementById('examInputName');
    const categoryInput = document.getElementById('examInputCategory');
    const providerInput = document.getElementById('examInputProvider');
    const codeInput = document.getElementById('examInputCode');
    const durationInput = document.getElementById('examInputDuration');
    const passingInput = document.getElementById('examInputPassing');
    const descInput = document.getElementById('examInputDesc');

    if (examId) {
      const exam = Storage.getExamById(examId);
      if (exam) {
        titleEl.textContent = 'Edit Examination';
        idInput.value = exam.id;
        nameInput.value = exam.name;
        categoryInput.value = exam.category || '';
        providerInput.value = exam.provider || '';
        codeInput.value = exam.code || '';
        durationInput.value = exam.defaultDuration !== undefined ? exam.defaultDuration : 30;
        passingInput.value = exam.passingPercentage || 75;
        descInput.value = exam.description || '';
      }
    } else {
      titleEl.textContent = 'Create New Examination';
      idInput.value = '';
      nameInput.value = '';
      categoryInput.value = 'General';
      providerInput.value = '';
      codeInput.value = '';
      durationInput.value = 30;
      passingInput.value = 75;
      descInput.value = '';
    }

    modal.classList.add('open');
  }

  handleSaveExam() {
    const id = document.getElementById('examInputId').value;
    const name = document.getElementById('examInputName').value.trim();
    if (!name) {
      alert('Please enter an exam title.');
      return;
    }

    const category = document.getElementById('examInputCategory').value.trim();
    const provider = document.getElementById('examInputProvider').value.trim();
    const code = document.getElementById('examInputCode').value.trim();
    const duration = parseInt(document.getElementById('examInputDuration').value, 10);
    const passing = parseInt(document.getElementById('examInputPassing').value, 10);
    const description = document.getElementById('examInputDesc').value.trim();

    Storage.saveExam({
      id: id || undefined,
      name,
      category,
      provider,
      code,
      defaultDuration: isNaN(duration) ? 30 : duration,
      passingPercentage: isNaN(passing) ? 75 : passing,
      description
    });

    document.getElementById('modalAddExam')?.classList.remove('open');
    this.showToast('Exam saved successfully', 'success');

    // Instantly refresh all views without requiring any browser reload
    this.renderDashboard();
    this.renderExamsCatalog();
    this.renderQuestionBank();

    if (this.currentView === 'dashboard') {
      this.renderDashboard();
    } else {
      this.switchView('exams');
    }
  }

  // --- Global Event Listeners ---
  initEventListeners() {
    // Navigation Tabs
    document.querySelectorAll('.nav-tab-btn[data-view]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const view = e.currentTarget.dataset.view;
        if (view) this.switchView(view);
      });
    });

    // Brand Home Link
    document.getElementById('brandHomeLink')?.addEventListener('click', () => {
      this.switchView('dashboard');
    });

    // Theme Switcher
    document.getElementById('themeToggleBtn')?.addEventListener('click', () => this.toggleTheme());

    // Sound FX Toggle
    document.getElementById('btnSoundToggle')?.addEventListener('click', () => {
      const active = Sound.toggle();
      const btn = document.getElementById('btnSoundToggle');
      if (btn) {
        btn.textContent = active ? '🔊' : '🔇';
      }
      this.showToast(active ? 'Sound effects enabled' : 'Sound effects muted', 'info');
    });

    // User Dropdown Menu Toggle
    const btnUserMenu = document.getElementById('btnHeaderUserMenu');
    const dropdownMenu = document.getElementById('userDropdownMenu');

    btnUserMenu?.addEventListener('click', (e) => {
      e.stopPropagation();
      dropdownMenu?.classList.toggle('show');
    });

    window.addEventListener('click', () => {
      dropdownMenu?.classList.remove('show');
    });

    dropdownMenu?.addEventListener('click', (e) => {
      e.stopPropagation();
    });

    // User Dropdown Actions
    document.getElementById('menuBtnProfile')?.addEventListener('click', () => {
      dropdownMenu?.classList.remove('show');
      this.openStudentProfileModal();
    });

    document.getElementById('menuBtnSettings')?.addEventListener('click', () => {
      dropdownMenu?.classList.remove('show');
      this.switchView('settings');
    });

    document.getElementById('menuBtnBackup')?.addEventListener('click', () => {
      dropdownMenu?.classList.remove('show');
      document.getElementById('btnExportBackup')?.click();
    });

    document.getElementById('menuBtnLogout')?.addEventListener('click', () => {
      dropdownMenu?.classList.remove('show');
      Auth.logout();
      this.showToast('You have been signed out', 'info');
      this.renderHeaderInfo();
      this.checkAuthenticationGate();
    });

    // Header Login Button
    document.getElementById('btnHeaderLogin')?.addEventListener('click', () => {
      this.openAuthModal('login');
    });

    document.getElementById('menuBtnSwitchAccount')?.addEventListener('click', () => {
      dropdownMenu?.classList.remove('show');
      this.openAuthModal('login');
    });

    // Password Visibility Toggles
    document.querySelectorAll('.btn-toggle-password').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const targetId = e.currentTarget.dataset.target;
        const input = document.getElementById(targetId);
        if (!input) return;
        const isPassword = input.type === 'password';
        input.type = isPassword ? 'text' : 'password';
        e.currentTarget.textContent = isPassword ? '🙈' : '👁️';
        e.currentTarget.title = isPassword ? 'Hide password' : 'Show password';
      });
    });

    // Auth Modal Tabs
    document.getElementById('btnAuthTabLogin')?.addEventListener('click', () => this.switchAuthTab('login'));
    document.getElementById('btnAuthTabRegister')?.addEventListener('click', () => this.switchAuthTab('register'));

    // Auth Form: Login
    document.getElementById('formAuthLogin')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = document.getElementById('loginEmail').value;
      const pass = document.getElementById('loginPassword').value;

      try {
        await Auth.login({ email, password: pass });
        this.onAuthSuccess('Welcome back to QuizPro!');
      } catch (err) {
        this.setAuthAlert(err.message, 'error');
      }
    });

    // Auth Form: Register
    document.getElementById('formAuthRegister')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const name = document.getElementById('regName').value;
      const email = document.getElementById('regEmail').value;
      const pass = document.getElementById('regPassword').value;
      const targetExam = document.getElementById('regGoal').value;
      const emoji = document.getElementById('regEmoji').value;

      try {
        await Auth.register({ name, email, password: pass, avatarEmoji: emoji, targetExam });
        this.onAuthSuccess('Account registered successfully! Welcome to QuizPro.');
      } catch (err) {
        this.setAuthAlert(err.message, 'error');
      }
    });

    // Quick Demo Account Login
    document.getElementById('btnQuickDemoLogin')?.addEventListener('click', async () => {
      try {
        const users = Auth.getUsers();
        let demoUser = users.find(u => u.email === 'demo@quizpro.dev');
        if (!demoUser) {
          demoUser = await Auth.register({
            name: 'Alex Rivera',
            email: 'demo@quizpro.dev',
            password: 'Password123!',
            avatarEmoji: '🚀',
            targetExam: 'Cloud Certifications'
          });
        } else {
          await Auth.login({ email: 'demo@quizpro.dev', password: 'Password123!' });
        }
        this.onAuthSuccess('Signed in as Demo Scholar (Alex Rivera)');
      } catch (err) {
        this.setAuthAlert(err.message, 'error');
      }
    });

    // Hero buttons
    document.getElementById('btnHeroNewExam')?.addEventListener('click', () => this.openAddExamModal());
    document.getElementById('btnHeroImport')?.addEventListener('click', () => this.openImportModal());

    // Action buttons in banner
    document.getElementById('btnOpenImportModal')?.addEventListener('click', () => this.openImportModal());
    document.getElementById('btnOpenCreateExamModal')?.addEventListener('click', () => this.openAddExamModal());
    document.getElementById('btnOpenAddQuestionModal')?.addEventListener('click', () => this.openAddQuestionModal());
    document.getElementById('btnQbAddQuestion')?.addEventListener('click', () => this.openAddQuestionModal());
    document.getElementById('btnOpenNewProfileModal')?.addEventListener('click', () => this.openStudentProfileModal());

    // Add Exam Modal Save
    document.getElementById('btnSaveExamModal')?.addEventListener('click', () => this.handleSaveExam());

    // Add Question Modal Save
    document.getElementById('btnSaveQuestionModal')?.addEventListener('click', () => this.handleSaveQuestion());

    // Save Student Profile Modal
    document.getElementById('btnSaveStudentProfile')?.addEventListener('click', () => this.handleSaveStudentProfile());

    // Emoji Picker in Profile Modal
    document.querySelectorAll('.emoji-choice').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const emoji = e.currentTarget.dataset.emoji;
        const targetInput = e.currentTarget.closest('#modalAuth') ? document.getElementById('regEmoji') : document.getElementById('profileInputEmoji');
        if (targetInput) targetInput.value = emoji;
        e.currentTarget.parentElement.querySelectorAll('.emoji-choice').forEach(b => b.style.borderColor = 'var(--border-color)');
        e.currentTarget.style.borderColor = 'var(--primary)';
      });
    });

    // Import Mode Tabs (File vs Paste)
    const btnTabFile = document.getElementById('btnTabImportFile');
    const btnTabPaste = document.getElementById('btnTabImportPaste');
    const contentFile = document.getElementById('importFileTabContent');
    const contentPaste = document.getElementById('importPasteTabContent');

    btnTabFile?.addEventListener('click', () => {
      btnTabFile.className = 'btn btn-sm btn-primary';
      btnTabPaste.className = 'btn btn-sm btn-secondary';
      contentFile.style.display = 'block';
      contentPaste.style.display = 'none';
    });

    btnTabPaste?.addEventListener('click', () => {
      btnTabPaste.className = 'btn btn-sm btn-primary';
      btnTabFile.className = 'btn btn-sm btn-secondary';
      contentPaste.style.display = 'block';
      contentFile.style.display = 'none';
    });

    // Preview Mode Tabs (Valid Questions vs Issues & Warnings)
    const btnPreviewValid = document.getElementById('btnPreviewTabValid');
    const btnPreviewIssues = document.getElementById('btnPreviewTabIssues');
    const contentValid = document.getElementById('previewTabValidContent');
    const contentIssues = document.getElementById('previewTabIssuesContent');

    btnPreviewValid?.addEventListener('click', () => {
      btnPreviewValid.className = 'btn btn-sm btn-primary';
      btnPreviewIssues.className = 'btn btn-sm btn-secondary';
      if (contentValid) contentValid.style.display = 'block';
      if (contentIssues) contentIssues.style.display = 'none';
    });

    btnPreviewIssues?.addEventListener('click', () => {
      btnPreviewIssues.className = 'btn btn-sm btn-primary';
      btnPreviewValid.className = 'btn btn-sm btn-secondary';
      if (contentIssues) contentIssues.style.display = 'block';
      if (contentValid) contentValid.style.display = 'none';
    });

    // Paste CSV parser button
    document.getElementById('btnParsePastedCsv')?.addEventListener('click', () => {
      const text = document.getElementById('importPasteTextarea').value.trim();
      if (!text) {
        alert('Please paste CSV text first.');
        return;
      }
      const rows = parseCSVString(text);
      const result = processRows(rows, 'Pasted_Questions.csv');
      this.showImportPreview(result);
    });

    // Import File Dropzone Handlers
    const fileInput = document.getElementById('importFileInput');
    const dropzone = document.getElementById('importDropzone');

    dropzone?.addEventListener('click', () => fileInput?.click());
    dropzone?.addEventListener('dragover', (e) => {
      e.preventDefault();
      dropzone.classList.add('dragover');
    });
    dropzone?.addEventListener('dragleave', () => dropzone.classList.remove('dragover'));
    dropzone?.addEventListener('drop', (e) => {
      e.preventDefault();
      dropzone.classList.remove('dragover');
      if (e.dataTransfer.files.length > 0) {
        this.handleImportFile(e.dataTransfer.files[0]);
      }
    });

    fileInput?.addEventListener('change', (e) => {
      if (e.target.files.length > 0) {
        this.handleImportFile(e.target.files[0]);
      }
    });

    // Sample CSV Download
    document.getElementById('btnDownloadSampleCsv')?.addEventListener('click', () => {
      const csvStr = generateSampleCsvContent();
      const blob = new Blob([csvStr], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'quizpro_sample_questions.csv';
      a.click();
      URL.revokeObjectURL(url);
    });

    // Confirm Import Button
    document.getElementById('btnConfirmImport')?.addEventListener('click', () => {
      this.executeImport();
    });

    // Close Modals
    document.querySelectorAll('.btn-close-modal').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.target.closest('.modal-overlay')?.classList.remove('open');
      });
    });

    // Submit Exam Confirmation Modal Actions
    document.getElementById('btnConfirmSubmitExam')?.addEventListener('click', () => {
      document.getElementById('modalSubmitConfirm')?.classList.remove('open');
      if (this.activeEngine) {
        this.activeEngine.submitExam(false);
      }
    });

    // Question Bank Search & Filter
    document.getElementById('qbSearchInput')?.addEventListener('input', () => this.renderQuestionBank());
    document.getElementById('qbCategoryFilter')?.addEventListener('change', () => this.renderQuestionBank());
    document.getElementById('qbTopicFilter')?.addEventListener('change', () => this.renderQuestionBank());
    document.getElementById('qbTypeFilter')?.addEventListener('change', () => this.renderQuestionBank());
    document.getElementById('btnQbToggleStarred')?.addEventListener('click', (e) => {
      e.currentTarget.classList.toggle('active');
      if (e.currentTarget.classList.contains('active')) {
        e.currentTarget.style.background = 'rgba(245, 158, 11, 0.2)';
        e.currentTarget.style.color = '#F59E0B';
        e.currentTarget.style.borderColor = 'rgba(245, 158, 11, 0.4)';
      } else {
        e.currentTarget.style.background = '';
        e.currentTarget.style.color = '';
        e.currentTarget.style.borderColor = '';
      }
      this.renderQuestionBank();
    });

    // Top Navigation & Header Quick Actions
    document.getElementById('navBtnImport')?.addEventListener('click', () => this.openImportModal());
    document.getElementById('btnHeaderNewExam')?.addEventListener('click', () => this.openAddExamModal());

    // Dashboard Quick Actions
    document.getElementById('btnDashQuickImport')?.addEventListener('click', () => this.openImportModal());
    document.getElementById('btnDashNewExam')?.addEventListener('click', () => this.openAddExamModal());
    document.getElementById('btnDashPracticeStarred')?.addEventListener('click', () => {
      this.openSessionLauncherModal({ defaultMode: 'practice', onlyStarred: true });
    });
    document.getElementById('btnDashViewAllExams')?.addEventListener('click', () => this.switchView('exams'));
    document.getElementById('btnDashViewAllHistory')?.addEventListener('click', () => this.switchView('history'));

    // History View Filter Buttons
    document.querySelectorAll('.hist-filter-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        this.renderHistory(e.currentTarget.dataset.filter);
      });
    });

    document.getElementById('btnClearHistoryBtnHist')?.addEventListener('click', () => {
      if (confirm('Are you sure you want to clear your attempt history?')) {
        const student = Storage.getActiveStudent();
        Storage.clearAllPerformances(student.id);
        this.showToast('Attempt history cleared', 'success');
        this.renderHistory();
      }
    });

    // Audit Modal Filter Pills
    document.querySelectorAll('.audit-filter-pill').forEach(btn => {
      btn.addEventListener('click', (e) => {
        document.querySelectorAll('.audit-filter-pill').forEach(b => {
          b.className = 'btn btn-sm btn-secondary audit-filter-pill';
        });
        e.currentTarget.className = 'btn btn-sm btn-primary audit-filter-pill';
        this.renderAuditQuestionsList(e.currentTarget.dataset.auditFilter);
      });
    });

    // Session Launcher Modal Controls
    document.getElementById('btnModePractice')?.addEventListener('click', () => {
      this.updateLauncherModeUI('practice');
    });

    document.getElementById('btnModeExam')?.addEventListener('click', () => {
      this.updateLauncherModeUI('exam');
    });

    document.getElementById('launcherExamSelect')?.addEventListener('change', (e) => {
      this.refreshLauncherTopics(e.target.value);
      this.updateLauncherDurationPillsUI();
      this.updateLauncherAvailability();
    });

    document.getElementById('launcherTopicSelect')?.addEventListener('change', () => {
      this.updateLauncherAvailability();
    });

    document.getElementById('launcherDifficultySelect')?.addEventListener('change', () => {
      this.updateLauncherAvailability();
    });

    document.getElementById('launcherTypeSelect')?.addEventListener('change', () => {
      this.updateLauncherAvailability();
    });

    document.getElementById('launcherStarredToggle')?.addEventListener('change', () => {
      this.updateLauncherAvailability();
    });

    document.querySelectorAll('#launcherCountPills .count-pill').forEach(btn => {
      btn.addEventListener('click', (e) => {
        document.querySelectorAll('#launcherCountPills .count-pill').forEach(b => {
          b.className = 'btn btn-sm btn-secondary count-pill';
        });
        e.currentTarget.className = 'btn btn-sm btn-primary count-pill active';
        const isCustom = e.currentTarget.dataset.count === 'custom';
        const wrap = document.getElementById('launcherCustomCountWrapper');
        if (wrap) wrap.style.display = isCustom ? 'block' : 'none';
        this.updateLauncherAvailability();
      });
    });

    document.getElementById('launcherCustomCountInput')?.addEventListener('input', () => {
      this.updateLauncherAvailability();
    });

    document.querySelectorAll('#launcherDurationPills .duration-pill').forEach(btn => {
      btn.addEventListener('click', (e) => {
        document.querySelectorAll('#launcherDurationPills .duration-pill').forEach(b => {
          b.className = 'btn btn-sm btn-secondary duration-pill';
        });
        e.currentTarget.className = 'btn btn-sm btn-primary duration-pill active';
        const isCustom = e.currentTarget.dataset.duration === 'custom';
        const wrap = document.getElementById('launcherCustomDurationWrapper');
        if (wrap) wrap.style.display = isCustom ? 'block' : 'none';
      });
    });

    document.getElementById('btnLaunchConfirmedSession')?.addEventListener('click', () => {
      this.executeLaunchSession();
    });

    // Analytics Clear History Button
    document.getElementById('btnClearHistoryBtn')?.addEventListener('click', () => {
      if (confirm('Are you sure you want to clear your attempt history?')) {
        const student = Storage.getActiveStudent();
        Storage.clearAllPerformances(student.id);
        this.showToast('Attempt history cleared', 'success');
        this.renderAnalytics();
      }
    });

    // Backup & Restore Handlers
    document.getElementById('btnExportBackup')?.addEventListener('click', () => {
      const backup = Storage.exportFullBackup();
      const json = JSON.stringify(backup, null, 2);
      const blob = new Blob([json], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `quizpro_backup_${new Date().toISOString().split('T')[0]}.json`;
      a.click();
      URL.revokeObjectURL(url);
      this.showToast('Full backup downloaded', 'success');
    });

    document.getElementById('btnImportBackupFile')?.addEventListener('change', (e) => {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = (evt) => {
        try {
          const parsed = JSON.parse(evt.target.result);
          Storage.importFullBackup(parsed);
          this.showToast('Backup restored successfully!', 'success');
          this.renderHeaderInfo();
          this.renderExamsCatalog();
        } catch (err) {
          alert('Failed to parse backup file: ' + err.message);
        }
      };
      reader.readAsText(file);
    });

    document.getElementById('btnResetAllData')?.addEventListener('click', () => {
      if (confirm('DANGER: This will wipe all exams, questions, and profiles, restoring a clean slate. Continue?')) {
        Storage.resetAllData();
        this.showToast('Reset completed', 'success');
        this.renderHeaderInfo();
        this.renderExamsCatalog();
      }
    });

    // Supabase Cloud Database Event Handlers
    document.getElementById('btnSaveSupabaseConfig')?.addEventListener('click', () => {
      const url = document.getElementById('supabaseInputUrl')?.value.trim();
      const anonKey = document.getElementById('supabaseInputKey')?.value.trim();
      Supabase.saveConfig({ url, anonKey });
      this.renderSettings();
      this.showToast('Supabase configuration saved!', 'success');
    });

    document.getElementById('btnTestSupabase')?.addEventListener('click', async () => {
      const url = document.getElementById('supabaseInputUrl')?.value.trim();
      const anonKey = document.getElementById('supabaseInputKey')?.value.trim();
      Supabase.saveConfig({ url, anonKey });
      this.showToast('Connecting to Supabase...', 'info');
      try {
        const result = await Supabase.testConnection();
        this.renderSettings();
        this.showToast(result.notice || 'Successfully connected to Supabase PostgreSQL!', 'success');
      } catch (err) {
        alert('Supabase Connection Failed: ' + err.message);
      }
    });

    document.getElementById('btnPushToSupabase')?.addEventListener('click', async () => {
      if (!Supabase.isConfigured()) {
        alert('Please enter and save your Supabase Project URL and Anon Key first.');
        return;
      }
      const exams = Storage.getAllExams();
      if (exams.length === 0) {
        this.showToast('No exams to push. Create or load an exam first.', 'info');
        return;
      }
      this.showToast('Uploading exams to Supabase Cloud...', 'info');
      try {
        const res = await Supabase.syncExamsToCloud(exams);
        this.showToast(`Pushed ${res.synced} exam(s) to Supabase cloud!`, 'success');
      } catch (err) {
        alert('Push to Supabase failed: ' + err.message);
      }
    });

    document.getElementById('btnPullFromSupabase')?.addEventListener('click', async () => {
      if (!Supabase.isConfigured()) {
        alert('Please enter and save your Supabase Project URL and Anon Key first.');
        return;
      }
      this.showToast('Downloading exams from Supabase Cloud...', 'info');
      try {
        const remoteExams = await Supabase.pullExamsFromCloud();
        if (remoteExams.length === 0) {
          this.showToast('No remote exams found in Supabase.', 'info');
          return;
        }
        Storage.setAllExams(remoteExams);
        this.renderExamsCatalog();
        this.renderQuestionBank();
        this.showToast(`Downloaded ${remoteExams.length} exam(s) from Supabase!`, 'success');
      } catch (err) {
        alert('Pull from Supabase failed: ' + err.message);
      }
    });

    // Test Confetti Button
    document.getElementById('btnTestConfetti')?.addEventListener('click', () => {
      ConfettiCelebration.firePassingCelebration();
      Sound.playOptionCorrect();
      this.showToast('Confetti celebration launched! 🎉', 'success');
    });

    // Desktop Keyboard Shortcuts (active only when no modal is open)
    window.addEventListener('keydown', (e) => {
      if (!this.activeEngine) return;
      if (document.querySelector('.modal-overlay.open')) return;
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT') return;

      const key = e.key.toUpperCase();
      if (key === '1' || key === 'A') this.activeEngine.selectOption(0);
      else if (key === '2' || key === 'B') this.activeEngine.selectOption(1);
      else if (key === '3' || key === 'C') this.activeEngine.selectOption(2);
      else if (key === '4' || key === 'D') this.activeEngine.selectOption(3);
      else if (key === 'M') this.activeEngine.toggleFlag();
      else if (key === 'B' && this.currentView === 'practice') {
        const q = this.activeEngine.getCurrentQuestion();
        if (q) {
          const s = Storage.getActiveStudent();
          Storage.toggleBookmark(q.id, s.id);
          this.renderPracticeCard();
        }
      }
      else if (e.key === 'ArrowRight' || e.key === 'Enter') this.activeEngine.next();
      else if (e.key === 'ArrowLeft') this.activeEngine.prev();
    });
  }

  handleImportFile(file) {
    const filename = file.name;
    const isCsv = filename.toLowerCase().endsWith('.csv');
    const isExcel = filename.toLowerCase().endsWith('.xlsx') || filename.toLowerCase().endsWith('.xls');

    if (!isCsv && !isExcel) {
      alert('Please upload a valid .csv, .xlsx, or .xls file.');
      return;
    }

    const titleEl = document.getElementById('importDropzoneTitle');
    const subEl = document.getElementById('importDropzoneSubtitle');
    if (titleEl) titleEl.textContent = `📄 ${filename}`;
    if (subEl) subEl.textContent = `${(file.size / 1024).toFixed(1)} KB — File processed`;

    const reader = new FileReader();

    if (isCsv) {
      reader.onload = (e) => {
        const text = e.target.result;
        const rows = parseCSVString(text);
        const result = processRows(rows, filename);
        this.showImportPreview(result);
      };
      reader.readAsText(file);
    } else {
      reader.onload = (e) => {
        const buffer = e.target.result;
        try {
          const result = parseExcelArrayBuffer(buffer, filename);
          this.showImportPreview(result);
        } catch (err) {
          alert('Excel parse error: ' + err.message);
        }
      };
      reader.readAsArrayBuffer(file);
    }
  }

  showImportPreview(result) {
    this.importPreviewData = result;
    const area = document.getElementById('importPreviewArea');
    const statsEl = document.getElementById('importPreviewStats');
    const validTbody = document.getElementById('importPreviewTableBody');
    const issuesTbody = document.getElementById('importIssuesTableBody');
    const confirmBtn = document.getElementById('btnConfirmImport');
    const countValidEl = document.getElementById('previewCountValid');
    const countIssuesEl = document.getElementById('previewCountIssues');
    const fileBadge = document.getElementById('importFileBadge');
    const tabValidBtn = document.getElementById('btnPreviewTabValid');
    const tabIssuesBtn = document.getElementById('btnPreviewTabIssues');
    const tabValidContent = document.getElementById('previewTabValidContent');
    const tabIssuesContent = document.getElementById('previewTabIssuesContent');

    if (!area || !result) return;

    area.style.display = 'block';

    const validCount = result.validQuestions ? result.validQuestions.length : 0;
    const issueCount = result.issues ? result.issues.length : 0;
    const dupCount = result.duplicateCount || 0;

    if (countValidEl) countValidEl.textContent = validCount;
    if (countIssuesEl) countIssuesEl.textContent = issueCount;
    if (fileBadge && result.filename) fileBadge.textContent = `📁 ${result.filename}`;

    // Stats Bar
    if (statsEl) {
      statsEl.innerHTML = `
        <div style="display: flex; gap: 0.6rem; align-items: center; flex-wrap: wrap;">
          <span class="preview-badge ${validCount > 0 ? 'success' : 'secondary'}">
            ✓ ${validCount} Questions Ready
          </span>
          ${issueCount > 0 ? `
            <span class="preview-badge warning">
              ⚠️ ${issueCount} Formatting Issues
            </span>
          ` : `
            <span class="preview-badge success">✓ 0 Issues</span>
          `}
          ${dupCount > 0 ? `
            <span class="preview-badge secondary">
              ℹ️ ${dupCount} Duplicate Questions Skipped
            </span>
          ` : ''}
        </div>
        ${validCount === 0 ? `
          <div class="alert alert-danger" style="margin-top: 0.75rem; font-size: 0.82rem; padding: 0.6rem 0.85rem; border-radius: var(--radius-sm); background: rgba(239, 68, 68, 0.1); border: 1px solid rgba(239, 68, 68, 0.25); color: #EF4444;">
            No questions could be extracted. Please check the "Issues &amp; Warnings" tab below to see specific row errors, or download the sample CSV template.
          </div>
        ` : ''}
      `;
    }

    // Populate Valid Questions
    if (validTbody) {
      if (validCount === 0) {
        validTbody.innerHTML = `
          <tr>
            <td colspan="5" style="text-align: center; color: var(--text-muted); padding: 2rem;">
              No valid questions detected. Switch to Issues tab to inspect row errors.
            </td>
          </tr>
        `;
      } else {
        validTbody.innerHTML = result.validQuestions.slice(0, 50).map((q, idx) => `
          <tr>
            <td><strong>#${idx + 1}</strong></td>
            <td>
              <div style="max-width: 360px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="${this.escapeHtml(q.question)}">
                ${this.escapeHtml(q.question)}
              </div>
            </td>
            <td><span class="meta-pill" style="font-size: 0.74rem; padding: 0.15rem 0.45rem;">${q.options ? q.options.length : 0} options</span></td>
            <td>
              <span class="q-badge" style="background: rgba(16, 185, 129, 0.12); color: #10B981; font-weight: 700; font-size: 0.78rem; padding: 0.2rem 0.5rem; border-radius: var(--radius-sm);">
                ${q.correctAnswers ? q.correctAnswers.map(a => String.fromCharCode(65 + a)).join(', ') : '-'}
              </span>
            </td>
            <td><span style="color: var(--text-muted); font-size: 0.78rem;">${this.escapeHtml(q.topic || 'General')}</span></td>
          </tr>
        `).join('');
      }
    }

    // Populate Issues Table
    if (issuesTbody) {
      if (issueCount === 0) {
        issuesTbody.innerHTML = `
          <tr>
            <td colspan="4" style="text-align: center; color: var(--success); padding: 1.5rem;">
              🎉 Excellent! No formatting issues found. All rows are valid.
            </td>
          </tr>
        `;
      } else {
        issuesTbody.innerHTML = result.issues.slice(0, 50).map(issue => `
          <tr>
            <td><strong>Row ${issue.row || '-'}</strong></td>
            <td><span style="color: #EF4444; font-weight: 600;">${this.escapeHtml(issue.problem || '')}</span></td>
            <td><span style="color: var(--text-muted); font-size: 0.8rem;">${this.escapeHtml(issue.suggestion || '')}</span></td>
            <td>
              <code class="raw-snippet-badge" title="${this.escapeHtml(issue.rawData || '')}">
                ${this.escapeHtml(issue.rawData || '-')}
              </code>
            </td>
          </tr>
        `).join('');
      }
    }

    // Auto-switch tab if 0 valid questions
    if (validCount === 0 && issueCount > 0) {
      if (tabIssuesBtn && tabValidBtn && tabIssuesContent && tabValidContent) {
        tabIssuesBtn.className = 'btn btn-sm btn-primary';
        tabValidBtn.className = 'btn btn-sm btn-secondary';
        tabIssuesContent.style.display = 'block';
        tabValidContent.style.display = 'none';
      }
    } else {
      if (tabIssuesBtn && tabValidBtn && tabIssuesContent && tabValidContent) {
        tabValidBtn.className = 'btn btn-sm btn-primary';
        tabIssuesBtn.className = 'btn btn-sm btn-secondary';
        tabValidContent.style.display = 'block';
        tabIssuesContent.style.display = 'none';
      }
    }

    // Confirm button state
    if (confirmBtn) {
      if (validCount > 0) {
        confirmBtn.style.display = 'inline-flex';
        confirmBtn.innerHTML = `${Icons.check('', 14)} Import ${validCount} Question${validCount > 1 ? 's' : ''}`;
      } else {
        confirmBtn.style.display = 'none';
      }
    }
  }

  executeImport() {
    if (!this.importPreviewData || !this.importPreviewData.validQuestions || this.importPreviewData.validQuestions.length === 0) {
      this.showToast('No valid questions to import.', 'warning');
      return;
    }

    const targetSelect = document.getElementById('importTargetExamSelect')?.value || 'NEW';
    const validQuestions = this.importPreviewData.validQuestions;

    if (targetSelect === 'NEW') {
      const rawName = this.importPreviewData.filename || 'Imported Examination';
      const examName = rawName.replace(/\.[^/.]+$/, '').replace(/[-_]/g, ' ');
      Storage.saveExam({
        name: examName.charAt(0).toUpperCase() + examName.slice(1),
        category: 'Imported',
        defaultDuration: Math.max(15, Math.round(validQuestions.length * 1.5)),
        description: `Imported from ${rawName} on ${new Date().toLocaleDateString()}`,
        questions: validQuestions
      });
    } else {
      const existingExam = Storage.getExamById(targetSelect);
      if (existingExam) {
        if (!existingExam.questions) existingExam.questions = [];
        existingExam.questions.push(...validQuestions);
        Storage.saveExam(existingExam);
      }
    }

    document.getElementById('modalImport')?.classList.remove('open');
    this.showToast(`Imported ${validQuestions.length} questions successfully!`, 'success');
    this.switchView('exams');
  }

  // --- Utilities ---
  showToast(message, type = 'info') {
    let container = document.querySelector('.toast-container');
    if (!container) {
      container = document.createElement('div');
      container.className = 'toast-container';
      document.body.appendChild(container);
    }

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    toast.textContent = message;

    container.appendChild(toast);
    setTimeout(() => {
      toast.style.opacity = '0';
      setTimeout(() => toast.remove(), 300);
    }, 3200);
  }

  formatDuration(seconds) {
    if (isNaN(seconds) || seconds < 0) return '00:00';
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  }

  escapeHtml(str) {
    if (!str) return '';
    return str
      .toString()
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }
}

// Instantiate App upon DOM loaded
window.addEventListener('DOMContentLoaded', () => {
  window.app = new QuizProApp();
});
