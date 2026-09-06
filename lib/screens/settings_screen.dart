import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../main.dart'; // To access darkModeNotifier

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic> settings = {
    'darkMode': false,
    'fontSize': 16.0,
    'hapticFeedback': true,
    'soundEffects': false,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final loaded = await StorageService.loadSettings();
    setState(() {
      settings = loaded;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await StorageService.saveSettings(settings);
  }

  void _updateSetting(String key, dynamic value) {
    setState(() {
      settings[key] = value;
    });
    _saveSettings();
    if (key == 'darkMode') {
      darkModeNotifier.value = value as bool;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Appearance',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                    ),
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Dark Mode'),
                            subtitle: const Text('Switch between light and dark themes'),
                            value: settings['darkMode'] ?? false,
                            onChanged: (val) => _updateSetting('darkMode', val),
                            secondary: const Icon(Icons.dark_mode),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Preferences',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                      ),
                    ),
                    Card(
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Haptic Feedback'),
                            subtitle: const Text('Vibrate on correct/incorrect answers'),
                            value: settings['hapticFeedback'] ?? true,
                            onChanged: (val) => _updateSetting('hapticFeedback', val),
                            secondary: const Icon(Icons.vibration),
                          ),
                          const Divider(),
                          SwitchListTile(
                            title: const Text('Sound Effects'),
                            subtitle: const Text('Play sound on correct/incorrect answers'),
                            value: settings['soundEffects'] ?? false,
                            onChanged: (val) => _updateSetting('soundEffects', val),
                            secondary: const Icon(Icons.volume_up),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
