import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase_options.dart';
import 'features/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final preferences = ReadingPreferences();
  try {
    await preferences.restore();
  } catch (_) {
    // The app can still open at the device text size if storage is unavailable.
  }
  runApp(OtuDocApp(preferences: preferences));
}
