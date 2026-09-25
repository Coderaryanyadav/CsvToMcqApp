// Clean Starter Configuration for QuizPro Web
// Zero dummy data as per production requirements

export const DEFAULT_STUDENT = {
  id: 'student_primary',
  name: 'Student',
  avatarEmoji: '🎓',
  avatarColorValue: 0xFF2563EB,
  createdAt: new Date().toISOString()
};

// No pre-populated dummy exams
export const DEFAULT_EXAMS = [];

// On-demand sample exam generator for instant testing
export function createSampleDemoExam() {
  return {
    id: 'exam_sample_cloud_' + Date.now(),
    name: 'Cloud Computing & Web Fundamentals',
    category: 'Information Technology',
    provider: 'Cloud Native Prep',
    description: 'Comprehensive test covering HTTP architecture, distributed systems, CAP theorem, container orchestration, and SQL isolation.',
    defaultDuration: 15,
    passingPercentage: 70,
    createdAt: new Date().toISOString(),
    questions: [
      {
        id: 'q_sample_1',
        question: 'Which HTTP status code signifies that the server understands the request and authenticated credentials, but refuses authorization for the resource?',
        options: ['401 Unauthorized', '403 Forbidden', '404 Not Found', '405 Method Not Allowed'],
        correctAnswers: [1],
        questionType: 'single',
        explanation: 'HTTP 403 Forbidden indicates that the client is authenticated but does not possess the requisite access privileges. 401 Unauthorized means authentication credentials are missing or invalid.',
        topic: 'Web Networking',
        difficulty: 2
      },
      {
        id: 'q_sample_2',
        question: 'In distributed data architecture, what does Eric Brewer\'s CAP theorem state regarding network partitions?',
        options: [
          'A distributed system can guarantee Consistency, Availability, and Partition Tolerance simultaneously',
          'During a network partition, a distributed system must choose between Consistency and Availability',
          'Partition tolerance is only required for legacy relational database management systems',
          'Network partitions can be avoided completely using fiber optic connections'
        ],
        correctAnswers: [1],
        questionType: 'single',
        explanation: 'The CAP theorem states that in any asynchronous network where partitions (P) may occur, a distributed data store can satisfy either Consistency (C) or Availability (A), but fundamentally cannot guarantee both.',
        topic: 'Distributed Systems',
        difficulty: 3
      },
      {
        id: 'q_sample_3',
        question: 'What is the primary role of a container orchestrator such as Kubernetes in a microservices deployment?',
        options: [
          'Automated horizontal pod autoscaling, rolling zero-downtime updates, self-healing restarts, and service discovery',
          'Compiling all application code into native machine assembly instructions',
          'Permanently bypassing network routing tables and firewalls',
          'Eliminating all application-layer logging and monitoring requirements'
        ],
        correctAnswers: [0],
        questionType: 'single',
        explanation: 'Kubernetes manages container lifecycles, container placement, automated pod replication/scaling, rolling version deployments, traffic routing, and health check monitoring.',
        topic: 'DevOps & Containers',
        difficulty: 3
      },
      {
        id: 'q_sample_4',
        question: 'Which SQL database transaction isolation level prevents dirty reads, non-repeatable reads, and phantom reads?',
        options: ['Read Uncommitted', 'Read Committed', 'Repeatable Read', 'Serializable'],
        correctAnswers: [3],
        questionType: 'single',
        explanation: 'Serializable is the highest isolation level specified in SQL standards. It guarantees transactions execute as if done in sequential order, preventing dirty reads, non-repeatable reads, and phantom reads.',
        topic: 'Databases & Storage',
        difficulty: 4
      },
      {
        id: 'q_sample_5',
        question: 'What is the purpose of configuring "Cache-Control: max-age=86400" in HTTP response headers?',
        options: [
          'Instructs browser and intermediate proxy caches that the asset is fresh for 86,400 seconds (24 hours)',
          'Limits client request body payloads to 86,400 bytes',
          'Forces browser memory to flush cache every 86.4 milliseconds',
          'Terminates TLS handshake connections after 86,400 CPU cycles'
        ],
        correctAnswers: [0],
        questionType: 'single',
        explanation: 'The max-age directive indicates in seconds the maximum time that a cached resource is considered valid before a revalidation or new fetch is required from the origin server.',
        topic: 'Web Performance',
        difficulty: 2
      }
    ]
  };
}

