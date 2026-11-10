// lib/features/resources/resources_screen.dart
//
// OTUDOC — Course hub › Resources page, with LOCAL STORAGE.
// Opened from CoursesScreen ("Open course"), which passes the course and
// the signed-in user's email (from Firebase Auth).
//
// What is stored on the phone, so it survives closing the app:
//   • SQLite (sqflite) ........... every resource's details (table "resources")
//   • App documents folder ....... a copy of each uploaded PDF
//   • SharedPreferences .......... the last "Type" filter picked per course
//
// Packages needed (run once in the project folder, the one with pubspec.yaml):
//   flutter pub add sqflite path path_provider shared_preferences file_picker
//
// Run it on the Android emulator or a phone — sqflite does not work on
// Chrome/web or Windows desktop without extra setup.
//
// Styling (input borders, buttons, app bar) comes from lib/app/theme.dart.
//
// Course features shown on this page (for the rubric):
//   • Local storage ... SQLite + saved PDF files + SharedPreferences
//   • ListView ........ the resource list
//   • Search/filter ... live search box + "Type" dropdown
//   • Dialogs ......... delete confirmation, "Discard upload?"
//   • Pickers ......... PDF file picker, date picker, type/semester dropdowns
//   • Forms ........... upload form with validation
//   • Snackbars ....... after upload, after delete (with UNDO), on errors
//   • Navigation ...... Resources → Upload screen (returns the new resource)

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
// "path" is imported with a prefix because it has its own top-level
// `context`, which would clash with Flutter's BuildContext `context`.
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

/// Kinds of resources a student can share.
enum ResourceType {
  notes('Notes', Icons.description_outlined),
  practice('Practice', Icons.quiz_outlined),
  syllabus('Syllabus', Icons.menu_book_outlined),
  assignment('Assignment', Icons.assignment_outlined),
  exam('Past exam', Icons.fact_check_outlined);

  const ResourceType(this.label, this.icon);

  final String label; // text shown in dropdowns and list subtitles
  final IconData icon; // icon shown in the list card

  /// Turns the text saved in the database back into the enum.
  /// Unknown values fall back to "notes" so one bad row can't crash the app.
  static ResourceType fromName(String? name) => ResourceType.values.firstWhere(
        (type) => type.name == name,
        orElse: () => ResourceType.notes,
      );
}

/// One shared study resource. Matches one row of the "resources" table.
class Resource {
  Resource({
    this.id,
    required this.courseCode,
    required this.title,
    required this.type,
    required this.semester,
    required this.materialDate,
    required this.uploaderEmail,
    this.pageCount,
    this.description = '',
    this.filePath,
    this.fileSizeBytes,
    DateTime? uploadedAt,
  }) : uploadedAt = uploadedAt ?? DateTime.now();

  /// Row id from SQLite. null = not saved yet (SQLite assigns one on insert).
  final int? id;

  final String courseCode; // e.g. "CSCI 3101U"
  final String title;
  final ResourceType type;
  final String semester; // e.g. "Fall 2026"
  final DateTime materialDate; // date of the lecture/test the material is from
  final int? pageCount; // optional
  final String description; // optional
  final String uploaderEmail; // Firebase Auth email of whoever uploaded it
  final String? filePath; // where the PDF copy lives on the phone (null = sample)
  final int? fileSizeBytes; // size of that PDF
  final DateTime uploadedAt;

  /// Subtitle for the list card, e.g. "Notes | PDF | 4 pages".
  String get summary {
    final parts = [type.label, 'PDF'];
    if (pageCount != null) {
      parts.add('$pageCount ${pageCount == 1 ? 'page' : 'pages'}');
    }
    return parts.join(' | ');
  }

  /// True if [userEmail] uploaded this resource (only they may delete it).
  /// Compared case-insensitively because emails aren't case-sensitive.
  bool isOwnedBy(String userEmail) =>
      userEmail.isNotEmpty &&
      uploaderEmail.toLowerCase() == userEmail.toLowerCase();

  /// Converts the resource into a database row.
  /// SQLite has no DateTime type, so dates are stored as
  /// milliseconds since 1970.
  Map<String, Object?> toMap() => {
        'id': id, // null lets SQLite pick the next id
        'courseCode': courseCode,
        'title': title,
        'type': type.name,
        'semester': semester,
        'materialDate': materialDate.millisecondsSinceEpoch,
        'pageCount': pageCount,
        'description': description,
        'uploaderEmail': uploaderEmail,
        'filePath': filePath,
        'fileSizeBytes': fileSizeBytes,
        'uploadedAt': uploadedAt.millisecondsSinceEpoch,
      };

