# QuizPro — Data Model & Schema Specifications

## 1. Entity Relationships

```
+------------------+          1:N          +----------------------+
|  StudentProfile  | --------------------> |   ExamPerformance    |
+------------------+                       +----------------------+
         | 1:1                                        |
         v                                            v
+------------------+                       +----------------------+
|    Bookmarks     |                       |  QuestionSnapshots   |
+------------------+                       +----------------------+

+------------------+          1:N          +----------------------+
|       Exam       | --------------------> |       Question       |
+------------------+                       +----------------------+
         | 1:1
         v
+------------------+
|   SessionState   |
+------------------+
```

---

## 2. Model Schemas

### `StudentProfile` (`students.json`)
```json
{
  "id": "uuid-v4-string",
  "name": "Alex Johnson",
  "avatarEmoji": "🎓",
  "avatarColorValue": 4280656875,
  "createdAt": "2026-09-13T10:00:00.000Z"
}
```

### `Exam` (`<examId>.json`)
```json
{
  "schemaVersion": 2,
  "id": "exam-uuid-v4",
  "name": "AWS Certified Solutions Architect",
  "description": "Comprehensive MCQ exam simulator",
  "category": "Cloud Computing",
  "provider": "Amazon Web Services",
  "code": "SAA-C03",
  "passingPercentage": 75,
  "defaultDuration": 30,
  "createdAt": "2026-09-13T10:00:00.000Z",
  "updatedAt": "2026-09-13T10:00:00.000Z",
  "questions": [
    {
      "id": "question-uuid-v4",
      "question": "Which AWS service provides serverless compute?",
      "questionType": "single",
      "options": ["AWS Lambda", "Amazon EC2", "Amazon S3", "Amazon RDS"],
      "correctAnswers": [0],
      "optionExplanations": {
        "0": "Lambda runs code without provisioning servers."
      },
      "topic": "Compute",
      "difficulty": 2,
      "tags": ["AWS", "Serverless"],
      "displayNumber": 1
    }
  ]
}
```

### `ExamPerformance` (`performance_<examId>_<timestamp>_<studentId>.json`)
```json
{
  "examId": "exam-uuid-v4",
  "examName": "AWS Certified Solutions Architect",
  "studentId": "student-uuid-v4",
  "studentName": "Alex Johnson",
  "date": "2026-09-13T12:00:00.000Z",
  "totalQuestions": 20,
  "correct": 18,
  "incorrect": 2,
  "unanswered": 0,
  "durationSeconds": 640,
  "timePerQuestion": {
    "question-uuid-v4": 32
  },
  "questionResults": {
    "question-uuid-v4": true
  },
  "weakTopics": [],
  "passingPercentage": 75,
  "topicPerformance": {
    "Compute": { "correct": 10, "total": 10 }
  },
  "difficultyPerformance": {
    "2": { "correct": 10, "total": 10 }
  },
  "questionSnapshots": {
    "question-uuid-v4": {
      "question": "Which AWS service provides serverless compute?",
      "topic": "Compute",
      "difficulty": 2,
      "userSelection": [0],
      "isCorrect": true
    }
  }
}
```

### `UserSettings` (`settings.json`)
```json
{
  "themeMode": "system",
  "darkMode": false,
  "fontSize": 16.0,
  "hapticFeedback": true,
  "soundEffects": false,
  "defaultDuration": 30,
  "defaultQuestionCount": 20,
  "defaultPassingScore": 75,
  "dailyGoal": 20,
  "activeStudentId": "student-uuid-v4",
  "schemaVersion": 2
}
```
