// main.dart
//
// OTUDOC — Course hub › Resources page (single-file version).
//
// Everything runs locally: uploaded resources are kept in memory while the
// app is open (no Firebase, no extra packages). The data lives in one list
// inside _ResourcesScreenState, so swapping in Firestore later only means
// replacing that list with a database call.
//
// Course features shown on this page (for the Part 2 rubric):
//   • ListView ........ the resource list
//   • Search/filter ... live search box + "Type" dropdown
//   • Dialogs ......... delete confirmation, "Discard upload?"
//   • Pickers ......... date picker, type + semester dropdowns
//   • Forms ........... upload form with validation
//   • Snackbars ....... after upload, after delete (with UNDO)
//   • Navigation ...... Resources → Upload screen (returns the new resource)

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// App entry point
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  runApp(const OtudocApp());
}

class OtudocApp extends StatelessWidget {
  const OtudocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OTUDOC',
      debugShowCheckedModeBanner: false,
      // Purple seed colour to match the proposal mockups.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B4CF5)),
      ),
      home: const ResourcesScreen(
        courseCode: 'CSCI 3101U',
        courseName: 'Mobile Devices',
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

/// Kinds of resources a student can share. `label` is the text shown in the UI.
enum ResourceType {
  notes('Notes', Icons.description_outlined),
  practice('Practice', Icons.quiz_outlined),
  syllabus('Syllabus', Icons.menu_book_outlined),
  assignment('Assignment', Icons.assignment_outlined),
  exam('Past exam', Icons.fact_check_outlined);

  const ResourceType(this.label, this.icon);

  final String label; // shown in dropdowns and list subtitles
  final IconData icon; // shown in the list card
}

/// One shared study resource (title, type, semester, etc.).
class Resource {
  Resource({
    required this.title,
    required this.type,
    required this.semester,
    required this.materialDate,
    required this.uploaderName,
    required this.isMine,
    this.pageCount,
    this.description = '',
  }) : uploadedAt = DateTime.now();

  final String title;
  final ResourceType type;
  final String semester; // e.g. "Fall 2026"
  final DateTime materialDate; // date of the lecture/test the material is from
  final int? pageCount; // optional
  final String description; // optional
  final String uploaderName;
  final bool isMine; // only your own uploads can be deleted
  final DateTime uploadedAt;

  /// Subtitle for the list card, e.g. "Notes | PDF | 4 pages".
  String get summary {
    final parts = [type.label, 'PDF'];
    if (pageCount != null) {
      parts.add('$pageCount ${pageCount == 1 ? 'page' : 'pages'}');
    }
    return parts.join(' | ');
  }
}

/// Formats a date like "Nov 2, 2026" (avoids needing the intl package).
String formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Semesters offered in the semester picker.
const List<String> kSemesters = [
  'Fall 2026', 'Summer 2026', 'Winter 2026', 'Fall 2025', 'Winter 2025',
];

// ─────────────────────────────────────────────────────────────────────────────
// Resources screen (Course hub › Resources)
// ─────────────────────────────────────────────────────────────────────────────

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({
    super.key,
    required this.courseCode,
    required this.courseName,
  });

  final String courseCode; // e.g. "CSCI 3101U"
  final String courseName; // e.g. "Mobile Devices"

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  // All resources for this course. Starts with sample data so the demo
  // video never shows an empty screen.
  final List<Resource> _resources = [
    Resource(
      title: 'Dart study notes',
      type: ResourceType.notes,
      semester: 'Fall 2026',
      materialDate: DateTime(2026, 9, 15),
      pageCount: 4,
      uploaderName: 'Sample student',
      isMine: false,
      description: 'Variables, null safety, lists and loops.',
    ),
    Resource(
      title: 'Practice questions – widgets',
      type: ResourceType.practice,
      semester: 'Fall 2026',
      materialDate: DateTime(2026, 10, 1),
      pageCount: 6,
      uploaderName: 'Sample student',
      isMine: false,
    ),
    Resource(
      title: 'Midterm review sheet',
      type: ResourceType.exam,
      semester: 'Fall 2025',
      materialDate: DateTime(2025, 10, 20),
      pageCount: 2,
      uploaderName: 'Sample student',
      isMine: false,
    ),
    Resource(
      title: 'Course syllabus',
      type: ResourceType.syllabus,
      semester: 'Fall 2026',
      materialDate: DateTime(2026, 9, 3),
      pageCount: 9,
      uploaderName: 'Sample student',
      isMine: false,
    ),
  ];

  // Current search text (lower-cased for matching).
  String _query = '';

  // Selected type filter; null means "All resources".
  ResourceType? _typeFilter;

  /// The list after applying search + type filter, newest upload first.
  List<Resource> get _visibleResources {
    final list = _resources.where((r) {
      final matchesType = _typeFilter == null || r.type == _typeFilter;
      final matchesQuery =
          _query.isEmpty || r.title.toLowerCase().contains(_query);
      return matchesType && matchesQuery;
    }).toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return list;
  }

  /// Shows a snackbar, replacing any one already visible.
  void _showSnackBar(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: action,
        behavior: SnackBarBehavior.floating,
      ));
  }

  /// Opens the upload form and adds whatever it returns to the list.
  Future<void> _openUploadForm() async {
    final newResource = await Navigator.of(context).push<Resource>(
      MaterialPageRoute(
        builder: (_) => UploadResourceScreen(courseCode: widget.courseCode),
      ),
    );
    // null = user backed out; !mounted = screen was closed meanwhile.
    if (newResource == null || !mounted) return;

    setState(() => _resources.add(newResource));
    _showSnackBar('"${newResource.title}" uploaded');
  }

  /// Confirms with a dialog, deletes, then offers UNDO in a snackbar.
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
    if (confirmed != true || !mounted) return;

    setState(() => _resources.remove(resource));
    _showSnackBar(
      'Resource deleted',
      action: SnackBarAction(
        label: 'UNDO',
        // Puts the same resource back into the list.
        onPressed: () => setState(() => _resources.add(resource)),
      ),
    );
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
            _DetailRow(label: 'Uploaded by', value: resource.uploaderName),
            const SizedBox(height: 16),
            Row(
              children: [
                // Delete only appears on your own uploads.
                if (resource.isMine)
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
    final resources = _visibleResources;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Course hub'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: Column(
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
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (text) =>
                  setState(() => _query = text.trim().toLowerCase()),
            ),
          ),

          // ── Type filter ("Type: All resources") ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<ResourceType?>(
              initialValue: _typeFilter,
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                // null value = show everything
                const DropdownMenuItem(
                    value: null, child: Text('All resources')),
                for (final type in ResourceType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) => setState(() => _typeFilter = value),
            ),
          ),

          // ── Resource list ──
          Expanded(
            child: resources.isEmpty
            // Empty state: different message for "no match" vs "none yet".
                ? _EmptyView(
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
                  onTap: () => _showDetails(resource),
                  // Long-press shortcut to delete your own uploads.
                  onLongPress: resource.isMine
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
              child: FilledButton.icon(
                onPressed: _openUploadForm,
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload resource'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One card in the resource list.
class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.resource,
    required this.onTap,
    this.onLongPress,
  });

  final Resource resource;
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
        trailing: resource.isMine
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

/// Centered icon + message when the list is empty.
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open, size: 48, color: color),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center, style: TextStyle(color: color)),
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
  const UploadResourceScreen({super.key, required this.courseCode});

  final String courseCode;

  @override
  State<UploadResourceScreen> createState() => _UploadResourceScreenState();
}

