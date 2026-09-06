import 'package:flutter/material.dart';
import '../models/student_profile.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final bool isSwitching;

  const WelcomeScreen({super.key, this.isSwitching = false});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _nameCtrl = TextEditingController();
  List<StudentProfile> _students = [];
  StudentProfile? _activeStudent;
  bool _loading = true;
  bool _isCreatingNew = false;

  String _selectedEmoji = '🎓';
  int _selectedColor = 0xFF2563EB;

  final List<String> _emojis = ['🎓', '🚀', '🧠', '💡', '🌟', '📚', '🎯', '🏆'];
  final List<int> _colors = [
    0xFF2563EB, // Blue
    0xFF7C3AED, // Purple
    0xFF059669, // Emerald
    0xFFDC2626, // Red
    0xFFD97706, // Amber
    0xFFDB2777, // Pink
    0xFF0D9488, // Teal
    0xFF4F46E5, // Indigo
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final list = await StorageService.getAllStudents();
    final active = await StorageService.getActiveStudent();
    if (mounted) {
      setState(() {
        _students = list;
        _activeStudent = active;
        _loading = false;
        _isCreatingNew = list.isEmpty;
      });
    }
  }

  Future<void> _selectStudent(StudentProfile student) async {
    await StorageService.setActiveStudent(student);
    if (!mounted) return;
    if (widget.isSwitching) {
      Navigator.pop(context, student);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _createNewStudent() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    final newStudent = StudentProfile(
      name: name,
      avatarEmoji: _selectedEmoji,
      avatarColorValue: _selectedColor,
    );

    await StorageService.saveStudent(newStudent);
    await StorageService.setActiveStudent(newStudent);

    if (!mounted) return;
    if (widget.isSwitching) {
      Navigator.pop(context, newStudent);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: widget.isSwitching
          ? AppBar(
              title: const Text('Switch Student Profile'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo & Header
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(_selectedColor),
                            Color(_selectedColor).withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(_selectedColor).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _selectedEmoji,
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.isSwitching ? 'Student Profiles' : 'Welcome to QuizPro',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isCreatingNew
                        ? 'Create a student profile to track your progress and exams.'
                        : 'Select who is practicing today or add a new student profile.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.secondaryText,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (!_isCreatingNew && _students.isNotEmpty) ...[
                    // List of existing students
                    Text(
                      'Select Student Profile (${_students.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._students.map((student) {
                      final isActive = _activeStudent?.id == student.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: InkWell(
                          onTap: () => _selectStudent(student),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Color(student.avatarColorValue).withValues(alpha: 0.08)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive
                                    ? Color(student.avatarColorValue)
                                    : Colors.grey.shade300,
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: Color(student.avatarColorValue).withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      student.avatarEmoji,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isActive
                                              ? Color(student.avatarColorValue)
                                              : AppTheme.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isActive ? 'Active Profile' : 'Student',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isActive
                                              ? Color(student.avatarColorValue)
                                              : AppTheme.secondaryText,
                                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isActive)
                                  Icon(
                                    Icons.check_circle,
                                    color: Color(student.avatarColorValue),
                                    size: 24,
                                  )
                                else
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isCreatingNew = true;
                          _nameCtrl.clear();
                        });
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add Another Student Profile'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Create New Profile Form
                    TextField(
                      controller: _nameCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Student Name *',
                        hintText: 'e.g. Alex, Aryan, Jordan',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Choose Emoji Avatar
                    const Text(
                      'Choose Avatar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _emojis.map((emoji) {
                          final isSel = _selectedEmoji == emoji;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () => setState(() => _selectedEmoji = emoji),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? Color(_selectedColor).withValues(alpha: 0.15)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSel ? Color(_selectedColor) : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Center(
                                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Choose Profile Color
                    const Text(
                      'Choose Theme Color',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _colors.map((c) {
                          final isSel = _selectedColor == c;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: InkWell(
                              onTap: () => setState(() => _selectedColor = c),
                              customBorder: const CircleBorder(),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Color(c),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel ? Colors.black : Colors.transparent,
                                    width: isSel ? 3 : 0,
                                  ),
                                ),
                                child: isSel
                                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 28),

                    FilledButton.icon(
                      onPressed: _createNewStudent,
                      icon: const Icon(Icons.check),
                      label: Text(
                        _students.isEmpty ? 'Get Started' : 'Save & Select Student',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Color(_selectedColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    if (_students.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isCreatingNew = false;
                          });
                        },
                        child: const Text('Back to Student Profiles'),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
