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
      this.switchView('exams');
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
    this.renderExamsCatalog();
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
  switchView(viewName, params = {}) {
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

    const targetSec = document.getElementById(`view-${viewName}`);
    const targetTab = document.querySelector(`.nav-tab-btn[data-view="${viewName}"]`);

    if (targetSec) targetSec.classList.add('active');
    if (targetTab) targetTab.classList.add('active');

    this.currentView = viewName;
    window.scrollTo({ top: 0, behavior: 'smooth' });

    switch (viewName) {
      case 'exams':
        this.renderExamsCatalog();
        break;
      case 'question_bank':
        this.renderQuestionBank();
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
        Storage.addExam(sample);
        this.renderExamsCatalog();
        this.showToast('Sample Exam loaded! Click Practice or Timed Exam to start.', 'success');
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
                <button class="icon-btn btn-sm btn-card-add-q" title="Add Question to Exam" data-id="${exam.id}">${Icons.plus('', 13)}</button>
                <button class="icon-btn btn-sm btn-edit-exam" title="Edit Exam Settings" data-id="${exam.id}">${Icons.edit('', 13)}</button>
                <button class="icon-btn btn-sm btn-delete-exam" title="Delete Exam" data-id="${exam.id}">${Icons.trash('', 13)}</button>
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

          <div class="exam-card-actions">
            <button class="btn btn-secondary btn-practice-exam" data-id="${exam.id}" style="flex: 1;" ${qCount === 0 ? 'title="Add questions to start practice"' : ''}>
              ${Icons.play('', 12)} Practice
            </button>
            <button class="btn btn-primary btn-take-exam" data-id="${exam.id}" style="flex: 1;" ${qCount === 0 ? 'title="Add questions to start timed test"' : ''}>
              ${Icons.clock('', 12)} Timed Exam
            </button>
          </div>
        </div>
      `;
    }).join('');

    // Attach card event listeners
    container.querySelectorAll('.btn-card-add-q').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const id = e.currentTarget.dataset.id;
        this.openAddQuestionModal(id);
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
        this.switchView('practice', { examId: id });
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
        this.switchView('exam', { examId: id });
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
  startPracticeSession({ examId = null, filterType = 'all', customQuestions = null }) {
    let exam = null;
    let questions = [];

    if (customQuestions && customQuestions.length > 0) {
      questions = [...customQuestions];
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
  startTimedExamSession({ examId }) {
    const exam = Storage.getExamById(examId);
    if (!exam || !exam.questions || exam.questions.length === 0) {
      this.showToast('This exam has no questions.', 'info');
      this.switchView('exams');
      return;
    }

    this.activeEngine = new ExamEngine({
      mode: 'timed',
      exam,
      questions: exam.questions,
      durationMinutes: exam.defaultDuration,
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
    exams.forEach(exam => {
      (exam.questions || []).forEach(q => {
        allQuestions.push({ ...q, examId: exam.id, examName: exam.name });
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

    const searchInput = document.getElementById('qbSearchInput')?.value.toLowerCase().trim() || '';
    const categoryFilter = catSelect?.value || 'all';

    let filtered = allQuestions.filter(q => {
      const matchSearch = !searchInput || 
                          q.question.toLowerCase().includes(searchInput) ||
                          (q.topic && q.topic.toLowerCase().includes(searchInput)) ||
                          (q.tags && q.tags.some(t => t.toLowerCase().includes(searchInput)));
      const matchExam = categoryFilter === 'all' || q.examId === categoryFilter;
      return matchSearch && matchExam;
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
    if (this.currentView === 'exams') this.renderExamsCatalog();
    else if (this.currentView === 'question_bank') this.renderQuestionBank();
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
  openImportModal() {
    const modal = document.getElementById('modalImport');
    const select = document.getElementById('importTargetExamSelect');
    if (!modal) return;

    const exams = Storage.getAllExams();
    select.innerHTML = `
      <option value="NEW">✨ Create New Exam From File</option>
      ${exams.map(e => `<option value="${e.id}">Append to: ${this.escapeHtml(e.name)}</option>`).join('')}
    `;

    document.getElementById('importPreviewArea').style.display = 'none';
    document.getElementById('btnConfirmImport').style.display = 'none';
    document.getElementById('importPasteTextarea').value = '';
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
    this.renderExamsCatalog();
  }

  // --- Global Event Listeners ---
  initEventListeners() {
    // Navigation Tabs
    document.querySelectorAll('.nav-tab-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const view = e.currentTarget.dataset.view;
        this.switchView(view);
      });
    });

    // Brand Home Link
    document.getElementById('brandHomeLink')?.addEventListener('click', () => {
      this.switchView('exams');
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
    const tableBody = document.getElementById('importPreviewTableBody');
    const confirmBtn = document.getElementById('btnConfirmImport');

    if (!area || !result) return;

    area.style.display = 'block';
    confirmBtn.style.display = result.validQuestions.length > 0 ? 'inline-flex' : 'none';

    statsEl.innerHTML = `
      <div style="display: flex; gap: 1rem; flex-wrap: wrap; margin-bottom: 1rem;">
        <span class="q-badge" style="color: var(--success); font-weight: 700;">✓ ${result.validQuestions.length} Valid Questions</span>
        <span class="q-badge" style="color: ${result.issues.length > 0 ? 'var(--warning)' : 'var(--text-muted)'}; font-weight: 700;">⚠️ ${result.issues.length} Issues</span>
      </div>
    `;

    tableBody.innerHTML = result.validQuestions.slice(0, 10).map((q, idx) => `
      <tr>
        <td><strong>#${idx + 1}</strong></td>
        <td>${this.escapeHtml(q.question)}</td>
        <td>${q.options.length} options</td>
        <td><span style="color: var(--success); font-weight: 700;">${q.correctAnswers.map(a => String.fromCharCode(65 + a)).join(', ')}</span></td>
        <td>${this.escapeHtml(q.topic || 'General')}</td>
      </tr>
    `).join('');
  }

  executeImport() {
    if (!this.importPreviewData || this.importPreviewData.validQuestions.length === 0) return;

    const targetSelect = document.getElementById('importTargetExamSelect').value;
    const validQuestions = this.importPreviewData.validQuestions;

    if (targetSelect === 'NEW') {
      const examName = this.importPreviewData.filename.replace(/\.[^/.]+$/, '').replace(/[-_]/g, ' ');
      Storage.saveExam({
        name: examName.charAt(0).toUpperCase() + examName.slice(1),
        category: 'Imported',
        defaultDuration: Math.max(15, Math.round(validQuestions.length * 1.5)),
        description: `Imported from ${this.importPreviewData.filename} on ${new Date().toLocaleDateString()}`,
        questions: validQuestions
      });
    } else {
      const existingExam = Storage.getExamById(targetSelect);
      if (existingExam) {
        existingExam.questions.push(...validQuestions);
        Storage.saveExam(existingExam);
      }
    }

    document.getElementById('modalImport')?.classList.remove('open');
    this.showToast(`Imported ${validQuestions.length} questions successfully!`, 'success');
    this.renderExamsCatalog();
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
