import puppeteer from 'puppeteer-core';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

const CHROME_PATH = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const APP_URL = 'http://localhost:8089/';

// Realistic, rich test data
const sampleExam = {
  id: 'exam_aws_architect_2026',
  name: 'AWS Certified Solutions Architect (SAA-C03)',
  category: 'Cloud Architecture & DevOps',
  provider: 'Amazon Web Services',
  description: 'Rigorous exam measuring distributed cloud systems, VPC networking, fault-tolerant HA multi-tier applications, IAM least privilege, and high throughput S3/DynamoDB architectures.',
  defaultDuration: 30,
  passingPercentage: 72,
  createdAt: new Date().toISOString(),
  questions: [
    {
      id: 'q1',
      question: 'A company runs a high-traffic web application on an Auto Scaling group of EC2 instances behind an Application Load Balancer. Users report sporadic latency spikes during database-heavy reporting hours. The database is a single Multi-AZ Amazon RDS PostgreSQL instance. Which architectural solution will offload read traffic with minimal operational overhead?',
      options: [
        'Deploy ElastiCache Redis cluster and migrate all relational queries to Redis key-value pairs',
        'Create an Amazon RDS Read Replica and update reporting queries to direct read requests to the read replica endpoint',
        'Upgrade EC2 instances to memory-optimized instances and enable AWS Global Accelerator',
        'Set up Amazon DynamoDB global tables with cross-region active-active replication'
      ],
      correctAnswers: [1],
      questionType: 'single',
      explanation: 'Amazon RDS Read Replicas offload read traffic from the primary read/write database instance. Applications direct read queries directly to the Read Replica endpoints.',
      topic: 'Databases & Storage',
      chapter: 'Database Scaling',
      difficulty: 3
    },
    {
      id: 'q2',
      question: 'Which of the following IAM policies adheres strictly to the principle of least privilege for an S3 storage bucket containing private financial audit records?',
      options: [
        'Granting s3:* on arn:aws:s3:::* to all IAM roles in the root organization',
        'Granting s3:GetObject and s3:ListBucket strictly scoped to the specific bucket ARN with MFA-required conditions',
        'Setting public read permissions via an Amazon S3 Bucket Policy with wildcard resource actions',
        'Attaching AdministratorAccess to all backend compute instance EC2 profiles'
      ],
      correctAnswers: [1],
      questionType: 'single',
      explanation: 'Least privilege dictates granting strictly the required actions (s3:GetObject, s3:ListBucket) restricted to the target bucket ARN, augmented by conditional multi-factor authentication (MFA).',
      topic: 'Security & IAM',
      chapter: 'Identity and Access Management',
      difficulty: 2
    },
    {
      id: 'q3',
      question: 'Select the TWO AWS services best suited for building completely event-driven, serverless asynchronous processing workflows without managing operating system patches.',
      options: [
        'AWS Lambda functions triggered by Amazon SQS queues',
        'Self-hosted Kafka cluster on an EC2 i3en storage cluster',
        'AWS Step Functions orchestrating distributed microservices tasks',
        'Amazon EC2 reserved instances behind a Classic Load Balancer'
      ],
      correctAnswers: [0, 2],
      questionType: 'multiple',
      explanation: 'AWS Lambda and AWS Step Functions are cloud-native serverless compute and state orchestration services requiring zero server management.',
      topic: 'Serverless Architecture',
      chapter: 'Compute & Orchestration',
      difficulty: 3
    },
    {
      id: 'q4',
      question: 'In a VPC peering configuration across two VPCs (VPC-A: 10.0.0.0/16 and VPC-B: 10.1.0.0/16), traffic fails to reach subnets in VPC-B from VPC-A. What is the most likely root cause?',
      options: [
        'VPC Peering does not support IPv4 CIDR blocks with /16 subnet masks',
        'Route tables in VPC-A and VPC-B lack explicit routes pointing to the VPC Peering connection (pcx-xxxx)',
        'The VPCs must be merged into a single AWS Transit Gateway',
        'Internet Gateway must be attached to both subnets with NAT Gateway disabled'
      ],
      correctAnswers: [1],
      questionType: 'single',
      explanation: 'Even when a VPC Peering connection is active, route tables in each VPC must be explicitly updated with the peer CIDR range destination and target peering connection id.',
      topic: 'VPC Networking',
      chapter: 'Cloud Networking',
      difficulty: 4
    }
  ]
};