  /// Rebuilds a resource from a database row (reverse of toMap).
  factory Resource.fromMap(Map<String, Object?> row) => Resource(
        id: row['id'] as int?,
        courseCode: row['courseCode'] as String? ?? '',
        title: row['title'] as String? ?? 'Untitled',
        type: ResourceType.fromName(row['type'] as String?),
        semester: row['semester'] as String? ?? '',
        materialDate: DateTime.fromMillisecondsSinceEpoch(
            row['materialDate'] as int? ?? 0),
        pageCount: row['pageCount'] as int?,
        description: row['description'] as String? ?? '',
        uploaderEmail: row['uploaderEmail'] as String? ?? '',
        filePath: row['filePath'] as String?,
        fileSizeBytes: row['fileSizeBytes'] as int?,
        uploadedAt: DateTime.fromMillisecondsSinceEpoch(
            row['uploadedAt'] as int? ?? 0),
      );
}

/// Formats a date like "Nov 2, 2026" (avoids needing the intl package).
String formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Formats a byte count like "1.4 MB" or "320 KB".
String formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).ceil()} KB';
}

/// Semesters offered in the semester picker.
const List<String> kSemesters = [
  'Fall 2026', 'Summer 2026', 'Winter 2026', 'Fall 2025', 'Winter 2025',
];

// ─────────────────────────────────────────────────────────────────────────────
// Local storage: SQLite database
// ─────────────────────────────────────────────────────────────────────────────

/// All SQLite code lives here, so the screens never write SQL themselves.
/// Use the single shared instance: ResourceDatabase.instance.
class ResourceDatabase {
  ResourceDatabase._(); // private constructor → only one instance
  static final ResourceDatabase instance = ResourceDatabase._();

  static const String _table = 'resources';

  // The open database (opened the first time it is needed).
  Database? _db;

  /// Returns the open database, opening/creating it on first use.
  Future<Database> get database async => _db ??= await _open();

