import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

/// Placeholder so the login/signup flow can be tested end to end.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTUDOC'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: Center(
        child: Text('Signed in as ${user?.email ?? 'unknown'}'),
      ),
    );
  }
}