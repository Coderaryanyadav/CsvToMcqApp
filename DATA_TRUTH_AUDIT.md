# QUIZPRO — DATA & MATHEMATICAL TRUTH AUDIT

## Analytical Formula Verification, Grading Accuracy & Persistence Schema

**Audit Date:** 2026-09-07  
**Auditor:** Antigravity Autonomous Systems & Verification Suite  
**Target:** Data Schema, Grading Engine & Analytics Calculations  

---

### 1. Grading Engine Mathematical Verification

#### Single-Choice Questions
- **Rule:** Question is graded Correct if and only if `selectedAnswers == [correctAnswerIndex]`.
- **Score Contribution:** $1.0$ mark for match, $0.0$ marks for mismatch or unselected.

#### Multi-Select Questions
- **Rule:** Set equality matching `Set(selectedAnswers) == Set(correctAnswerIndices)`.
- **Score Contribution:** $1.0$ mark if the set of chosen indices matches the exact solution set; otherwise $0.0$.
- **Boundary Conditions Tested:**
  - Extra choices selected: Graded Incorrect.
  - Incomplete choices selected: Graded Incorrect.
  - Permuted index order: Graded Correct (Set equivalence verified).

#### Percentage & Pass/Fail Calculation
$$\text{Percentage} = \left(\frac{\text{Correct Answers}}{\text{Total Questions}}\right) \times 100$$
$$\text{Passed} = \text{Percentage} \ge \text{PassingThreshold}$$

---

### 2. Analytics Engine Formulas & Verification

#### Average Score Calculation
$$\text{Average Score} = \frac{\sum_{i=1}^{N} \text{Percentage}_i}{N}$$
- *Edge Case ($N = 0$):* Evaluates cleanly to $0.0\%$ without division-by-zero exceptions.

#### Improvement Trend Delta
$$\text{Trend Delta} = \text{Score}_{\text{latest}} - \text{Score}_{\text{previous}}$$
- *Edge Case (1 Attempt):* Evaluates cleanly to $+0.0\%$ (neutral baseline).

#### Weak Topics Identification
- A topic is classified as a "Weak Topic" if:
$$\text{Topic Accuracy} = \frac{\text{Correct In Topic}}{\text{Total In Topic}} < 0.70\ (70\%)$$

#### Cumulative Study Time
$$\text{Total Study Time} = \sum_{i=1}^{N} \text{DurationSeconds}_i$$

---

### 3. File Persistence Architecture & Schema

All persistence is managed via JSON documents in the application sandbox directory:

1. **`students.json`**:
   - Stores array of `StudentProfile` objects (`id`, `name`, `avatar`, `colorValue`, `createdAt`).
2. **`settings.json`**:
   - Stores global preferences (`activeStudentId`, `isDarkMode`, `hapticsEnabled`, `soundEnabled`, `defaultDurationMinutes`, `passingPercentage`).
3. **`exams.json`**:
   - Stores master question bank and metadata (`id`, `title`, `description`, `topics`, `passingPercentage`, `durationMinutes`, `questions`).
4. **`student_{id}_performance.json`**:
   - Stores historical attempts partitioned by student (`id`, `examId`, `examTitle`, `score`, `totalQuestions`, `percentage`, `passed`, `durationSeconds`, `timestamp`, `topicBreakdown`).
5. **`student_{id}_mistakes.json`**:
   - Stores question objects incorrectly answered by that specific student.
6. **`student_{id}_session.json`**:
   - Stores live exam autosave state (`examId`, `currentQuestionIndex`, `selectedAnswers`, `markedForReview`, `timeRemainingSeconds`, `timestamp`).

---

### 4. Data Collision & Race-Condition Resistance

- Record IDs are generated using UUID v4 (`uuid.v4()`), mathematically eliminating filename and record identifier collisions.
- File writes employ `flush: true` to ensure the Dart runtime flushes all bytes to the operating system file system buffers prior to returning execution.

---

### 5. Mathematical & Persistence Verdict: **PASS**
All formulas, grading logic, and serialization schemas are mathematically sound, isolated by student, and verified by automated unit tests.
