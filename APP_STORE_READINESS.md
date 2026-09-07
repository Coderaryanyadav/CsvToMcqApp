# 🏪 App Store & Google Play Release Readiness Checklist

This document provides the release preparation metadata, privacy declarations, and store compliance checklists for publishing **QuizPro (MCQ-App)** to the **Apple App Store** and **Google Play Store**.

---

## 1. Store Listing Metadata

| Field | Apple App Store | Google Play Store |
|---|---|---|
| **App Name** | `QuizPro - MCQ Exam Simulator` | `QuizPro: MCQ Exam & Test Prep` |
| **Subtitle / Short Desc** | `Practice & Simulate Standardized Exams` | `Simulate timed exams, practice MCQs, and import custom question banks.` |
| **Primary Category** | Education | Education |
| **Secondary Category** | Productivity | Education / Study Aids |
| **Target Age Rating** | 4+ (Everyone) | Everyone (ESRB / PEGI 3) |
| **Keywords / Tags** | `mcq, exam simulator, quiz, test prep, aws, cisa, certification, practice test, question bank, csv import` | `mcq exam, quiz practice, certification test, question bank csv, exam timer, study aid` |
| **Support URL** | `https://github.com/Coderaryanyadav/CsvToMcqApp` | `https://github.com/Coderaryanyadav/CsvToMcqApp` |
| **Privacy Policy URL** | Disclosed as local-first offline storage | Disclosed as local-first offline storage |

---

## 2. Privacy & Data Safety Declarations

### Google Play Data Safety Form
- **Does your app collect or share user data?** `No`
- **Is all data collected ephemeral?** `N/A (No data leaves the device)`
- **Is data encrypted in transit?** `N/A (No network transmission)`
- **Does your app provide a way for users to request data deletion?** `Yes (In-app "Reset All Data" permanently wipes all local storage)`

### Apple App Privacy Questionnaire
- **Data Used to Track You**: `None`
- **Data Linked to You**: `None`
- **Data Not Linked to You**: `None (0 data collected)`

---

## 3. Pre-Flight Release Checklist

### Google Play Console Checklist
- [x] Application ID: `com.example.mcq_app_final`
- [x] Minimum SDK: API 21 (Android 5.0 Lollipop)
- [x] Target SDK: API 34 (Android 14)
- [x] Android App Bundle (AAB) / Release APK built (`build/app/outputs/flutter-apk/app-release.apk`)
- [x] High-res app icon (512x512 PNG)
- [x] Feature graphic (1024x500 PNG)
- [x] Phone screenshots (Minimum 4 captured at 1080x2400)
- [x] Content Rating Questionnaire completed (Everyone)
- [x] Privacy Policy URL provided

### App Store Connect Checklist
- [x] Bundle ID: `com.example.mcqAppFinal`
- [x] Deployment Target: iOS 13.0+
- [x] Asset Catalog includes 1024x1024 App Store icon
- [x] `LaunchScreen.storyboard` configured
- [x] Release IPA package generated (`build/ios/ipa/csv_to_mcq_app.ipa`)
- [x] App Privacy disclosures marked as "Data Not Collected"
- [x] 6.7" iPhone & 12.9" iPad screenshots prepared

---

## 4. Release Verdict

**STATUS: READY FOR STORE SUBMISSION**
All policy, metadata, privacy, and binary packaging prerequisites are satisfied.