const sampleExam2 = {
  id: 'exam_fullstack_ts',
  name: 'Modern Full-Stack TypeScript & Systems',
  category: 'Software Engineering',
  provider: 'QuizPro Academy',
  description: 'Advanced assessment covering TypeScript type-level programming, Node.js event loops, memory leaks, and distributed caching.',
  defaultDuration: 20,
  passingPercentage: 75,
  createdAt: new Date().toISOString(),
  questions: [
    {
      id: 'q_ts_1',
      question: 'What is the runtime time-complexity of accessing a Map value by key in JavaScript V8 engine on average?',
      options: ['O(1)', 'O(log n)', 'O(n)', 'O(n^2)'],
      correctAnswers: [0],
      questionType: 'single',
      explanation: 'JavaScript Map uses an internal hash table implementation providing near O(1) constant average lookup performance.',
      topic: 'Data Structures',
      chapter: 'Core Algorithms',
      difficulty: 1
    }
  ]
};

const samplePerformance = {
  id: 'perf_demo_super_score',
  examId: 'exam_aws_architect_2026',
  examName: 'AWS Certified Solutions Architect (SAA-C03)',
  studentId: 'student_primary',
  studentName: 'Aryan Yadav',
  completedAt: new Date(Date.now() - 3600000).toISOString(),
  date: new Date(Date.now() - 3600000).toISOString(),
  score: 88,
  passed: true,
  totalQuestions: 25,
  correct: 22,
  incorrect: 3,
  unanswered: 0,
  durationSeconds: 1120,
  timeTakenSeconds: 1120,
  accuracy: 88,
  missedQuestions: ['q4'],
  topicBreakdown: {
    'Databases & Storage': { total: 8, correct: 8, percentage: 100 },
    'Security & IAM': { total: 7, correct: 6, percentage: 85.7 },
    'VPC Networking': { total: 5, correct: 4, percentage: 80 },
    'Serverless Architecture': { total: 5, correct: 4, percentage: 80 }
  },
  detailedAnswers: [
    { questionId: 'q1', questionText: sampleExam.questions[0].question, selectedIndices: [1], correctIndices: [1], isCorrect: true, topic: 'Databases & Storage', explanation: sampleExam.questions[0].explanation },
    { questionId: 'q2', questionText: sampleExam.questions[1].question, selectedIndices: [1], correctIndices: [1], isCorrect: true, topic: 'Security & IAM', explanation: sampleExam.questions[1].explanation },
    { questionId: 'q3', questionText: sampleExam.questions[2].question, selectedIndices: [0, 2], correctIndices: [0, 2], isCorrect: true, topic: 'Serverless Architecture', explanation: sampleExam.questions[2].explanation },
    { questionId: 'q4', questionText: sampleExam.questions[3].question, selectedIndices: [0], correctIndices: [1], isCorrect: false, topic: 'VPC Networking', explanation: sampleExam.questions[3].explanation }
  ]
};

const samplePerformance2 = {
  id: 'perf_demo_score_2',
  examId: 'exam_fullstack_ts',
  examName: 'Modern Full-Stack TypeScript & Systems',
  studentId: 'student_primary',
  studentName: 'Aryan Yadav',
  completedAt: new Date(Date.now() - 86400000).toISOString(),
  date: new Date(Date.now() - 86400000).toISOString(),
  score: 95,
  passed: true,
  totalQuestions: 20,
  correct: 19,
  incorrect: 1,
  unanswered: 0,
  durationSeconds: 740,
  timeTakenSeconds: 740,
  accuracy: 95,
  missedQuestions: [],
  topicBreakdown: {
    'Data Structures': { total: 10, correct: 10, percentage: 100 },
    'System Design': { total: 10, correct: 9, percentage: 90 }
  },
  detailedAnswers: []
};

