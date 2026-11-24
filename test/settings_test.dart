import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:otudoc/features/settings/settings_screen.dart';

void main() {
  testWidgets('Drawer opens Settings and the chosen size can be restored', (
    tester,
  ) async {
    final previous = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
    final prefs = ReadingPreferences();
    await tester.pumpWidget(
      ReadingScope(
        preferences: prefs,
        child: const MaterialApp(
          home: Scaffold(
            drawer: CourseDrawer(),
            appBar: null,
            body: SizedBox(),
          ),
        ),
      ),
    );
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extra large'));
    await tester.pumpAndSettle();
    expect(prefs.value, ReadingSize.larger);
    final restored = ReadingPreferences();
    await restored.restore();
    expect(restored.value, ReadingSize.larger);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
  });
}