  /// Opens otudoc_resources.db; creates the table + sample rows the very
  /// first time.
  Future<Database> _open() async {
    final folder = await getDatabasesPath();
    return openDatabase(
      p.join(folder, 'otudoc_resources.db'),
      version: 1,
      // onCreate only runs when the database file doesn't exist yet.
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            courseCode    TEXT    NOT NULL,
            title         TEXT    NOT NULL,
            type          TEXT    NOT NULL,
            semester      TEXT    NOT NULL,
            materialDate  INTEGER NOT NULL,
            pageCount     INTEGER,
            description   TEXT,
            uploaderEmail TEXT    NOT NULL,
            filePath      TEXT,
            fileSizeBytes INTEGER,
            uploadedAt    INTEGER NOT NULL
          )
        ''');
        // Sample rows so the demo video never shows an empty screen.
        for (final resource in _sampleResources()) {
          await db.insert(_table, resource.toMap());
        }
      },
    );
  }

  /// All resources for one course, newest upload first.
  Future<List<Resource>> getResources(String courseCode) async {
    final db = await database;
    final rows = await db.query(
      _table,
      where: 'courseCode = ?', // "?" placeholders prevent SQL injection
      whereArgs: [courseCode],
      orderBy: 'uploadedAt DESC',
    );
    return rows.map(Resource.fromMap).toList();
  }

  /// Saves a resource and returns its row id.
  /// "replace" lets UNDO re-insert a deleted row with its old id.
  Future<int> insert(Resource resource) async {
    final db = await database;
    return db.insert(
      _table,
      resource.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes one resource row by id.
  Future<void> delete(int id) async {
    final db = await database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  /// Sample data inserted the first time the database is created.
  static List<Resource> _sampleResources() {
    final now = DateTime.now();
    // Small helper so each sample is one line.
    Resource sample(String title, ResourceType type, int pages,
            DateTime materialDate, int uploadedDaysAgo,
            {String semester = 'Fall 2026', String description = ''}) =>
        Resource(
          courseCode: 'CSCI 3101U',
          title: title,
          type: type,
          semester: semester,
          materialDate: materialDate,
          pageCount: pages,
          description: description,
          uploaderEmail: 'sample.student@ontariotechu.net',
          uploadedAt: now.subtract(Duration(days: uploadedDaysAgo)),
        );

    return [
      sample('Dart study notes', ResourceType.notes, 4, DateTime(2026, 9, 15),
          1, description: 'Variables, null safety, lists and loops.'),
      sample('Practice questions – widgets', ResourceType.practice, 6,
          DateTime(2026, 10, 1), 3),
      sample('Midterm review sheet', ResourceType.exam, 2,
          DateTime(2025, 10, 20), 5, semester: 'Fall 2025'),
      sample('Course syllabus', ResourceType.syllabus, 9, DateTime(2026, 9, 3),
          40),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local storage: PDF files in the app's private folder
// ─────────────────────────────────────────────────────────────────────────────

/// Copies a picked PDF into the app's documents folder.
/// Returns where it was saved and its size in bytes.
/// (file_picker 12+ no longer gives a reliable file path, so we read the
/// bytes and write our own copy — which also survives Android clearing
/// the picker's temporary cache.)
Future<({String path, int size})> savePdfToAppStorage(
    PlatformFile picked, int maxBytes) async {
  // Read the whole PDF into memory (max 20 MB, so this is fine).
  final bytes = await picked.readAsBytes();
  if (bytes.length > maxBytes) {
    throw Exception('File is larger than 20 MB');
  }

  // <app documents>/resources/  (created on first upload)
  final docs = await getApplicationDocumentsDirectory();
  final folder = Directory(p.join(docs.path, 'resources'));
  await folder.create(recursive: true);

  // Keep only safe characters and add a timestamp so names never collide.
  final safeName = picked.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final destination = p.join(
      folder.path, '${DateTime.now().millisecondsSinceEpoch}_$safeName');

  // Write our own copy of the PDF.
  await File(destination).writeAsBytes(bytes, flush: true);
  return (path: destination, size: bytes.length);
}

/// Deletes a saved PDF if it exists (sample resources have no file).
Future<void> deleteSavedPdf(String? path) async {
  if (path == null) return;
  final file = File(path);
  if (await file.exists()) await file.delete();
}

// ─────────────────────────────────────────────────────────────────────────────
// Resources screen (Course hub › Resources)
// ─────────────────────────────────────────────────────────────────────────────

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({
    super.key,
    required this.courseCode,
    required this.courseName,
    required this.userEmail,
  });

  final String courseCode; // e.g. "CSCI 3101U"
  final String courseName; // e.g. "Mobile Devices"

  /// Signed-in user's email (from Firebase Auth). Stored as the uploader of
  /// new resources and used to decide which ones you may delete.
  final String userEmail;

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  // Shortcut to the shared database.
  final ResourceDatabase _db = ResourceDatabase.instance;

  // Resources loaded from SQLite for this course.
  List<Resource> _resources = [];

  // Loading / error state for the first load.
  bool _loading = true;
  String? _loadError;

  // Current search text (lower-cased for matching). Not saved on purpose.
  String _query = '';

  // Selected type filter; null means "All resources". Saved in
  // SharedPreferences so it is remembered next time the app opens.
  ResourceType? _typeFilter;

  /// SharedPreferences key — one per course so each course remembers its own.
  String get _filterKey => 'resources_type_filter_${widget.courseCode}';

  @override
  void initState() {
    super.initState();
    _loadEverything(); // read SQLite + SharedPreferences on startup
  }

  /// First load: saved filter (SharedPreferences) + resources (SQLite).
  Future<void> _loadEverything() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      // 1) Remembered filter.
      final prefs = await SharedPreferences.getInstance();
      final savedFilter = prefs.getString(_filterKey);

      // 2) Resources from the database.
      final resources = await _db.getResources(widget.courseCode);

      if (!mounted) return; // screen closed while loading
      setState(() {
        _typeFilter = savedFilter == null
            ? null
            : ResourceType.fromName(savedFilter);
        _resources = resources;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  /// Re-reads the list from SQLite after an insert/delete.
  Future<void> _refreshList() async {
    final resources = await _db.getResources(widget.courseCode);
    if (mounted) setState(() => _resources = resources);
  }

  /// Changes the filter and saves it in SharedPreferences.
  Future<void> _setTypeFilter(ResourceType? value) async {
    setState(() => _typeFilter = value);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_filterKey); // "All resources" = nothing saved
      } else {
        await prefs.setString(_filterKey, value.name);
      }
    } catch (_) {
      // Not being able to remember the filter isn't worth bothering the user.
    }
  }

  /// The list after applying search + type filter (already newest first).
  List<Resource> get _visibleResources => _resources.where((r) {
        final matchesType = _typeFilter == null || r.type == _typeFilter;
        final matchesQuery =
            _query.isEmpty || r.title.toLowerCase().contains(_query);
        return matchesType && matchesQuery;
      }).toList();

  /// Shows a snackbar (replacing any visible one) and returns its controller,
  /// so callers can react when it closes.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _showSnackBar(
      String message,
      {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    return messenger.showSnackBar(SnackBar(
      content: Text(message),
      action: action,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Opens the upload form; saves what it returns into SQLite.
  Future<void> _openUploadForm() async {
    final newResource = await Navigator.of(context).push<Resource>(
      MaterialPageRoute(
        builder: (_) => UploadResourceScreen(
          courseCode: widget.courseCode,
          userEmail: widget.userEmail,
        ),
      ),
    );
    // null = user backed out.
    if (newResource == null) return;

    try {
      await _db.insert(newResource);
      await _refreshList();
      if (mounted) _showSnackBar('"${newResource.title}" uploaded');
    } catch (e) {
      // Saving the row failed → remove the copied PDF so nothing is orphaned.
      await deleteSavedPdf(newResource.filePath);
      if (mounted) _showSnackBar('Could not save: $e');
    }
  }

  /// Confirms with a dialog, deletes from SQLite, offers UNDO.
  /// The PDF file itself is only deleted once UNDO is no longer possible.
  Future<void> _confirmDelete(Resource resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete resource?'),
        content: Text('"${resource.title}" will be removed from '
            '${widget.courseCode}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || resource.id == null) return;

    try {
      await _db.delete(resource.id!);
      await _refreshList();
    } catch (e) {
      if (mounted) _showSnackBar('Could not delete: $e');
      return;
    }
    if (!mounted) return;

    final snackBar = _showSnackBar(
      'Resource deleted',
      action: SnackBarAction(
        label: 'UNDO',
        // Re-insert the same row (same id), then reload the list.
        onPressed: () async {
          await _db.insert(resource);
          await _refreshList();
        },
      ),
    );

    // When the snackbar goes away without UNDO being tapped,
    // the deletion is final → remove the PDF from the phone too.
    snackBar.closed.then((reason) {
      if (reason != SnackBarClosedReason.action) {
        deleteSavedPdf(resource.filePath);
      }
    });
  }

  /// Bottom sheet with the resource details and actions.
  void _showDetails(Resource resource) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(resource.title,
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(resource.summary),
            if (resource.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(resource.description),
            ],
            const SizedBox(height: 12),
            _DetailRow(label: 'Semester', value: resource.semester),
            _DetailRow(
                label: 'Material date',
                value: formatDate(resource.materialDate)),
            _DetailRow(label: 'Uploaded by', value: resource.uploaderEmail),
            _DetailRow(
                label: 'Uploaded on', value: formatDate(resource.uploadedAt)),
            // Show the saved file (sample resources have none).
            _DetailRow(
              label: 'File',
              value: resource.filePath == null
                  ? 'Sample (no file)'
                  : '${p.basename(resource.filePath!)}'
                      '${resource.fileSizeBytes == null ? '' : ' · ${formatFileSize(resource.fileSizeBytes!)}'}',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Delete only appears on your own uploads.
                if (resource.isOwnedBy(widget.userEmail))
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop(); // close sheet first
                      _confirmDelete(resource);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    // Placeholder until the Document preview screen exists.
                    _showSnackBar('Document preview coming soon');
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Course hub'),
      ),
      body: _buildBody(theme),
    );
  }

  /// Chooses between loading spinner, error view, and the real page.
  Widget _buildBody(ThemeData theme) {
    // Still reading from storage.
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Storage failed to open — show the error with a retry button.
    if (_loadError != null) {
      return _MessageView(
        icon: Icons.error_outline,
        message: 'Could not load resources.\n$_loadError',
        actionLabel: 'Try again',
        onAction: _loadEverything,
      );
    }

    final resources = _visibleResources;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Course header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.courseCode,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text('${widget.courseName} | Joined',
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),

        // ── Search box (filters as you type) ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search resources',
              isDense: true,
            ),
            onChanged: (text) =>
                setState(() => _query = text.trim().toLowerCase()),
          ),
        ),

        // ── Type filter (remembered with SharedPreferences) ──
        // Built only after loading, so initialValue is the saved filter.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<ResourceType?>(
            initialValue: _typeFilter,
            decoration: const InputDecoration(
              labelText: 'Type',
              isDense: true,
            ),
            items: [
              // null value = show everything
              const DropdownMenuItem(value: null, child: Text('All resources')),
              for (final type in ResourceType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: _setTypeFilter,
          ),
        ),

        // ── Resource list ──
        Expanded(
          child: resources.isEmpty
              // Empty state: different message for "no match" vs "none yet".
              ? _MessageView(
                  icon: Icons.folder_open,
                  message: _query.isNotEmpty || _typeFilter != null
                      ? 'No resources match your search.'
                      : 'No resources yet.\nBe the first to upload one!',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: resources.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final resource = resources[index];
                    return _ResourceCard(
                      resource: resource,
                      isMine: resource.isOwnedBy(widget.userEmail),
                      onTap: () => _showDetails(resource),
                      // Long-press shortcut to delete your own uploads.
                      onLongPress: resource.isOwnedBy(widget.userEmail)
                          ? () => _confirmDelete(resource)
                          : null,
                    );
                  },
                ),
        ),

        // ── "Upload resource" button pinned at the bottom ──
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            // Styled by elevatedButtonTheme in lib/app/theme.dart.
            child: ElevatedButton.icon(
              onPressed: _openUploadForm,
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload resource'),
            ),
          ),
        ),
      ],
    );
  }
}

/// One card in the resource list.
class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.resource,
    required this.isMine,
    required this.onTap,
    this.onLongPress,
  });

  final Resource resource;
  final bool isMine; // true if the signed-in user uploaded it
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias, // keeps the tap ripple inside the corners
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Icon(resource.type.icon),
        ),
        title: Text(resource.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(resource.summary),
        // Small "Yours" tag on your own uploads.
        trailing: isMine
            ? Chip(
                label: const Text('Yours'),
                visualDensity: VisualDensity.compact,
                backgroundColor: scheme.secondaryContainer,
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

/// Label/value row used in the details sheet.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// Centered icon + message for empty and error states (optional button).
class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center, style: TextStyle(color: color)),
            // Retry button (only on the error view).
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload screen (form)
// ─────────────────────────────────────────────────────────────────────────────

class UploadResourceScreen extends StatefulWidget {
  const UploadResourceScreen({
    super.key,
    required this.courseCode,
    required this.userEmail,
  });

  final String courseCode;
  final String userEmail; // saved as the uploader of the new resource

  @override
  State<UploadResourceScreen> createState() => _UploadResourceScreenState();
}

class _UploadResourceScreenState extends State<UploadResourceScreen> {
  // Max PDF size from the proposal: 20 MB.
  static const int _maxBytes = 20 * 1024 * 1024;

  // Key used to run every field's validator at once.
  final _formKey = GlobalKey<FormState>();

  // Text field controllers.
  final _titleController = TextEditingController();
  final _pagesController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Picker values.
  ResourceType _type = ResourceType.notes;
  String _semester = kSemesters.first;
  DateTime? _materialDate; // null until the user picks a date

  // The PDF chosen with the file picker (null until picked).
  PlatformFile? _pickedFile;
  int? _pickedSize; // its size in bytes (null if the picker can't tell)
  String? _fileError; // error shown under the "Choose PDF" button

  // True while saving (shows a spinner, disables the form).
  bool _saving = false;

  @override
  void dispose() {
    // Free the controllers when the screen closes.
    _titleController.dispose();
    _pagesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// True if the user typed or picked anything (for the discard dialog).
  bool get _hasChanges =>
      _titleController.text.isNotEmpty ||
      _pagesController.text.isNotEmpty ||
      _descriptionController.text.isNotEmpty ||
      _materialDate != null ||
      _pickedFile != null;

  /// Opens the system file picker, PDFs only.
  Future<void> _pickPdf() async {
    // file_picker 12+: static call that returns a list (empty = cancelled).
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (files.isEmpty) return; // user cancelled

    final file = files.first;
    // length() can return null if the size is unknown; in that case the
    // 20 MB check happens again when the file is saved.
    final size = await file.length();
    if (!mounted) return;

    setState(() {
      if (size != null && size > _maxBytes) {
        // Too big → reject right away.
        _pickedFile = null;
        _pickedSize = null;
        _fileError = 'File is larger than 20 MB';
      } else {
        _pickedFile = file;
        _pickedSize = size;
        _fileError = null;
        // Pre-fill the title from the file name if it's still empty.
        if (_titleController.text.isEmpty) {
          _titleController.text = file.name
              .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '')
              .replaceAll('_', ' ');
        }
      }
    });
  }

  /// Opens the date picker for the material date.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _materialDate ?? now,
      firstDate: DateTime(now.year - 5), // up to 5 years back
      lastDate: now, // can't be in the future
      helpText: 'Date of the lecture or test',
    );
    if (picked != null) setState(() => _materialDate = picked);
  }

  /// Validates, copies the PDF into app storage, and returns the resource.
  /// (The Resources screen inserts it into SQLite.)
  Future<void> _submit() async {
    // Text fields + date use validators; the file is checked by hand.
    final fieldsValid = _formKey.currentState!.validate();
    if (_pickedFile == null) {
      setState(() => _fileError ??= 'Choose a PDF');
    }
    if (!fieldsValid || _pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Save our own copy of the PDF on the phone.
      final saved = await savePdfToAppStorage(_pickedFile!, _maxBytes);

      final pagesText = _pagesController.text.trim();
      final resource = Resource(
        courseCode: widget.courseCode,
        title: _titleController.text.trim(),
        type: _type,
        semester: _semester,
        materialDate: _materialDate!, // validated as non-null above
        pageCount: pagesText.isEmpty ? null : int.parse(pagesText),
        description: _descriptionController.text.trim(),
        uploaderEmail: widget.userEmail, // signed-in user is the uploader
        filePath: saved.path,
        fileSizeBytes: saved.size,
      );

      // Send it back; the Resources screen saves it and shows the snackbar.
      if (mounted) Navigator.of(context).pop(resource);
    } catch (e) {
      // Stay on the form so the user can try again.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not save the file: $e'),
        action: SnackBarAction(label: 'RETRY', onPressed: _submit),
      ));
    }
  }

  /// Asks before throwing away a half-filled form.
  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard upload?'),
        content: const Text('Your changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // PopScope catches the back button so we can ask before discarding.
    return PopScope<Resource>(
      canPop: !_hasChanges && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return; // already left, or busy saving
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Upload resource'),
        ),
        body: Form(
          key: _formKey,
          // Rebuild on every edit so PopScope's canPop (_hasChanges) stays current.
          onChanged: () => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Sharing to ${widget.courseCode}',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 16),

              // ── PDF file picker (required) ──
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: Text(
                  _pickedFile == null
                      ? 'Choose PDF'
                      : _pickedSize == null
                          ? _pickedFile!.name
                          : '${_pickedFile!.name} (${formatFileSize(_pickedSize!)})',
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
              // File error styled like a normal form error.
              if (_fileError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(_fileError!,
                      style: TextStyle(
                          color: theme.colorScheme.error, fontSize: 12)),
                ),
              const SizedBox(height: 16),

              // ── Title (required, at least 3 characters) ──
              TextFormField(
                controller: _titleController,
                enabled: !_saving,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Dart study notes',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Enter a title';
                  if (text.length < 3) return 'Title is too short';
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // ── Resource type picker ──
              DropdownButtonFormField<ResourceType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                ),
                items: [
                  for (final type in ResourceType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: 16),

              // ── Semester picker ──
              DropdownButtonFormField<String>(
                initialValue: _semester,
                decoration: const InputDecoration(
                  labelText: 'Semester',
                ),
                items: [
                  for (final s in kSemesters)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _semester = value!),
              ),
              const SizedBox(height: 16),

              // ── Material date (date picker, required) ──
              // A FormField so it can show an error like the text fields do.
              FormField<DateTime>(
                validator: (_) =>
                    _materialDate == null ? 'Choose a date' : null,
                builder: (field) => InkWell(
                  onTap: _saving
                      ? null
                      : () async {
                          await _pickDate();
                          field.didChange(_materialDate); // clears the error
                        },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Material date',
                      suffixIcon: const Icon(Icons.calendar_today),
                      errorText: field.errorText,
                    ),
                    child: Text(_materialDate == null
                        ? 'Tap to choose'
                        : formatDate(_materialDate!)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Page count (optional, 1–500 if given) ──
              TextFormField(
                controller: _pagesController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of pages (optional)',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null; // optional
                  final pages = int.tryParse(text);
                  if (pages == null) return 'Enter a whole number';
                  if (pages < 1 || pages > 500) return 'Enter 1 to 500';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Description (optional) ──
              TextFormField(
                controller: _descriptionController,
                enabled: !_saving,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),

              // Reminder from the proposal.
              Text(
                'Only share material you are allowed to distribute.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),

              // ── Upload button ──
              // Styled by elevatedButtonTheme in lib/app/theme.dart.
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    // Spinner while the PDF is being copied.
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Upload'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