class _UploadResourceScreenState extends State<UploadResourceScreen> {
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

  // True while "uploading" (shows a spinner, disables the form).
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
          _materialDate != null;

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

  /// Validates the form, then returns the new resource to the list screen.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      // Snackbar pointing out that something needs fixing.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields')),
      );
      return;
    }

    setState(() => _saving = true);
    // Short pause to imitate a network upload.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final pagesText = _pagesController.text.trim();
    final resource = Resource(
      title: _titleController.text.trim(),
      type: _type,
      semester: _semester,
      materialDate: _materialDate!, // validated as non-null above
      pageCount: pagesText.isEmpty ? null : int.parse(pagesText),
      description: _descriptionController.text.trim(),
      uploaderName: 'You',
      isMine: true,
    );
    // Send the resource back; the Resources screen shows the snackbar.
    Navigator.of(context).pop(resource);
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
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
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

              // ── Title (required, at least 3 characters) ──
              TextFormField(
                controller: _titleController,
                enabled: !_saving,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Dart study notes',
                  border: OutlineInputBorder(),
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
                  border: OutlineInputBorder(),
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
                  border: OutlineInputBorder(),
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
                      border: const OutlineInputBorder(),
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
                  border: OutlineInputBorder(),
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
                  border: OutlineInputBorder(),
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
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: _saving
                // Spinner while "uploading".
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