async function seedData(page) {
  await page.evaluate(({ sampleExam, sampleExam2, samplePerformance, samplePerformance2 }) => {
    localStorage.setItem('quizpro_v3_clean_slate', 'true');
    localStorage.setItem('quizpro_exams_v3', JSON.stringify([sampleExam, sampleExam2]));
    localStorage.setItem('quizpro_students_v3', JSON.stringify([
      { id: 'student_primary', name: 'Aryan Yadav', avatarEmoji: '⚡', avatarColorValue: 0xFF2563EB, createdAt: new Date().toISOString() }
    ]));
    localStorage.setItem('quizpro_active_student_id_v3', 'student_primary');
    localStorage.setItem('quizpro_performances_v3', JSON.stringify([samplePerformance, samplePerformance2]));
    localStorage.setItem('quizpro_bookmarks_v3', JSON.stringify({
      [sampleExam.id]: ['q1', 'q3']
    }));
    localStorage.setItem('quizpro_settings_v3', JSON.stringify({
      theme: 'dark',
      soundEnabled: true,
      keyboardShortcuts: true,
      showExplanationsImmediately: true
    }));
  }, { sampleExam, sampleExam2, samplePerformance, samplePerformance2 });
}

async function captureAll() {
  console.log('🚀 Launching Chromium instance with Chrome binary...');
  const browser = await puppeteer.launch({
    executablePath: CHROME_PATH,
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-web-security',
      '--window-size=2560,1600'
    ]
  });

  const viewports = [
    {
      name: 'Desktop_4K',
      folder: 'Screenshots/UltraHD_Desktop',
      width: 2560,
      height: 1440,
      deviceScaleFactor: 2 // 5120x2880 Ultra-HD Retina
    },
    {
      name: 'Mobile_ProMax',
      folder: 'Screenshots/UltraHD_Mobile',
      width: 430,
      height: 932,
      deviceScaleFactor: 3 // 1290x2796 Ultra-HD Retina
    }
  ];

  for (const vp of viewports) {
    console.log(`\n📸 Starting Ultra-HD captures for [${vp.name}] (${vp.width}x${vp.height} @ ${vp.deviceScaleFactor}x)...`);
    const page = await browser.newPage();
    await page.setViewport({
      width: vp.width,
      height: vp.height,
      deviceScaleFactor: vp.deviceScaleFactor
    });

    await page.goto(APP_URL, { waitUntil: 'networkidle0' });
    await seedData(page);
    await page.reload({ waitUntil: 'networkidle0' });
    await page.waitForFunction(() => !!window.app);
    await new Promise(r => setTimeout(r, 800));

    const takeShot = async (filename, waitMs = 500) => {
      if (waitMs > 0) await new Promise(r => setTimeout(r, waitMs));
      const outPath = path.join(rootDir, vp.folder, filename);
      await page.screenshot({ path: outPath, fullPage: false });
      console.log(`  ✅ Captured: ${filename}`);
    };

    // 1. Dashboard Screen
    await page.evaluate(() => window.app.switchView('dashboard'));
    await takeShot('01_Executive_Dashboard.png', 700);

    // 2. Exam Catalog Screen
    await page.evaluate(() => window.app.switchView('exams'));
    await takeShot('02_Exam_Catalog.png', 700);

    // 3. Question Bank & Chapter Matrix Screen
    await page.evaluate(() => window.app.switchView('question_bank'));
    await takeShot('03_Question_Bank_Matrix.png', 700);

    // 4. Analytics & Performance Intelligence Screen
    await page.evaluate(() => window.app.switchView('analytics'));
    await takeShot('04_Performance_Analytics.png', 700);

    // 5. Exam History & Detailed Past Sessions Screen
    await page.evaluate(() => window.app.switchView('history'));
    await takeShot('05_Exam_History.png', 700);

    // 6. Settings Screen
    await page.evaluate(() => window.app.switchView('settings'));
    await takeShot('06_Settings_Preferences.png', 700);

    // 7. Interactive Practice Mode Screen
    await page.evaluate(() => {
      const exams = JSON.parse(localStorage.getItem('quizpro_exams_v3') || '[]');
      if (exams.length > 0) {
        window.app.switchView('practice', { examId: exams[0].id });
      }
    });
    // Select an option to show active state
    await page.evaluate(() => {
      const opt = document.querySelector('.quiz-option-card');
      if (opt) opt.click();
    });
    await takeShot('07_Interactive_Practice_Mode.png', 800);

    // 8. Timed Exam Session Screen
    await page.evaluate(() => {
      const exams = JSON.parse(localStorage.getItem('quizpro_exams_v3') || '[]');
      if (exams.length > 0) {
        window.app.switchView('exam', { examId: exams[0].id, duration: 25 });
      }
    });
    await takeShot('08_Timed_Exam_Simulation.png', 800);

    // 9. Comprehensive Score & Results Screen
    await page.evaluate(({ samplePerformance }) => {
      window.app.switchView('results', { performance: samplePerformance });
    }, { samplePerformance });
    await takeShot('09_Score_Results_Screen.png', 800);

    // 10. Exam Audit & Question Review Breakdown Modal
    await page.evaluate(({ samplePerformance }) => {
      window.app.openAuditModal(samplePerformance.id);
    }, { samplePerformance });
    await takeShot('10_Exam_Audit_Breakdown_Modal.png', 700);
    await page.evaluate(() => {
      const btn = document.querySelector('#modalExamAudit .btn-close-modal');
      if (btn) btn.click();
    });

    // 11. Start Assessment / Session Launcher Modal
    await page.evaluate(() => {
      window.app.switchView('exams');
      const exams = JSON.parse(localStorage.getItem('quizpro_exams_v3') || '[]');
      if (exams.length > 0) {
        window.app.openSessionLauncherModal({ examId: exams[0].id });
      }
    });
    await takeShot('11_Session_Launcher_Modal.png', 700);
    await page.evaluate(() => {
      const btn = document.querySelector('#modalSessionLauncher .btn-close-modal');
      if (btn) btn.click();
    });

    // 12. Smart CSV / Excel Importer Modal
    await page.evaluate(() => {
      window.app.switchView('exams');
      const btn = document.getElementById('btnOpenImportModal');
      if (btn) btn.click();
    });
    await takeShot('12_Import_Questions_Modal.png', 700);
    await page.evaluate(() => {
      const btn = document.querySelector('#modalImport .btn-close-modal');
      if (btn) btn.click();
    });

    // 13. Create & Configure New Exam Modal
    await page.evaluate(() => {
      window.app.switchView('exams');
      const btn = document.getElementById('btnOpenCreateExamModal');
      if (btn) btn.click();
    });
    await takeShot('13_Create_Edit_Exam_Modal.png', 700);
    await page.evaluate(() => {
      const btn = document.querySelector('#modalAddExam .btn-close-modal');
      if (btn) btn.click();
    });

    // 14. Add / Edit Question Editor Modal
    await page.evaluate(() => {
      window.app.switchView('exams');
      const btn = document.getElementById('btnOpenAddQuestionModal');
      if (btn) btn.click();
    });
    await takeShot('14_Question_Editor_Modal.png', 700);
    await page.evaluate(() => {
      const btn = document.querySelector('#modalAddQuestion .btn-close-modal');
      if (btn) btn.click();
    });

    await page.close();
  }

  await browser.close();
  console.log('\n🎉 ALL ULTRA-HD SCREENSHOTS GENERATED SUCCESSFULLY!');
}

captureAll().catch(err => {
  console.error('Fatal error during capture:', err);
  process.exit(1);
});
