import 'package:flutter/material.dart';

import 'auth_widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Validation checks the form's format, not whether an account exists.
    showAuthPreview(context, isSignup: false);
  }

  void _openSignup() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final navigator = Navigator.of(context);
    // Return to signup instead of adding another copy to the route stack.
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const SignupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPage(
      title: 'Welcome\nback.',
      subtitle:
          'Your course community is waiting.\nPick up where you left off.',
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
                isSignup: false,
                onSubmitted: _submit,
              ),
              const SizedBox(height: 24),
              AuthSubmitButton(label: 'Log in', onPressed: _submit),
              const SizedBox(height: 12),
              AuthSwitch(
                prompt: 'New to OTUDOC?',
                label: 'Sign up',
                onPressed: _openSignup,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
