import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../discussion/discussion_view.dart';
import 'resource_store.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class Course {
  Course({required this.code, required this.name, this.isJoined = false});

  final String code;
  final String name;
  bool isJoined;
}

enum ResourceType {
  notes('Notes', Icons.description_outlined),
  practice('Practice', Icons.quiz_outlined),
  syllabus('Syllabus', Icons.menu_book_outlined),
  assignment('Assignment', Icons.assignment_outlined),
  exam('Past exam', Icons.fact_check_outlined);

  const ResourceType(this.label, this.icon);

  final String label;
  final IconData icon;
}

class Resource {
  Resource({
    this.id,
    required this.courseCode,
    required this.title,
    required this.type,
    required this.semester,
    required this.materialDate,
    required this.uploaderEmail,
    required this.currentUserId,
    this.pageCount,
    this.description = '',
    DateTime? uploadedAt,
    this.filePath,
    this.fileName,
    this.fileSizeBytes,
  }) : uploadedAt = uploadedAt ?? DateTime.now(); // new uploads default to "now"

  /// Set by the store once the resource is saved (null on a fresh draft).
  final int? id;

  /// Course this resource belongs to, e.g. "CSCI 3101U".
  final String courseCode;
  final String title;
  final ResourceType type;
  final String semester;
  final DateTime materialDate;
  final int? pageCount;
  final String description;
  final String uploaderEmail;
  final String currentUserId;
  final DateTime uploadedAt;

  /// Where the PDF is saved on the phone (null for seeded sample resources).
  final String? filePath;

  /// Original name of the uploaded file, e.g. "week3_notes.pdf".
  final String? fileName;

  /// Size of the uploaded file in bytes.
  final int? fileSizeBytes;

  bool get isMine => uploaderEmail.toLowerCase() == currentUserId.toLowerCase();

  /// True when a real PDF is attached (false for sample data).
  bool get hasFile => filePath != null;

  String get summary {
    final parts = [type.label, 'PDF'];
    if (pageCount != null) {
      parts.add('$pageCount ${pageCount == 1 ? 'page' : 'pages'}');
    }
    // Show the file size when we know it.
    if (fileSizeBytes != null) parts.add(formatFileSize(fileSizeBytes!));
    return parts.join(' | ');
  }

  /// Returns a copy with the given fields replaced. The store uses this to
  /// attach the id and saved file path to a draft from the upload form.
  Resource copyWith({
    int? id,
    String? filePath,
    String? fileName,
    int? fileSizeBytes,
  }) {
    return Resource(
      id: id ?? this.id,
      courseCode: courseCode,
      title: title,
      type: type,
      semester: semester,
      materialDate: materialDate,
      uploaderEmail: uploaderEmail,
      currentUserId: currentUserId,
      pageCount: pageCount,
      description: description,
      uploadedAt: uploadedAt,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }
}

String formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

const List<String> kSemesters = [
  'Fall 2026',
  'Summer 2026',
  'Winter 2026',
  'Fall 2025',
  'Winter 2025',
];

// ─────────────────────────────────────────────────────────────────────────────
// Courses Screen
// ─────────────────────────────────────────────────────────────────────────────
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final List<Course> _courses = [
    Course(code: 'CSCI 3101U', name: 'Mobile Devices', isJoined: true),
    Course(code: 'CSCI 2010U', name: 'Data Structures', isJoined: false),
    Course(
      code: 'INFR 2820U',
      name: 'Algorithms & Data Structures',
      isJoined: true,
    ),
    Course(
      code: 'CSCI 3070U',
      name: 'Analysis & Design of Algorithms',
      isJoined: false,
    ),
  ];

  String _searchQuery = '';
  bool _showJoinedOnly = false;

