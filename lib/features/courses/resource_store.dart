import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'courses_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Picked file
// ─────────────────────────────────────────────────────────────────────────────

/// A PDF the user chose with the file picker, before it is saved by the app.
class PickedPdf {
  const PickedPdf({
    required this.path,
    required this.name,
    required this.sizeBytes,
  });

  /// Temporary path the picker gave us (usually inside the app's cache).
  final String path;

  /// Original file name, e.g. "week3_notes.pdf".
  final String name;

  /// File size in bytes, used for the size limit and the details sheet.
  final int sizeBytes;
}

/// Largest PDF we accept (25 MB). Keeps the phone's storage from filling up.
const int kMaxUploadBytes = 25 * 1024 * 1024;

/// Signature for "let the user choose a PDF". The screens take one of these so
/// widget tests can pass a fake picker instead of opening the real one.
typedef PdfPicker = Future<PickedPdf?> Function();

/// The real picker: opens Android's file chooser filtered to PDF files.
/// Returns null if the user backs out without choosing anything.
Future<PickedPdf?> pickPdfFromDevice() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['pdf'],
  );
  // User cancelled the picker.
  if (result == null || result.files.isEmpty) return null;

  final file = result.files.single;
  // path can be null on web; this app only targets Android, so treat it as a cancel.
  if (file.path == null) return null;

  return PickedPdf(path: file.path!, name: file.name, sizeBytes: file.size);
}

/// Opens a saved resource's PDF in whatever PDF viewer the phone has.
/// Returns an error message to show the user, or null on success.
Future<String?> openResourceFile(Resource resource) async {
  final path = resource.filePath;
  // Sample resources were seeded without a real file.
  if (path == null) return 'This sample resource has no file attached.';
  if (!await File(path).exists()) return 'The file could not be found.';

  final result = await OpenFilex.open(path);
  // ResultType.done means a viewer opened; anything else is a problem.
  return result.type == ResultType.done
      ? null
      : 'No app found to open PDF files.';
}

/// Turns a byte count into something readable, e.g. 1536000 -> "1.5 MB".
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// ─────────────────────────────────────────────────────────────────────────────
// Store interface
// ─────────────────────────────────────────────────────────────────────────────

/// Everything the screens need to read and change a course's resources.
/// Screens only talk to this class, so swapping SQLite for Firebase later
/// only means writing another implementation.
abstract class ResourceStore {
  /// The store the app uses by default: SQLite on a real Android device,
  /// an in-memory list everywhere else (widget tests, desktop, web).
  static final ResourceStore instance = Platform.isAndroid
      ? SqliteResourceStore()
      : MemoryResourceStore();

  /// All resources for one course, newest first.
  Future<List<Resource>> loadFor(String courseCode, String currentUserEmail);

  /// Saves the PDF into app storage and records the resource.
  /// [draft] holds the form fields; the returned copy has its id and file path.
  Future<Resource> add(Resource draft, PickedPdf file);

  /// Removes the record only. The file is kept so "Undo" can bring it back.
  Future<void> remove(Resource resource);

  /// Puts a removed record back (used by the "Undo" snackbar action).
  Future<void> restore(Resource resource);

