import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:otudoc/features/settings/settings_screen.dart';

import 'package:otudoc/app/app.dart';
import 'package:otudoc/features/courses/courses_screen.dart';
import 'package:otudoc/features/auth/signup_screen.dart';

void main() {
  testWidgets('Drawer opens Settings and the chosen size can be restored', (
    tester,
  ) async {
    final previous = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
    final prefs = ReadingPreferences();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      OtuDocApp(
        preferences: prefs,
        home: const CoursesScreen(userEmail: 'test@ontariotechu.net'),
      ),
    );
    Future<void> tap(String label) async {
      final target = find.text(label).first;
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    void check(String label) {
      final context = tester.element(find.text(label).first);
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(MediaQuery.textScalerOf(context).scale(20), 26);
      expect(tester.takeException(), isNull);
    }

    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extra large'));
    await tester.pumpAndSettle();
    expect(prefs.value, ReadingSize.larger);
    await tap('Dark mode');
    check('Settings');
    final restored = ReadingPreferences();
    await restored.restore();
    expect(restored.value, ReadingSize.larger);
    expect(restored.dark, isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    check('Courses');
    await tap('Open course');
    check('Course hub');
    await tap('Discussion');
    check('Shared course chat');
    await tap('Resources');
    await tap('Upload resource');
    check('Material date');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      OtuDocApp(preferences: restored, home: const SignupScreen()),
    );
    check('Full name');
    await tap('Log in');
    check('School email');
  });
}
