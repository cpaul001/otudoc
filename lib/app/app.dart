import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/auth/auth_service.dart';
import '../features/auth/signup_screen.dart';
import '../features/home/home_screen.dart';
import 'theme.dart';

class OtuDocApp extends StatelessWidget {
  const OtuDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTUDOC',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AuthGate(),
    );
  }
}

/// Shows the home screen when signed in and the signup screen otherwise.
///
/// Firebase delivers its first event only after a saved login has been
/// restored, so we show a spinner until then instead of flashing the signup
/// screen at someone who is already signed in.
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
        return snapshot.hasData ? const HomeScreen() : const SignupScreen();
      },
    );
  }
}