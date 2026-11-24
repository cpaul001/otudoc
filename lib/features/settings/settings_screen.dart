import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReadingSize {
  device('Device default', 0),
  large('Large', 1.15),
  larger('Extra large', 1.30);

  const ReadingSize(this.label, this.minimumScale);
  final String label;
  final double minimumScale;
}

class ReadingPreferences extends ValueNotifier<ReadingSize> {
  ReadingPreferences() : super(ReadingSize.device);
  static const _key = 'reading_size';
  final _store = SharedPreferencesAsync();

  Future<void> restore() async {
    final saved = await _store.getString(_key);
    value = ReadingSize.values.firstWhere(
      (size) => size.name == saved,
      orElse: () => ReadingSize.device,
    );
  }

  Future<void> save(ReadingSize size) async {
    await _store.setString(_key, size.name);
    value = size;
  }
}

class ReadingScope extends InheritedNotifier<ReadingPreferences> {
  const ReadingScope({
    super.key,
    required ReadingPreferences preferences,
    required super.child,
  }) : super(notifier: preferences);

  static ReadingPreferences of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReadingScope>()!.notifier!;
}

class CourseDrawer extends StatelessWidget {
  const CourseDrawer({super.key});

  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(
      child: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'OTUDOC',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Courses'),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            onTap: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _saving = false;
  Future<void> _select(ReadingSize? size) async {
    if (_saving || size == null) return;
    final prefs = ReadingScope.of(context);
    setState(() => _saving = true);
    try {
      await prefs.save(size);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save text size. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Text size', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Choose a minimum text size for all screens.'),
          RadioGroup<ReadingSize>(
            groupValue: ReadingScope.of(context).value,
            onChanged: _select,
            child: Column(
              children: [
                for (final size in ReadingSize.values)
                  RadioListTile<ReadingSize>(
                    value: size,
                    enabled: !_saving,
                    title: Text(size.label),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
