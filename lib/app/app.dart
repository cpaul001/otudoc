import 'package:flutter/material.dart';

import '../features/auth/signup_screen.dart';
import 'theme.dart';

class OtuDocApp extends StatelessWidget {
  const OtuDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTUDOC',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SignupScreen(),
    );
  }
}
