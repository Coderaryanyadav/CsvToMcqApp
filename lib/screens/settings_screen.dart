import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../main.dart';
import '../models/student_profile.dart';
import '../services/storage_service.dart';
import '../services/import_service.dart';
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
    await StorageService.saveSettings(settings);
  }

  Future<void> _exportAllData() async {
    try {
      final exams = await StorageService.loadAllExams();
      final perfs = StorageService.loadAllPerformances();
      final bundle = {
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'exams': exams.map((e) => e.toJson()).toList(),
        'performances': perfs.map((p) => p.toJson()).toList(),
      };
      final jsonText = const JsonEncoder.withIndent('  ').convert(bundle);
      final outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup JSON',
        fileName:
            'quizpro_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonText);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup exported successfully!'),
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
          'This will permanently delete all created exams, question banks, and practice attempt history. This action cannot be undone.',
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
                _sectionHeader('Student Profile & Multi-User', Icons.person_outline),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                            builder: (_) => const WelcomeScreen(isSwitching: true),
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
                _sectionHeader('Appearance', Icons.palette_outlined),
                Card(
                  child: Column(
                    children: [
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

                // 2. EXAM DEFAULTS SECTION
                _sectionHeader('Exam & Practice Defaults', Icons.tune_outlined),
                Card(
                  child: Column(
                    children: [
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

                // 3. FEEDBACK SECTION
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

                // 4. DATA & BACKUP SECTION
                _sectionHeader('Data & Storage', Icons.folder_zip_outlined),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.file_download_outlined,
                            color: AppTheme.accentBlue),
                        title: const Text('Export Complete Data Backup',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Save all exams, question banks, and history to a JSON file'),
                        trailing: OutlinedButton(
                          onPressed: _exportAllData,
                          child: const Text('Export JSON'),
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
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
                        const SizedBox(height: 8),
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
