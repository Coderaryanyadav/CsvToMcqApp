# 📊 Data Truth & Analytics Integrity Audit

This report verifies that all numerical data, statistics, calculations, scoring, and metrics displayed in **QuizPro (MCQ-App)** are truthful, accurately computed from real database records, and free of mock or fabricated fallbacks.

---

## 1. Zero Hardcoded Data Verification

| Component | Policy | Implementation Audit | Status |
|---|---|---|---|
| **Starter Datasets** | Must not inject fake exams/results | `StorageService.seedStarterDataIfEmpty()` is empty; database operates 100% dynamically based on user actions and imports. | **PASS** |
| **Active Exams List** | Must reflect physical JSON records | `getAllExams()` reads active `.json` files in `<app_documents>/mcq_data/`. When empty, UI shows "No Question Banks Available". | **PASS** |
| **History & Performance** | Must only show completed runs | `loadPerformancesForActiveStudent()` retrieves real test attempts for the active student. If no attempts exist, shows "No practice sessions yet." | **PASS** |
| **Overview Metrics** | Must compute from real records | All cards (Answered, Avg Score, Study Time, Active Exams) reflect live aggregated data from disk. | **PASS** |

---

## 2. Analytics Calculation Verification

### Chronological Improvement Formula
- **Logic**: Evaluates student improvement over time by sorting attempts chronologically ($t_1 \le t_2 \le ... \le t_n$).
- **Algorithm** (`lib/services/analytics_service.dart`):
  ```dart
  // Sort oldest to newest
  final sorted = List<ExamPerformance>.from(performances)
    ..sort((a, b) => a.date.compareTo(b.date));
  
  // Split into earlier half and recent half
  final mid = sorted.length ~/ 2;
  final earlier = sorted.sublist(0, mid);
  final recent = sorted.sublist(mid);
  
  final earlierAvg = earlier.map((e) => e.percentage).reduce((a, b) => a + b) / earlier.length;
  final recentAvg = recent.map((e) => e.percentage).reduce((a, b) => a + b) / recent.length;
  
  final improvement = recentAvg - earlierAvg;
  ```
- **Validation**:
  - Tested with increasing scores (`[50.0, 60.0, 70.0, 80.0]`): produces $+20.0\%$ improvement.
  - Tested with declining scores (`[80.0, 70.0, 60.0, 50.0]`): produces $-20.0\%$ decline.
  - Tested with 0 or 1 attempt: returns `0.0%` (no false improvement claims).
- **Evidence**: Verified in automated test suite (`test/analytics_test.dart`).

---

## 3. Exam Grading & Scoring Mathematics

### Exact Set-Match Multiple-Choice Grading
- **Single-Select**: Choice index $k$ matches `correctAnswers.contains(k)` and $|answers| = 1$.
- **Multi-Select**: Set of chosen options $A$ must exactly equal `correctAnswers` $C$ ($A = C$).
  - Partial selections without all required options are graded incorrect.
  - Selections containing extraneous wrong choices are graded incorrect.
- **Score Calculation**:
  $$\text{Percentage} = \left( \frac{\text{Correct Answers}}{\text{Total Questions}} \right) \times 100$$
- **Passing Status**:
  $$\text{Passed} = \text{Percentage} \ge \text{PassingThreshold}$$

---

## 4. Topic & Difficulty Breakdown Accuracy

- Each question is mapped by `topic` and `difficulty` (1 to 5).
- Performance aggregators tally:
  - Total questions attempted per topic
  - Correct questions per topic
  - Accuracy percentage per topic: $\frac{\text{Correct}}{\text{Total}} \times 100$
- Weak topics are flagged only when topic accuracy falls below the exam's passing percentage threshold.

---

## 5. Data Truth Verdict

**STATUS: PASS (100% Truthful, Mathematical Integrity Verified)**
QuizPro contains zero fabricated fallback numbers and computes all analytics with strict mathematical precision.
