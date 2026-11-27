import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otudoc/app/theme.dart';
import 'package:otudoc/features/courses/courses_screen.dart';
import 'package:otudoc/features/courses/resource_store.dart';

// Fake file picker: pretends the user chose a small PDF, so tests never
// open the real Android file chooser (it doesn't exist in widget tests).
Future<PickedPdf?> fakePickPdf() async => const PickedPdf(
      path: '/fake/video_demo_notes.pdf',
      name: 'video_demo_notes.pdf',
      sizeBytes: 2048,
    );

Future<void> openHub(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: ResourcesScreen(
        courseCode: 'CSCI 3101U',
        courseName: 'Mobile Devices',
        userEmail: 'demo@ontariotechu.net',
        // In-memory store + fake picker keep tests off the real plugins.
        store: MemoryResourceStore(),
        pickPdf: fakePickPdf,
      ),
    ),
  );
  // Let the store finish loading the sample resources.
  await tester.pumpAndSettle();
}

Future<void> openUpload(WidgetTester tester) async {
  await tester.tap(find.text('Upload resource'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Clean upload exits; edited upload can keep or discard changes', (
    tester,
  ) async {
    await openHub(tester);
    await openUpload(tester);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(UploadResourceScreen), findsNothing);
    await openUpload(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Draft notes');
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard upload?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Draft notes'), findsOneWidget);
    // Android system Back must offer the same exit flow as the toolbar.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(UploadResourceScreen), findsNothing);
    expect(find.text('Draft notes'), findsNothing);
  });

  testWidgets('Dropdown-only edits also trigger discard confirmation', (
    tester,
  ) async {
    await openHub(tester);
    await openUpload(tester);
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practice').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard upload?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
  });

  testWidgets('Invalid pages do not crash; valid upload returns to the hub', (
    tester,
  ) async {
    await openHub(tester);
    await openUpload(tester);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Video demo notes',
    );
    // Uploading now requires a PDF; the fake picker supplies one.
    await tester.tap(find.text('Choose PDF'));
    await tester.pumpAndSettle();
    expect(find.textContaining('video_demo_notes.pdf'), findsOneWidget);
    await tester.tap(find.text('Tap to choose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    final pages = find.widgetWithText(
      TextFormField,
      'Number of pages (optional)',
    );
    for (final value in ['abc', '0', '-2', '1.5']) {
      await tester.enterText(pages, value);
      await tester.ensureVisible(find.text('Upload'));
      await tester.tap(find.text('Upload'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter a whole number greater than zero'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.enterText(pages, '4');
    await tester.ensureVisible(find.text('Upload'));
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.byType(UploadResourceScreen), findsNothing);
    expect(find.text('Video demo notes'), findsOneWidget);
    expect(find.text('Discard upload?'), findsNothing);
  });

  testWidgets('Upload without a PDF shows an error and stays on the form', (
    tester,
  ) async {
    await openHub(tester);
    await openUpload(tester);
    await tester.enterText(find.byType(TextFormField).first, 'No file notes');
    await tester.tap(find.text('Tap to choose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Upload'));
    await tester.tap(find.text('Upload'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a PDF to upload'), findsOneWidget);
    expect(find.byType(UploadResourceScreen), findsOneWidget);
  });

  testWidgets('Resource search stays visible across tabs and can be cleared', (
    tester,
  ) async {
    await openHub(tester);
    await tester.enterText(find.byType(TextField), 'no match');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discussion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resources'));
    await tester.pumpAndSettle();
    expect(find.text('no match'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Dart study notes'), findsOneWidget);
    expect(find.text('Practice questions – widgets'), findsOneWidget);
  });
}
