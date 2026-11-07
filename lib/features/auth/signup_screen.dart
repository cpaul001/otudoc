import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final AuthService _auth = AuthService();
  bool _submitted = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);
    try {
      await _auth.createAccount(
        email: _email.text.trim(),
        password: _password.text,
      );
      await _auth.updateUsername(username: _name.text.trim());
      // On success the auth gate in app.dart swaps this screen for the home screen.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showAuthMessage(context, authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openLogin() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // Push adds the login page above this one; returning preserves the form.
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: 'Create your\naccount.',
      subtitle: 'Your courses, notes and classmates.\nAll in one place.',
      child: AutofillGroup(
        onDisposeAction: AutofillContextAction.cancel,
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                label: 'Full name',
                child: TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(hintText: 'Your name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your full name.'
                      : null,
                ),
              ),
              const SizedBox(height: 18),
              AuthField(
                label: 'School email',
                child: TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(
                    hintText: 'you@ontariotechu.net',
                  ),
                  validator: validateEmail,
                ),
              ),
              const SizedBox(height: 18),
              PasswordField(
                controller: _password,
                isSignup: true,
                onSubmitted: _submit,
              ),
              const SizedBox(height: 24),
              AuthSubmitButton(
                label: 'Create account',
                onPressed: _submit,
                isLoading: _loading,
              ),
              const SizedBox(height: 12),
              AuthSwitch(
                prompt: 'Already have an account?',
                label: 'Log in',
                onPressed: _openLogin,
              ),
            ],
          ),
        ),
      ),
    );
  }
}