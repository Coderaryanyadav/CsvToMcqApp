# QUIZPRO — USER JOURNEY VERIFICATION AUDIT

## End-to-End User Flow Execution and Persistence Analysis

**Date:** 2026-09-07  
**Platform Tested:** Flutter 3.x / Android Emulator (ARM64) + Unit/Widget Harness

---

### Verified User Journeys

#### Journey 1: First-Time Onboarding & Profile Creation
1. **Action:** App launches with no prior profile in storage.
2. **State:** Detects empty student list, routes to `WelcomeScreen`.
3. **Execution:** User enters name (e.g., "Alex Walker"), selects avatar `student_01`, chooses accent color `Indigo`, taps **Save & Continue**.
4. **Result:** `DatabaseService` creates `students.json` with unique UUID, sets active student, seeds initial exams, and transitions to `HomeScreen`.
5. **Persistence Check:** Cold app restart successfully recovers "Alex Walker" without re-showing onboarding.
- **Verdict: PASS**

#### Journey 2: Multi-Student Profile Isolation
1. **Action:** Create "Student A" and "Student B".
2. **Execution:** Switch between Student A and Student B via header profile switcher.
3. **Verification:**
   - Student A's exam history, mistakes bank, and analytics remain strictly in `student_<idA>_performance.json` and `student_<idA>_mistakes.json`.
   - Student B sees fresh, isolated metrics and separate mistake tracking.
- **Verdict: PASS**

#### Journey 3: Exam Creation, Question Management & Bank Quality Audit
1. **Action:** Navigate to Exams tab -> tap **Create Exam** -> add title "Cloud Architecture".
2. **Question Management:** Add single-choice and multiple-choice questions with explanations.
3. **Quality Audit:** Tap **Audit Bank Health** -> engine evaluates options count, difficulty spread, duplicate prompts, and answer index bounds.
4. **Result:** Exam saves atomically to `exams.json`. All questions render accurately with complete explanations.
- **Verdict: PASS**

#### Journey 4: CSV / Excel Parsing & Question Bank Ingestion
1. **Action:** Tap **Import CSV / Excel** -> select template file.
2. **Parsing Rules:** Validates headers (`Question`, `Option A`, `Option B`, `Option C`, `Option D`, `Correct Answer`, `Explanation`, `Topic`, `Difficulty`).
3. **Validation & Errors:** Flags invalid answer keys, empty options, or duplicate rows before commit.
4. **Commit:** Imports valid rows directly into target exam bank.
- **Verdict: PASS**

#### Journey 5: Live Exam Session, Timer & State Resilience
1. **Action:** Launch timed exam (e.g., 10 minutes, 10 questions).
2. **Session Persistence:** Answer selection updates in-memory state and autosaves checkpoint to disk.
3. **Timer Mechanics:** Timer measures elapsed wall-clock time (`DateTime.now().difference(startTime)`), ensuring backgrounding, screen sleep, or orientation change does not artificially freeze or extend exam time.
4. **Interruption Recovery:** Force-killing the app during an active exam safely preserves answers upon restart.
- **Verdict: PASS**

#### Journey 6: Practice Mode with Instant Feedback
1. **Action:** Toggle Practice Mode on exam launch or select "Practice Mistakes".
2. **Execution:** Selecting an answer allows tapping **Show Answer & Explanation**.
3. **Visual Feedback:** Correct option highlights green; incorrect option highlights red with full explanation card.
- **Verdict: PASS**

#### Journey 7: Exam Grading, Result Analysis & Mistakes Tracking
1. **Action:** Submit exam -> `GradingEngine` calculates score, percentage, time spent, and pass/fail verdict.
2. **Mistakes Isolation:** Incorrect questions are automatically saved to the active student's mistakes repository.
3. **Navigation:** User can tap **Practice Mistakes**, **Retake Exam**, or **Back to Dashboard**.
- **Verdict: PASS**

#### Journey 8: Settings Configuration & Factory Reset
1. **Action:** Modify duration defaults, passing score threshold (e.g. 75%), toggle sound and haptics.
2. **Factory Reset:** Tap **Reset All Application Data** -> requires confirmation -> deletes all student files, performance logs, and exam files -> returns cleanly to WelcomeScreen.
- **Verdict: PASS**

---

### Journey Summary Matrix

| Journey | Description | Steps Verified | Edge Cases Tested | Status |
|---|---|---|---|---|
| **UJ-01** | First-Time Student Onboarding | 5 | Whitespace name, avatar selection, color theme | **PASS** |
| **UJ-02** | Multi-Student Profile Isolation | 4 | 2+ profiles, data partition, mistake isolation | **PASS** |
| **UJ-03** | Question Bank Management & Audit | 6 | Add/Edit/Duplicate/Delete question, quality audit | **PASS** |
| **UJ-04** | CSV / Excel Data Ingestion | 5 | Valid CSV, malformed rows, missing fields | **PASS** |
| **UJ-05** | Timed Exam & Autosave Recovery | 7 | Wall-clock timer, app kill, auto-submit | **PASS** |
| **UJ-06** | Practice Mode & Instant Explanations | 4 | Immediate reveal, review explanations | **PASS** |
| **UJ-07** | Results Breakdown & Mistake Bank | 5 | Score calculation, mistake auto-harvest | **PASS** |
| **UJ-08** | Settings & Destructive Data Reset | 4 | Setting changes, cold reboot, full reset | **PASS** |
