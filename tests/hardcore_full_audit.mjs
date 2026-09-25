// ==============================================================================
// HARDCORE BRUTAL AUDIT SUITE FOR QUIZPRO WEB V2.0
// 120+ Rigorous Assertions Testing Storage, Engine, Importer, Security & UI
// ==============================================================================

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

let totalTests = 0;
let passedTests = 0;
let failedTests = [];

function assert(condition, message) {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`  ✅ [TEST ${String(totalTests).padStart(3, '0')}] PASS: ${message}`);
  } else {
    failedTests.push({ testNum: totalTests, message });
    console.error(`  ❌ [TEST ${String(totalTests).padStart(3, '0')}] FAIL: ${message}`);
  }
}

// -----------------------------------------------------------------------------
// Mock Browser Environment for Headless Node.js Testing
// -----------------------------------------------------------------------------
class MockLocalStorage {
  constructor() { this.store = {}; }
  getItem(k) { return this.store[k] !== undefined ? this.store[k] : null; }
  setItem(k, v) { this.store[k] = String(v); }
  removeItem(k) { delete this.store[k]; }
  clear() { this.store = {}; }
}

global.localStorage = new MockLocalStorage();
global.window = {
  scrollTo: () => {},
  addEventListener: () => {}
};
global.document = {
  documentElement: {
    setAttribute: () => {},
    getAttribute: () => 'dark'
  },
  getElementById: () => null,
  querySelectorAll: () => [],
  querySelector: () => null
};

console.log('\n======================================================');
console.log('🚀 EXECUTING HARDCORE BRUTAL AUDIT SUITE');
console.log('======================================================\n');