  List<Course> get _filteredCourses {
    return _courses.where((c) {
      final matchesFilter = !_showJoinedOnly || c.isJoined;
      final matchesQuery =
          _searchQuery.isEmpty ||
          c.code.toLowerCase().contains(_searchQuery) ||
          c.name.toLowerCase().contains(_searchQuery);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  void _changeMembership(Course course, bool join) {
    final previousValue = course.isJoined;
    setState(() => course.isJoined = join);

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(join ? 'Joined ${course.code}' : 'Left ${course.code}'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (!mounted) return;
              setState(() => course.isJoined = previousValue);
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = AuthService().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Courses'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Search courses', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Code or course name',
                  ),
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('All')),
                          ButtonSegment(value: true, label: Text('Joined')),
                        ],
                        selected: {_showJoinedOnly},
                        onSelectionChanged: (set) {
                          setState(() => _showJoinedOnly = set.first);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredCourses.isEmpty
                ? const Center(child: Text('No courses found.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredCourses.length,
                    itemBuilder: (context, index) {
                      final course = _filteredCourses[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.code,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                course.name,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              if (course.isJoined)
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ResourcesScreen(
                                              courseCode: course.code,
                                              courseName: course.name,
                                              userEmail:
                                                  currentUser?.email ?? '',
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('Open course'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          _changeMembership(course, false),
                                      icon: const Icon(Icons.logout),
                                      label: const Text('Leave course'),
                                    ),
                                  ],
                                )
                              else
                                FilledButton.icon(
                                  onPressed: () =>
                                      _changeMembership(course, true),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Join course'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Search by course code or course name.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resources Screen
// ─────────────────────────────────────────────────────────────────────────────

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({
    super.key,
    required this.courseCode,
    required this.courseName,
    required this.userEmail,
    this.store,
    this.pickPdf,
  });

  final String courseCode;
  final String courseName;
  final String userEmail;

  /// Where resources are saved. Defaults to SQLite on Android; tests pass a
  /// MemoryResourceStore.
  final ResourceStore? store;

  /// How the upload form chooses a PDF. Defaults to the real file picker;
  /// tests pass a fake.
  final PdfPicker? pickPdf;

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  // Filled once the store finishes loading.
  final List<Resource> _resources = [];
  bool _loading = true;
  String? _loadError;

  final _searchController = TextEditingController();
  String _query = '';
  ResourceType? _typeFilter;
  bool _showDiscussion = false;

  // The store to use: the one passed in, or the app-wide default.
  ResourceStore get _store => widget.store ?? ResourceStore.instance;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  /// Reads this course's resources from the store.
  Future<void> _loadResources() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final loaded = await _store.loadFor(widget.courseCode, widget.userEmail);
      if (!mounted) return;
      setState(() {
        _resources
          ..clear()
          ..addAll(loaded);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Could not load resources.';
      });
    }
  }

  /// Opens the resource's PDF, or explains why it can't be opened.
  Future<void> _openFile(Resource resource) async {
    final error = await openResourceFile(resource);
    if (error != null && mounted) _showSnackBar(error);
  }

  List<Resource> get _visibleResources {
    return _resources.where((r) {
      final matchesType = _typeFilter == null || r.type == _typeFilter;
      final matchesQuery =
          _query.isEmpty || r.title.toLowerCase().contains(_query);
      return matchesType && matchesQuery;
    }).toList()..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  void _showSnackBar(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: action,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _openUploadForm() async {
    FocusScope.of(context).unfocus();
    final newResource = await Navigator.of(context).push<Resource>(
      MaterialPageRoute(
        builder: (_) => UploadResourceScreen(
          courseCode: widget.courseCode,
          userEmail: widget.userEmail,
          store: _store,
          pickPdf: widget.pickPdf ?? pickPdfFromDevice,
        ),
      ),
    );
    if (newResource == null || !mounted) return;

    setState(() {
      _resources.add(newResource);
      _searchController.clear();
      _query = '';
      _typeFilter = null;
    });
    _showSnackBar('"${newResource.title}" uploaded');
  }

  Future<void> _confirmDelete(Resource resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete resource?'),
        content: Text(
          '"${resource.title}" will be removed from ${widget.courseCode}.',
        ),
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

    // Remove from the screen right away, then from the store.
    setState(() => _resources.remove(resource));
    try {
      await _store.remove(resource);
    } catch (_) {
      // Store failed: put it back so the screen matches what's saved.
      if (!mounted) return;
      setState(() => _resources.add(resource));
      _showSnackBar('Could not delete "${resource.title}". Try again.');
      return;
    }
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final snackBar = messenger.showSnackBar(
      SnackBar(
        content: const Text('Resource deleted'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () async {
            // Undo: put the record back in the store and on screen.
            await _store.restore(resource);
            if (mounted) setState(() => _resources.add(resource));
          },
        ),
      ),
    );
    // The PDF is only deleted once the snackbar closes without "Undo",
    // otherwise Undo would bring back a record with no file.
    snackBar.closed.then((reason) {
      if (reason != SnackBarClosedReason.action) _store.deleteFile(resource);
    });
  }

  void _showDetails(Resource resource) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resource.title,
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
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
              value: formatDate(resource.materialDate),
            ),
            _DetailRow(label: 'Uploaded by', value: resource.uploaderEmail),
            _DetailRow(label: 'Uploaded on', value: formatDate(resource.uploadedAt)),
            // File info only exists for real uploads, not sample data.
            if (resource.fileName != null)
              _DetailRow(label: 'File', value: resource.fileName!),
            const SizedBox(height: 16),
            Row(
              children: [
                if (resource.isMine)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _confirmDelete(resource);
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    // Opens the PDF in the phone's PDF viewer.
                    _openFile(resource);
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
      appBar: AppBar(title: const Text('Course hub')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.courseCode,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.courseName} | Joined',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Resources')),
                ButtonSegment(value: true, label: Text('Discussion')),
              ],
              selected: {_showDiscussion},
              onSelectionChanged: (set) {
                FocusScope.of(context).unfocus();
                setState(() => _showDiscussion = set.first);
              },
            ),
          ),
          if (_showDiscussion)
            Expanded(
              child: DiscussionView(
                courseCode: widget.courseCode,
                userEmail: widget.userEmail,
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search resources',
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _searchController.clear();
                            _query = '';
                          }),
                        ),
                ),
                onChanged: (text) =>
                    setState(() => _query = text.trim().toLowerCase()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<ResourceType?>(
                key: ValueKey(_typeFilter),
                initialValue: _typeFilter,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All resources'),
                  ),
                  for (final type in ResourceType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) => setState(() => _typeFilter = value),
              ),
            ),
            Expanded(
              // Spinner while loading, retry on error, otherwise the list.
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _loadError != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_loadError!),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _loadResources,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  : resources.isEmpty
                  ? _EmptyView(
                      message: _query.isNotEmpty || _typeFilter != null
                          ? 'No resources match your search.'
                          : 'No resources yet.\nBe the first to upload one!',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: resources.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final resource = resources[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(resource.type.icon),
                            ),
                            title: Text(
                              resource.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(resource.summary),
                            trailing: resource.isMine
                                ? const Chip(label: Text('Yours'))
                                : const Icon(Icons.chevron_right),
                            onTap: () => _showDetails(resource),
                            onLongPress: resource.isMine
                                ? () => _confirmDelete(resource)
                                : null,
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: ElevatedButton.icon(
                  onPressed: _openUploadForm,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload resource'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

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
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upload Screen Form
// ─────────────────────────────────────────────────────────────────────────────

class UploadResourceScreen extends StatefulWidget {
  const UploadResourceScreen({
    super.key,
    required this.courseCode,
    required this.userEmail,
    required this.store,
    required this.pickPdf,
  });

  final String courseCode;
  final String userEmail;

  /// Saves the resource and its PDF when the form is submitted.
  final ResourceStore store;

  /// Opens the file chooser (a fake one in tests).
  final PdfPicker pickPdf;

  @override
  State<UploadResourceScreen> createState() => _UploadResourceScreenState();
}

class _UploadResourceScreenState extends State<UploadResourceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _pagesController = TextEditingController();
  final _descriptionController = TextEditingController();

  ResourceType _type = ResourceType.notes;
  String _semester = kSemesters.first;
  DateTime? _materialDate;
  PickedPdf? _file; // the PDF the user chose, null until they pick one
  bool _saving = false;
  bool _confirmingExit = false;

  @override
  void dispose() {
    _titleController.dispose();
    _pagesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _hasChanges =>
      _titleController.text.isNotEmpty ||
      _pagesController.text.isNotEmpty ||
      _descriptionController.text.isNotEmpty ||
      _materialDate != null ||
      _file != null || // picking a file counts as an unsaved change
      _type != ResourceType.notes ||
      _semester != kSemesters.first;

  Future<void> _confirmExit() async {
    if (_saving || _confirmingExit) return;
    _confirmingExit = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard upload?'),
        content: const Text('Your unsaved resource details will be lost.'),
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
    _confirmingExit = false;
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _materialDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _materialDate = picked);
  }

  Future<void> _submit() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields')),
      );
      return;
    }

    setState(() => _saving = true);

    // Build the draft from the form fields (no id or saved path yet).
    final pagesText = _pagesController.text.trim();
    final draft = Resource(
      courseCode: widget.courseCode,
      title: _titleController.text.trim(),
      type: _type,
      semester: _semester,
      materialDate: _materialDate!,
      pageCount: pagesText.isEmpty ? null : int.parse(pagesText),
      description: _descriptionController.text.trim(),
      uploaderEmail: widget.userEmail,
      currentUserId: widget.userEmail,
    );

    try {
      // Copies the PDF into app storage and saves the record.
      final saved = await widget.store.add(draft, _file!);
      if (!mounted) return;
      // Hand the saved resource back to the hub so it appears in the list.
      Navigator.of(context).pop(saved);
    } catch (e) {
      // Keep the form filled in so the user can try again.
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed. Please try again.')),
      );
    }
  }

  /// Lets the user choose a PDF and checks it before accepting it.
  Future<void> _choosePdf() async {
    FocusScope.of(context).unfocus();
    PickedPdf? result;
    try {
      result = await widget.pickPdf();
    } catch (e) {
      // e.g. the picker plugin isn't available on this platform.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the file picker.')),
      );
      return;
    }
    if (result == null || !mounted) return; // user cancelled
    final picked = result; // non-null from here on

    // Double-check the extension in case the picker let something else through.
    if (!picked.name.toLowerCase().endsWith('.pdf')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only PDF files can be uploaded.')),
      );
      return;
    }
    if (picked.sizeBytes > kMaxUploadBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'That file is too big. The limit is '
            '${formatFileSize(kMaxUploadBytes)}.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _file = picked;
      // Fill in the title from the file name if the user hasn't typed one.
      if (_titleController.text.trim().isEmpty) {
        final name = picked.name;
        _titleController.text = name.substring(0, name.length - 4);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Resource>(
      canPop: !_hasChanges && !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Upload resource')),
        body: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Sharing to ${widget.courseCode}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              // PDF picker. Wrapped in a FormField so "Upload" shows an error
              // under it when no file was chosen, like the other fields.
              FormField<PickedPdf>(
                validator: (_) => _file == null ? 'Choose a PDF to upload' : null,
                builder: (field) => InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _saving
                      ? null
                      : () async {
                          await _choosePdf();
                          if (!mounted || !field.mounted) return;
                          // Re-run validation so the error clears after picking.
                          field.didChange(_file);
                        },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'File',
                      prefixIcon: const Icon(Icons.picture_as_pdf_outlined),
                      suffixIcon: _file == null
                          ? const Icon(Icons.attach_file)
                          : const Icon(Icons.swap_horiz), // tap again to replace
                      errorText: field.errorText,
                    ),
                    child: Text(
                      _file == null
                          ? 'Choose PDF'
                          : '${_file!.name} (${formatFileSize(_file!.sizeBytes)})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                enabled: !_saving,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Dart study notes',
                ),
                validator: (val) {
                  final text = val?.trim() ?? '';
                  if (text.isEmpty) return 'Enter a title';
                  if (text.length < 3) return 'Title is too short';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<ResourceType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final type in ResourceType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: _saving ? null : (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _semester,
                decoration: const InputDecoration(labelText: 'Semester'),
                items: [
                  for (final s in kSemesters)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _semester = v!),
              ),
              const SizedBox(height: 16),
              FormField<DateTime>(
                validator: (_) =>
                    _materialDate == null ? 'Choose a date' : null,
                builder: (field) => InkWell(
                  onTap: _saving
                      ? null
                      : () async {
                          await _pickDate();
                          if (!mounted || !field.mounted) return;
                          field.didChange(_materialDate);
                        },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Material date',
                      suffixIcon: const Icon(Icons.calendar_today),
                      errorText: field.errorText,
                    ),
                    child: Text(
                      _materialDate == null
                          ? 'Tap to choose'
                          : formatDate(_materialDate!),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pagesController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of pages (optional)',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final pages = int.tryParse(text);
                  return pages == null || pages <= 0
                      ? 'Enter a whole number greater than zero'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                enabled: !_saving,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Upload'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
