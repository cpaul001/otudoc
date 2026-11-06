import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared layout keeps signup and login consistent without duplicating screens.
/// extracts reusable widgets. The sizing below also handles a visible keyboard.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 28),
                            const _Brand(),
                            const SizedBox(height: 40),
                            Text(title, style: theme.textTheme.headlineLarge),
                            const SizedBox(height: 12),
                            Text(subtitle, style: theme.textTheme.bodyMedium),
                            const SizedBox(height: 28),
                            child,
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 32, bottom: 24),
                          child: Text(
                            'A little less searching. A lot more learning.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.menu_book_rounded,
            color: colors.onPrimary,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'OTUDOC',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({super.key, required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        Semantics(label: label, child: child),
      ],
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.isSignup,
    required this.onSubmitted,
  });
  final TextEditingController controller;
  final bool isSignup;
  final VoidCallback onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  // setState rebuilds this field when the eye button changes obscureText.
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return AuthField(
      label: 'Password',
      child: TextFormField(
        controller: widget.controller,
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: TextInputAction.done,
        autofillHints: [
          widget.isSignup ? AutofillHints.newPassword : AutofillHints.password,
        ],
        onFieldSubmitted: (_) => widget.onSubmitted(),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Enter your password.';
          if (widget.isSignup && value.length < 8) {
            return 'Use at least 8 characters.';
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: widget.isSignup
              ? 'Create a password'
              : 'Enter your password',
          helperText: widget.isSignup ? 'Use at least 8 characters.' : null,
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(child: Text(label)),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward_rounded, size: 18),
        ],
      ),
    );
  }
}

class AuthSwitch extends StatelessWidget {
  const AuthSwitch({
    super.key,
    required this.prompt,
    required this.label,
    required this.onPressed,
  });
  final String prompt;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt, style: Theme.of(context).textTheme.bodyMedium),
        TextButton(onPressed: onPressed, child: Text(label)),
      ],
    );
  }
}

String? validateEmail(String? value) {
  // This format check is stricter than the workshop's contains('@') example.
  final email = value?.trim() ?? '';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  if (email.split('@').last.toLowerCase() != 'ontariotechu.net') {
    return 'Use your @ontariotechu.net school email.';
  }
  return null;
}

// Replace this preview response with the authentication controller when Firebase is integrated.
void showAuthPreview(BuildContext context, {required bool isSignup}) {
  FocusScope.of(context).unfocus();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          isSignup
              ? 'Preview only — no account was created.'
              : 'Preview only — you have not been signed in.',
        ),
      ),
    );
}