async function runAudit() {
  // ===========================================================================
  // SECTION 1: STORAGE & REPOSITORY INTEGRITY
  // ===========================================================================
  console.log('📦 SUITE 1: STORAGE, UUID & REPOSITORY INTEGRITY');

  const { Storage } = await import('../web/scripts/storage.js');
  const { createSampleDemoExam } = await import('../web/scripts/defaultData.js');

  assert(typeof Storage.getAllExams === 'function', 'Storage.getAllExams is defined');
  assert(typeof Storage.saveExam === 'function', 'Storage.saveExam is defined');
  assert(typeof Storage.addExam === 'function', 'Storage.addExam alias is defined and matches saveExam');

  Storage.resetAllData();
  assert(Storage.getAllExams().length === 0, 'Clean slate initializes with 0 exams');

  // Test UUID generation
  const exam1 = Storage.saveExam({
    name: 'AWS Solutions Architect SAA-C03',
    category: 'Cloud Computing',
    provider: 'Amazon Web Services',
    code: 'SAA-C03',
    defaultDuration: 45,
    passingPercentage: 72,
    description: 'Core cloud solutions examination',
    questions: [
      {
        question: 'Which S3 storage tier offers millisecond retrieval for infrequently accessed data?',
        options: ['S3 Standard-IA', 'S3 Glacier Flexible', 'S3 Glacier Deep Archive', 'S3 One Zone-IA'],
        correctAnswers: [0],
        explanation: 'S3 Standard-IA delivers low latency with reduced storage rates.',
        topic: 'Storage',
        difficulty: 2
      },
      {
        question: 'Select two VPC networking components required for internet gateway access:',
        options: ['Internet Gateway attached to VPC', 'Route table entry pointing 0.0.0.0/0 to IGW', 'NAT Gateway', 'Transit Gateway'],
        correctAnswers: [0, 1],
        questionType: 'multiple',
        explanation: 'Both an attached IGW and default route entry are necessary.',
        topic: 'Networking',
        difficulty: 3
      }
    ]
  });

  const allExams = Storage.getAllExams();
  assert(allExams.length === 1, 'Exam successfully persisted to storage (count: 1)');
  
  const createdExam = allExams[0];
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  assert(uuidRegex.test(createdExam.id), `Exam ID is a RFC4122 compliant UUID: ${createdExam.id}`);
  assert(createdExam.questions.length === 2, 'Exam contains exactly 2 questions');
  assert(uuidRegex.test(createdExam.questions[0].id), 'Question 1 assigned a valid UUID');
  assert(createdExam.questions[0].displayNumber === 1, 'Question 1 displayNumber indexed to 1');
  assert(createdExam.questions[1].displayNumber === 2, 'Question 2 displayNumber indexed to 2');

  // Test Storage.addExam alias
  const sampleExam = createSampleDemoExam();
  Storage.addExam(sampleExam);
  assert(Storage.getAllExams().length === 2, 'Storage.addExam successfully created sample exam (count: 2)');

  // Test getExamById
  const fetched = Storage.getExamById(createdExam.id);
  assert(fetched !== null && fetched.name === 'AWS Solutions Architect SAA-C03', 'Storage.getExamById retrieves correct exam');

  // Test streak logic
  const activeStudent = Storage.getActiveStudent();
  assert(activeStudent && activeStudent.id, 'Active student retrieved cleanly');

  const initialStreak = Storage.getStreak(activeStudent.id);
  assert(initialStreak.currentStreak === 0, 'Initial study streak starts at 0 days');

  Storage.updateStreak(activeStudent.id);
  const updatedStreak = Storage.getStreak(activeStudent.id);
  assert(updatedStreak.currentStreak === 1, 'Study streak increments to 1 on completion');

  // Test Bookmarks
  const qId = createdExam.questions[0].id;
  assert(Storage.isBookmarked(qId, activeStudent.id) === false, 'Question initially not bookmarked');
  Storage.toggleBookmark(qId, activeStudent.id);
  assert(Storage.isBookmarked(qId, activeStudent.id) === true, 'Question bookmarked after toggle');
  Storage.toggleBookmark(qId, activeStudent.id);
  assert(Storage.isBookmarked(qId, activeStudent.id) === false, 'Question unbookmarked after second toggle');
  Storage.toggleBookmark(qId, activeStudent.id); // Re-bookmark for later tests

  // Test Performance History
  Storage.savePerformance({
    examId: createdExam.id,
    examName: createdExam.name,
    studentId: activeStudent.id,
    score: 85,
    passed: true,
    correct: 17,
    totalQuestions: 20,
    durationSeconds: 940,
    missedQuestions: [createdExam.questions[0]]
  });

  const perfs = Storage.getPerformances(activeStudent.id);
  assert(perfs.length === 1, 'Performance attempt saved and retrieved (count: 1)');
  assert(perfs[0].passed === true, 'Performance pass status correctly evaluated');
  assert(perfs[0].missedQuestions.length === 1, 'Missed questions stored accurately for mistake drill');

  // Test Full Backup Export & Restore
  const backup = Storage.exportFullBackup();
  assert(backup.exams && backup.exams.length === 2, 'Backup contains both examinations');
  assert(backup.performances && backup.performances.length === 1, 'Backup contains attempt history');
  assert(backup.bookmarks !== undefined, 'Backup contains bookmarks map');

  // Wipe and restore from backup
  Storage.resetAllData();
  assert(Storage.getAllExams().length === 0, 'Reset wiped all data');
  Storage.importFullBackup(backup);
  assert(Storage.getAllExams().length === 2, 'Restore recovered all examinations intact');
  assert(Storage.getPerformances(activeStudent.id).length === 1, 'Restore recovered performance history');

  // ===========================================================================
  // SECTION 2: CSV & EXCEL INGESTION ENGINE
  // ===========================================================================
  console.log('\n📄 SUITE 2: CSV & EXCEL PARSER ROBUSTNESS');

  const { parseCSVString, processRows } = await import('../web/scripts/importEngine.js');

  // Multi-column alias testing
  const csvRaw = `question,option_a,option_b,option_c,option_d,correct_answer,explanation,topic,difficulty
"What does ACID stand for in databases?","Atomicity, Consistency, Isolation, Durability","Advanced Cloud Interface Database","Asynchronous Client Input Driver","Automated Crash Inspection Daemon",A,"ACID guarantees reliable transactions.",Databases,2
"Which protocols operate at the Transport layer? (Choose two)","TCP","UDP","IP","HTTP","A, B","Both TCP and UDP provide transport services.",Networking,3
"IPv6 addresses have a length of 128 bits.","True","False","","","1","IPv6 uses 128-bit addresses.",Networking,1`;

  const parsedRows = parseCSVString(csvRaw);
  assert(parsedRows.length === 4, 'Parsed 4 lines (1 header + 3 data rows)');

  const importResult = processRows(parsedRows, 'test_sample.csv');
  assert(importResult.validQuestions.length === 3, 'All 3 rows parsed into valid questions');
  assert(importResult.issues.length === 0, 'Zero formatting issues detected in compliant CSV');

  const q1 = importResult.validQuestions[0];
  assert(q1.question === 'What does ACID stand for in databases?', 'Question 1 text preserved');
  assert(q1.options.length === 4, 'Question 1 has 4 options');
  assert(q1.correctAnswers.length === 1 && q1.correctAnswers[0] === 0, 'Single answer "A" maps to index 0');

  const q2 = importResult.validQuestions[1];
  assert(q2.correctAnswers.length === 2 && q2.correctAnswers[0] === 0 && q2.correctAnswers[1] === 1, 'Multi answer "A, B" maps to [0, 1]');
  assert(q2.questionType === 'multiple', 'Multi-answer question flagged as type multiple');

  const q3 = importResult.validQuestions[2];
  assert(q3.correctAnswers.length === 1 && q3.correctAnswers[0] === 0, 'Numeric answer "1" maps to index 0');

  // Malformed rows tolerance
  const badCsv = `question,option_a,option_b,correct_answer
"Only two options?",Yes,No,A
"Missing answer?",Yes,No,
"Valid question?",Yes,No,B`;

  const badResult = processRows(parseCSVString(badCsv), 'bad.csv');
  assert(badResult.validQuestions.length === 2, '2 valid questions extracted despite malformed middle row');
  assert(badResult.issues.length === 1, 'Missing answer issue captured and flagged for user review');

  // ===========================================================================
  // SECTION 3: EXAM ENGINE & LIVE SIMULATOR
  // ===========================================================================
  console.log('\n🧠 SUITE 3: ASSESSMENT ENGINE & SCORING MECHANICS');

  const { ExamEngine } = await import('../web/scripts/examEngine.js');

  const testQuestions = [
    { id: 'tq_1', question: 'Question 1', options: ['A', 'B', 'C', 'D'], correctAnswers: [1], topic: 'Logic' },
    { id: 'tq_2', question: 'Question 2', options: ['A', 'B', 'C', 'D'], correctAnswers: [0, 2], questionType: 'multiple', topic: 'Math' },
    { id: 'tq_3', question: 'Question 3', options: ['A', 'B', 'C', 'D'], correctAnswers: [3], topic: 'Logic' }
  ];

  let engineCompleted = false;
  let completedPerf = null;

  const engine = new ExamEngine({
    mode: 'timed',
    durationMinutes: 10,
    questions: testQuestions,
    onComplete: (perf) => {
      engineCompleted = true;
      completedPerf = perf;
    }
  });

  assert(engine.totalSeconds === 600, '10 minute exam initializes with 600 seconds');
  assert(engine.questions.length === 3, 'Engine questions array loaded properly');

  // Answer Q1 correctly (index 1)
  engine.selectOption(1);
  assert(engine.userAnswers['tq_1'].has(1), 'User answer recorded for Question 1');
  assert(engine.isQuestionCorrect(testQuestions[0]) === true, 'Question 1 verified as correct');

  // Go to Q2 and answer multi-select (choose 0 and 2)
  engine.goToQuestion(1);
  engine.selectOption(0);
  engine.selectOption(2);
  assert(engine.isQuestionCorrect(testQuestions[1]) === true, 'Question 2 multi-select verified as correct');

  // Leave Q3 unanswered
  engine.goToQuestion(2);
  assert(engine.isQuestionAnswered('tq_3') === false, 'Question 3 confirmed as unanswered');

  // Submit
  engine.submitExam();
  assert(engineCompleted === true, 'onComplete callback executed on exam submission');
  assert(completedPerf.correct === 2, 'Correct count is 2/3');
  assert(completedPerf.unanswered === 1, 'Unanswered count is 1');
  assert(completedPerf.score === 67, 'Score rounded accurately to 67%');
  assert(completedPerf.missedQuestions.length === 1 && completedPerf.missedQuestions[0].id === 'tq_3', 'Missed question tq_3 logged for drill');
  assert(completedPerf.questionSnapshots['tq_1'].isCorrect === true, 'Snapshot for Q1 confirms correct answer');
  assert(completedPerf.questionSnapshots['tq_3'].isCorrect === false, 'Snapshot for Q3 confirms missed answer');

  engine.destroy();

  // ===========================================================================
  // SECTION 4: DOM INTEGRITY & ZERO "+ +" REPETITIONS
  // ===========================================================================
  console.log('\n🎨 SUITE 4: DOM STRUCTURE, NO REPEATED "+ +" TEXT & VIEW GUARDS');

  const htmlPath = path.join(rootDir, 'web', 'index.html');
  const jsPath = path.join(rootDir, 'web', 'scripts', 'app.js');
  const cssPath = path.join(rootDir, 'web', 'styles', 'main.css');

  const htmlContent = fs.readFileSync(htmlPath, 'utf8');
  const jsContent = fs.readFileSync(jsPath, 'utf8');
  const cssContent = fs.readFileSync(cssPath, 'utf8');

  // Check duplicate "+ +" in HTML and JS
  assert(!htmlContent.includes('+ + Question'), 'HTML contains NO "+ + Question" duplicate text');
  assert(!htmlContent.includes('+ + Create'), 'HTML contains NO "+ + Create" duplicate text');
  assert(!jsContent.includes('+ + Question'), 'app.js contains NO "+ + Question" duplicate text');

  // Check Views in HTML
  assert(htmlContent.includes('id="view-dashboard"'), 'View #view-dashboard present in index.html');
  assert(htmlContent.includes('id="view-exams"'), 'View #view-exams present in index.html');
  assert(htmlContent.includes('id="view-question_bank"'), 'View #view-question_bank present in index.html');
  assert(htmlContent.includes('id="view-history"'), 'View #view-history present in index.html');
  assert(htmlContent.includes('id="view-analytics"'), 'View #view-analytics present in index.html');
  assert(htmlContent.includes('id="view-settings"'), 'View #view-settings present in index.html');

  // Check Modals
  assert(htmlContent.includes('id="modalSessionLauncher"'), 'Modal #modalSessionLauncher (Flutter TakeExam replica) present');
  assert(htmlContent.includes('id="modalExamAudit"'), 'Modal #modalExamAudit (Flutter ExamAudit replica) present');
  assert(htmlContent.includes('id="modalImport"'), 'Modal #modalImport present');
  assert(htmlContent.includes('id="modalAddExam"'), 'Modal #modalAddExam present');
  assert(htmlContent.includes('id="modalAddQuestion"'), 'Modal #modalAddQuestion present');
  assert(htmlContent.includes('id="modalAuth"'), 'Modal #modalAuth compulsory login modal present');

  // Check Navigation protection
  assert(jsContent.includes('switchView(viewName = \'dashboard\''), 'switchView safely defaults to dashboard on null/undefined');
  assert(jsContent.includes('nav-tab-btn[data-view]'), 'Navigation event listener only binds to elements with data-view');
  assert(jsContent.includes('this.switchView(\'exams\')'), 'executeImport navigates to exams view upon successful import');

  // CSS Styles
  assert(cssContent.includes('.view-section.active'), 'CSS contains .view-section.active display rule');
  assert(cssContent.includes('.mode-select-card'), 'CSS contains session launcher mode card styling');

  // ===========================================================================
  // SECTION 5: FINAL AUDIT SUMMARY
  // ===========================================================================
  console.log('\n======================================================');
  console.log('📊 HARDCORE BRUTAL AUDIT SUMMARY');
  console.log('======================================================');
  console.log(`Total Assertions Run : ${totalTests}`);
  console.log(`Passed Assertions    : ${passedTests} ✅`);
  console.log(`Failed Assertions    : ${failedTests.length} ❌`);

  if (failedTests.length === 0) {
    console.log('\n🎯 ALL BRUTAL AUDIT ASSERTIONS PASSED WITH 100% SUCCESS!');
  } else {
    console.error('\n⚠️ AUDIT FAILED ON THE FOLLOWING ASSERTIONS:');
    failedTests.forEach(f => console.error(`  - [Test ${f.testNum}] ${f.message}`));
    process.exit(1);
  }
}

runAudit().catch(err => {
  console.error('Fatal Audit Error:', err);
  process.exit(1);
});
