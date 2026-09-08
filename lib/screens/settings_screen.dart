import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/student_profile.dart';
import '../services/storage_service.dart';
import '../services/import_service.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> settings = {
    'themeMode': 'system',
    'fontSize': 16.0,
    'hapticFeedback': true,
    'soundEffects': false,
    'defaultDuration': 30,
    'defaultQuestionCount': 20,
    'defaultPassingScore': 75,
    'dailyGoal': 20,
  };
  bool loading = true;
  StudentProfile? activeStudent;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loaded = await StorageService.loadSettings();
    final student = await StorageService.getActiveStudent();
    if (mounted) {
      setState(() {
        settings = loaded;
        activeStudent = student;
        loading = false;
      });
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() {
      settings[key] = value;
    });
    if (key == 'themeMode') {
      AppTheme.setThemeMode(value.toString());
    }
    await StorageService.saveSettings(settings);
  }

  Future<void> _exportAllData() async {
    try {
      final fullData = await StorageService.exportFullBackupData();
      final jsonText = const JsonEncoder.withIndent('  ').convert(fullData);
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Full QuizPro Backup Package',
        fileName:
            'QuizPro_Full_Backup_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonText);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Complete package exported successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.restore_page_outlined,
                color: AppTheme.accentBlue, size: 24),
            SizedBox(width: 8),
            Text('Restore From Backup'),
          ],
        ),
        content: const Text(
          'Restoring a backup will merge and update all student profiles, exam tracks, question banks, bookmarks, and past attempt history.\n\nWould you like to proceed and select a backup JSON file?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Select Backup File'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await BackupService.pickAndRestoreBackup();
    if (!mounted) return;

    if (result.success) {
      await _loadSettings();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.success, size: 24),
              SizedBox(width: 8),
              Text('Restore Complete'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${result.message}\n',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              _buildRestoreStat('Student Profiles', result.studentsRestored),
              _buildRestoreStat('Exam Question Banks', result.examsRestored),
              _buildRestoreStat(
                  'Practice Performances', result.performancesRestored),
              _buildRestoreStat(
                  'Bookmarked Questions', result.bookmarksRestored),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } else if (result.message != 'No file selected.') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Widget _buildRestoreStat(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: AppTheme.secondaryText, fontSize: 13)),
          Text('$count',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _saveSampleCsv() async {
    try {
      final template = ImportService.getSampleCsvTemplate();
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Sample CSV Template',
        fileName: 'quizpro_template.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(template);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sample CSV template saved!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save template: $e'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  Future<void> _confirmResetData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Application Data?'),
        content: const Text(
          'This will permanently delete all created exams, question banks, bookmarks, and practice attempt history. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.clearAllData();
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data has been reset.'),
            backgroundColor: AppTheme.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 0. STUDENT PROFILE SECTION
                _sectionHeader(
                    'Student Profile & Multi-User', Icons.person_outline),
                Card(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (activeStudent != null
                                ? Color(activeStudent!.avatarColorValue)
                                : AppTheme.primaryNavy)
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          activeStudent?.avatarEmoji ?? '🎓',
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    title: Text(
                      activeStudent?.name ?? 'No Student Selected',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: const Text(
                      'Switch or create student profiles with separate statistics and history.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const WelcomeScreen(isSwitching: true),
                          ),
                        );
                        _loadSettings();
                      },
                      child: const Text('Switch'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 1. APPEARANCE SECTION
                _sectionHeader('Appearance & Theme', Icons.palette_outlined),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.brightness_6_outlined),
                        title: const Text('Theme Mode',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          settings['themeMode'] == 'dark'
                              ? 'Dark theme'
                              : settings['themeMode'] == 'light'
                                  ? 'Light theme'
                                  : 'System theme (follow device settings)',
                        ),
                        trailing: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'system',
                              label: Text('System'),
                              icon: Icon(Icons.brightness_auto, size: 16),
                            ),
                            ButtonSegment(
                              value: 'light',
                              label: Text('Light'),
                              icon: Icon(Icons.light_mode, size: 16),
                            ),
                            ButtonSegment(
                              value: 'dark',
                              label: Text('Dark'),
                              icon: Icon(Icons.dark_mode, size: 16),
                            ),
                          ],
                          selected: {
                            (settings['themeMode']?.toString().toLowerCase() ??
                                'system')
                          },
                          onSelectionChanged: (newSelection) {
                            if (newSelection.isNotEmpty) {
                              _updateSetting('themeMode', newSelection.first);
                            }
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.format_size),
                        title: const Text('Question Font Size',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${(settings['fontSize'] as num?)?.toInt() ?? 16} pt'),
                        trailing: SizedBox(
                          width: 180,
                          child: Slider(
                            value:
                                ((settings['fontSize'] as num?)?.toDouble() ??
                                        16.0)
                                    .clamp(12.0, 24.0),
                            min: 12.0,
                            max: 24.0,
                            divisions: 6,
                            label:
                                '${((settings['fontSize'] as num?)?.toInt() ?? 16)} pt',
                            onChanged: (v) => _updateSetting('fontSize', v),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 2. EXAM DEFAULTS & DAILY GOAL SECTION
                _sectionHeader(
                    'Exam & Study Habit Targets', Icons.tune_outlined),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                            Icons.local_fire_department_outlined,
                            color: Color(0xFFEA580C)),
                        title: const Text('Daily Study Question Goal',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Target number of questions to answer each day for streak tracking'),
                        trailing: DropdownButton<int>(
                          value: (settings['dailyGoal'] as num?)?.toInt() ?? 20,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(
                                value: 5, child: Text('5 Questions')),
                            DropdownMenuItem(
                                value: 10, child: Text('10 Questions')),
                            DropdownMenuItem(
                                value: 15, child: Text('15 Questions')),
                            DropdownMenuItem(
                                value: 20, child: Text('20 Questions')),
                            DropdownMenuItem(
                                value: 30, child: Text('30 Questions')),
                            DropdownMenuItem(
                                value: 50, child: Text('50 Questions')),
                          ],
                          onChanged: (v) {
                            if (v != null) _updateSetting('dailyGoal', v);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: const Text('Default Exam Duration',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Standard time assigned when creating new exam sessions'),
                        trailing: DropdownButton<int>(
                          value:
                              (settings['defaultDuration'] as num?)?.toInt() ??
                                  30,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Untimed')),
                            DropdownMenuItem(
                                value: 15, child: Text('15 Minutes')),
                            DropdownMenuItem(
                                value: 30, child: Text('30 Minutes')),
                            DropdownMenuItem(
                                value: 45, child: Text('45 Minutes')),
                            DropdownMenuItem(
                                value: 60, child: Text('60 Minutes')),
                          ],
                          onChanged: (v) {
                            if (v != null) _updateSetting('defaultDuration', v);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.grading_outlined),
                        title: const Text('Default Passing Score',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${(settings['defaultPassingScore'] as num?)?.toInt() ?? 75}% threshold required to pass'),
                        trailing: DropdownButton<int>(
                          value: (settings['defaultPassingScore'] as num?)
                                  ?.toInt() ??
                              75,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 60, child: Text('60%')),
                            DropdownMenuItem(value: 70, child: Text('70%')),
                            DropdownMenuItem(value: 75, child: Text('75%')),
                            DropdownMenuItem(value: 80, child: Text('80%')),
                            DropdownMenuItem(value: 85, child: Text('85%')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              _updateSetting('defaultPassingScore', v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 3. DESKTOP KEYBOARD SHORTCUTS SECTION
                _sectionHeader(
                    'Desktop Keyboard Shortcuts', Icons.keyboard_outlined),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildShortcutRow('1, 2, 3, 4  or  A, B, C, D',
                            'Select Option (A, B, C, D)'),
                        const Divider(height: 14),
                        _buildShortcutRow('Left Arrow / Right Arrow',
                            'Navigate to Previous / Next Question'),
                        const Divider(height: 14),
                        _buildShortcutRow('Spacebar',
                            'Toggle Explanation (Practice) / Flag for Review (Exam)'),
                        const Divider(height: 14),
                        _buildShortcutRow(
                            'M Key', 'Star / Bookmark Question for Revision'),
                        const Divider(height: 14),
                        _buildShortcutRow('Enter',
                            'Advance to Next Question / Finish Session'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 4. FEEDBACK SECTION
                _sectionHeader(
                    'Feedback & Interaction', Icons.touch_app_outlined),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.vibration),
                        title: const Text('Haptic Feedback',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Vibrate on answer tap and navigation clicks'),
                        value: settings['hapticFeedback'] ?? true,
                        onChanged: (v) => _updateSetting('hapticFeedback', v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.volume_up_outlined),
                        title: const Text('Sound Effects',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Play subtle audio cues for correct/incorrect answers'),
                        value: settings['soundEffects'] ?? false,
                        onChanged: (v) => _updateSetting('soundEffects', v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5. DATA & BACKUP SECTION
                _sectionHeader('Data & Storage', Icons.folder_zip_outlined),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.file_download_outlined,
                            color: AppTheme.accentBlue),
                        title: const Text('Export Full Backup Package',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Export all students, exams, question banks, bookmarks & history'),
                        trailing: OutlinedButton(
                          onPressed: _exportAllData,
                          child: const Text('Export JSON'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.restore_page_outlined,
                            color: AppTheme.accentBlue),
                        title: const Text('Restore Full Backup Package',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Restore student profiles, questions, and attempt history'),
                        trailing: OutlinedButton(
                          onPressed: _restoreBackup,
                          child: const Text('Restore JSON'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.table_chart_outlined,
                            color: AppTheme.success),
                        title: const Text('Download Sample CSV Template',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Export a formatted CSV sample to prepare your questions'),
                        trailing: OutlinedButton(
                          onPressed: _saveSampleCsv,
                          child: const Text('Get CSV Template'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_forever,
                            color: AppTheme.danger),
                        title: const Text('Reset All Data',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.danger)),
                        subtitle: const Text(
                            'Erase all exams and performance records permanently'),
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.danger),
                          onPressed: _confirmResetData,
                          child: const Text('Reset Data'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 5. ABOUT SECTION
                _sectionHeader('About', Icons.info_outline),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'QuizPro Exam Simulator',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(width: 8),
                            Chip(
                              label: Text('v2.0.0',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Data is stored locally on your device by the application and is not uploaded to any remote servers.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutRow(String keys, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            keys,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: AppTheme.text,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(fontSize: 13, color: AppTheme.text),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.accentBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