  /// Deletes the PDF from storage once the delete can no longer be undone.
  Future<void> deleteFile(Resource resource) async {
    final path = resource.filePath;
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// In-memory store (tests and non-Android platforms)
// ─────────────────────────────────────────────────────────────────────────────

/// Keeps resources in a map. Nothing survives an app restart, and the picked
/// file is not copied anywhere; it just remembers the picker's path.
class MemoryResourceStore extends ResourceStore {
  final Map<String, List<Resource>> _byCourse = {};
  int _nextId = 1;

  @override
  Future<List<Resource>> loadFor(String courseCode, String currentUserEmail) async {
    // First visit to a course: fill it with the same sample data as before.
    final list = _byCourse.putIfAbsent(
      courseCode,
      () => _samples(courseCode, currentUserEmail),
    );
    // Copy so the screen can't change our list by accident.
    return [...list]..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  @override
  Future<Resource> add(Resource draft, PickedPdf file) async {
    final saved = draft.copyWith(
      id: _nextId++,
      filePath: file.path,
      fileName: file.name,
      fileSizeBytes: file.sizeBytes,
    );
    _byCourse.putIfAbsent(draft.courseCode, () => []).add(saved);
    return saved;
  }

  @override
  Future<void> remove(Resource resource) async {
    _byCourse[resource.courseCode]?.removeWhere((r) => r.id == resource.id);
  }

  @override
  Future<void> restore(Resource resource) async {
    _byCourse.putIfAbsent(resource.courseCode, () => []).add(resource);
  }

  // Memory store never copied the file, so there is nothing of ours to delete.
  @override
  Future<void> deleteFile(Resource resource) async {}

  List<Resource> _samples(String courseCode, String currentUserEmail) => [
        Resource(
          id: _nextId++,
          courseCode: courseCode,
          title: 'Dart study notes',
          type: ResourceType.notes,
          semester: 'Fall 2026',
          materialDate: DateTime(2026, 9, 15),
          pageCount: 4,
          uploaderEmail: 'sample.student@ontariotechu.net',
          currentUserId: currentUserEmail,
          description: 'Variables, null safety, lists and loops.',
        ),
        Resource(
          id: _nextId++,
          courseCode: courseCode,
          title: 'Practice questions – widgets',
          type: ResourceType.practice,
          semester: 'Fall 2026',
          materialDate: DateTime(2026, 10, 1),
          pageCount: 6,
          // Uploaded by the current user so the "Yours" chip shows in the demo.
          uploaderEmail: currentUserEmail,
          currentUserId: currentUserEmail,
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// SQLite store (real Android device)
// ─────────────────────────────────────────────────────────────────────────────

/// Saves resource details in a local SQLite database and copies each PDF into
/// the app's private documents folder, so uploads survive app restarts.
class SqliteResourceStore extends ResourceStore {
  static const _table = 'resources';

  // Opened once, the first time any method needs it.
  Future<Database>? _db;
  Future<Database> get _database => _db ??= _open();

  Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), 'otudoc.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // One row per uploaded resource. Dates are stored as milliseconds.
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_code TEXT NOT NULL,
            title TEXT NOT NULL,
            type TEXT NOT NULL,
            semester TEXT NOT NULL,
            material_date INTEGER NOT NULL,
            page_count INTEGER,
            description TEXT NOT NULL DEFAULT '',
            uploader_email TEXT NOT NULL,
            uploaded_at INTEGER NOT NULL,
            file_path TEXT,
            file_name TEXT,
            file_size INTEGER
          )
        ''');
        // A sample row so the Mobile Devices hub isn't empty on first launch.
        await db.insert(_table, {
          'course_code': 'CSCI 3101U',
          'title': 'Dart study notes',
          'type': ResourceType.notes.name,
          'semester': 'Fall 2026',
          'material_date': DateTime(2026, 9, 15).millisecondsSinceEpoch,
          'page_count': 4,
          'description': 'Variables, null safety, lists and loops.',
          'uploader_email': 'sample.student@ontariotechu.net',
          'uploaded_at': DateTime(2026, 9, 15).millisecondsSinceEpoch,
        });
      },
    );
  }

  @override
  Future<List<Resource>> loadFor(String courseCode, String currentUserEmail) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where: 'course_code = ?',
      whereArgs: [courseCode],
      orderBy: 'uploaded_at DESC',
    );
    return [for (final row in rows) _fromRow(row, currentUserEmail)];
  }

  @override
  Future<Resource> add(Resource draft, PickedPdf file) async {
    // 1. Copy the PDF out of the picker's temporary cache into our own folder,
    //    because Android can clear the cache at any time.
    final docs = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(docs.path, 'resources'));
    await folder.create(recursive: true);
    // Timestamp prefix so two uploads called "notes.pdf" don't overwrite each other.
    final storedPath = p.join(
      folder.path,
      '${DateTime.now().millisecondsSinceEpoch}_${file.name}',
    );
    await File(file.path).copy(storedPath);

    // 2. Record the resource, pointing at the copied file.
    final withFile = draft.copyWith(
      filePath: storedPath,
      fileName: file.name,
      fileSizeBytes: file.sizeBytes,
    );
    try {
      final db = await _database;
      final id = await db.insert(_table, _toRow(withFile));
      return withFile.copyWith(id: id);
    } catch (_) {
      // Don't leave an orphaned PDF behind if the database write failed.
      await File(storedPath).delete();
      rethrow;
    }
  }

  @override
  Future<void> remove(Resource resource) async {
    final db = await _database;
    await db.delete(_table, where: 'id = ?', whereArgs: [resource.id]);
  }

  @override
  Future<void> restore(Resource resource) async {
    final db = await _database;
    // Re-insert with the same id so the row is exactly as it was.
    await db.insert(
      _table,
      {'id': resource.id, ..._toRow(resource)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Resource -> database row (id is left out so SQLite assigns one).
  Map<String, Object?> _toRow(Resource r) => {
        'course_code': r.courseCode,
        'title': r.title,
        'type': r.type.name,
        'semester': r.semester,
        'material_date': r.materialDate.millisecondsSinceEpoch,
        'page_count': r.pageCount,
        'description': r.description,
        'uploader_email': r.uploaderEmail,
        'uploaded_at': r.uploadedAt.millisecondsSinceEpoch,
        'file_path': r.filePath,
        'file_name': r.fileName,
        'file_size': r.fileSizeBytes,
      };

  // Database row -> Resource. currentUserEmail decides the "Yours" chip.
  Resource _fromRow(Map<String, Object?> row, String currentUserEmail) =>
      Resource(
        id: row['id'] as int,
        courseCode: row['course_code'] as String,
        title: row['title'] as String,
        type: ResourceType.values.byName(row['type'] as String),
        semester: row['semester'] as String,
        materialDate:
            DateTime.fromMillisecondsSinceEpoch(row['material_date'] as int),
        pageCount: row['page_count'] as int?,
        description: row['description'] as String,
        uploaderEmail: row['uploader_email'] as String,
        currentUserId: currentUserEmail,
        uploadedAt:
            DateTime.fromMillisecondsSinceEpoch(row['uploaded_at'] as int),
        filePath: row['file_path'] as String?,
        fileName: row['file_name'] as String?,
        fileSizeBytes: row['file_size'] as int?,
      );
}