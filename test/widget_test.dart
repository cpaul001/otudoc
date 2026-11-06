import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otudoc/app/app.dart';
import 'package:otudoc/features/auth/auth_widgets.dart';
import 'package:otudoc/features/auth/login_screen.dart';
import 'package:otudoc/features/auth/signup_screen.dart';

Future<void> startApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const OtuDocApp());
}

Future<void> submit(WidgetTester tester) async {
  final button = find.byType(ElevatedButton);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'School email accepts the exact domain only, ignoring case and padding',
    () {
      expect(validateEmail(' student@ONTARIOTECHU.NET '), isNull);
      for (final email in [
        'student@gmail.com',
        'student@ontariotechu.net.example.com',
        'student@fakeontariotechu.net',
        'student@sub.ontariotechu.net',
      ]) {
        expect(
          validateEmail(email),
          'Use your @ontariotechu.net school email.',
        );
      }
    },
  );
  testWidgets('Signup validates required fields and malformed input', (
    tester,
  ) async {
    await startApp(tester);
    await submit(tester);
    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '  ');
    await tester.enterText(fields.at(1), 'invalid-email');
    await tester.enterText(fields.at(2), 'short');
    await submit(tester);
    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Valid signup shows a preview without creating an account', (
    tester,
  ) async {
    await startApp(tester);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Demo Student');
    await tester.enterText(fields.at(1), 'student@example.com');
    await tester.enterText(fields.at(2), 'example123');
    await submit(tester);
    expect(
      find.text('Use your @ontariotechu.net school email.'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    await tester.enterText(fields.at(1), 'student@ontariotechu.net');
    await submit(tester);
    expect(find.text('Preview only — no account was created.'), findsOneWidget);
    expect(find.byType(SignupScreen), findsOneWidget);
  });

  testWidgets('Password visibility toggles without changing the value', (
    tester,
  ) async {
    await startApp(tester);
    await tester.enterText(find.byType(TextFormField).last, 'example123');
    expect(
      tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    final visible = tester.widget<EditableText>(find.byType(EditableText).last);
    expect(visible.obscureText, isFalse);
    expect(visible.controller.text, 'example123');
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
      isTrue,
    );
  });

  testWidgets('Login validates and returns to the existing signup screen', (
    tester,
  ) async {
    await startApp(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Demo Student');
    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    await submit(tester);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'example123');
    await submit(tester);
    expect(
      find.text('Use your @ontariotechu.net school email.'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    await tester.enterText(
      find.byType(TextFormField).first,
      'student@ontariotechu.net',
    );
    await submit(tester);
    expect(
      find.text('Preview only — you have not been signed in.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Sign up'));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.byType(SignupScreen), findsOneWidget);
    expect(find.text('Demo Student'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('Small screen with large text and keyboard remains scrollable', (
    tester,
  ) async {
    await startApp(tester);
    tester.view.physicalSize = const Size(320, 600);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await submit(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Enter your full name.'), findsOneWidget);
    await tester.ensureVisible(find.text('Log in'));
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    await submit(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Enter your password.'), findsOneWidget);
  });
}
