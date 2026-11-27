import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/auth/auth_service.dart';
import '../features/auth/signup_screen.dart';
import '../features/courses/courses_screen.dart';
import 'theme.dart';
import '../features/settings/settings_screen.dart';

class OtuDocApp extends StatelessWidget {
  const OtuDocApp({
    super.key,
    required this.preferences,
    this.home = const _AuthGate(),
  });
  final Widget home;
  final ReadingPreferences preferences;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: preferences,
      child: home,
      builder: (context, homePage) => MaterialApp(
        title: 'OTUDOC',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: preferences.dark ? ThemeMode.dark : ThemeMode.light,
        builder: (context, child) => ReadingScope(
          preferences: preferences,
          child: Builder(
            builder: (context) => MediaQuery.withClampedTextScaling(
              minScaleFactor: ReadingScope.of(context).value.minimumScale,
              child: child!,
            ),
          ),
        ),
        home: homePage,
      ),
    );
  }
}

/// Shows the home screen when signed in and the signup screen otherwise.
///
/// Firebase delivers its first event only after a saved login has been
/// restored, so we show a spinner until then instead of flashing the signup
/// screen at someone who is already signed in.
///

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // route signed-in users straight to the Courses Hub & Resources
        return snapshot.hasData
            ? CoursesScreen(userEmail: snapshot.data?.email ?? '')
            : const SignupScreen();
      },
    );
  }
}
