import 'package:flutter/material.dart';

import '../auth/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class Course {
  Course({
    required this.code,
    required this.name,
    this.isJoined = false,
  });

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
    required this.title,
    required this.type,
    required this.semester,
    required this.materialDate,
    required this.uploaderEmail,
    required this.currentUserId,
    this.pageCount,
    this.description = '',
  }) : uploadedAt = DateTime.now();

  final String title;
  final ResourceType type;
  final String semester;
  final DateTime materialDate;
  final int? pageCount;
  final String description;
  final String uploaderEmail;
  final String currentUserId;
  final DateTime uploadedAt;

  bool get isMine => uploaderEmail.toLowerCase() == currentUserId.toLowerCase();

  String get summary {
    final parts = [type.label, 'PDF'];
    if (pageCount != null) {
      parts.add('$pageCount ${pageCount == 1 ? 'page' : 'pages'}');
    }
    return parts.join(' | ');
  }
}

String formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

const List<String> kSemesters = [
  'Fall 2026', 'Summer 2026', 'Winter 2026', 'Fall 2025', 'Winter 2025',
];

// ─────────────────────────────────────────────────────────────────────────────
// Courses Screen (Hub matching screenshot)
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
    Course(code: 'INFR 2820U', name: 'Algorithms & Data Structures', isJoined: true),
    Course(code: 'CSCI 3070U', name: 'Analysis & Design of Algorithms', isJoined: false),
  ];

  String _searchQuery = '';
  bool _showJoinedOnly = false;

  List<Course> get _filteredCourses {
    return _courses.where((c) {
      final matchesFilter = !_showJoinedOnly || c.isJoined;
      final matchesQuery = _searchQuery.isEmpty ||
          c.code.toLowerCase().contains(_searchQuery) ||
          c.name.toLowerCase().contains(_searchQuery);
      return matchesFilter && matchesQuery;
    }).toList();
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
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
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
                              Text(course.name, style: theme.textTheme.bodyMedium),
                              const SizedBox(height: 12),
                              if (course.isJoined)
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ResourcesScreen(
                                          courseCode: course.code,
                                          courseName: course.name,
                                          userEmail: currentUser?.email ?? '',
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Open course'),
                                )
                              else
                                TextButton(
                                  onPressed: () {
                                    setState(() => course.isJoined = true);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Joined ${course.code}')),
                                    );
                                  },
                                  child: const Text('Join course'),
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
  });

  final String courseCode;
  final String courseName;
  final String userEmail;

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  late final List<Resource> _resources;
  String _query = '';
  ResourceType? _typeFilter;

  @override
  void initState() {
    super.initState();
    _resources = [
      Resource(
        title: 'Dart study notes',
        type: ResourceType.notes,
        semester: 'Fall 2026',
        materialDate: DateTime(2026, 9, 15),
        pageCount: 4,
        uploaderEmail: 'sample.student@ontariotechu.net',
        currentUserId: widget.userEmail,
        description: 'Variables, null safety, lists and loops.',
      ),
      Resource(
        title: 'Practice questions – widgets',
        type: ResourceType.practice,
        semester: 'Fall 2026',
        materialDate: DateTime(2026, 10, 1),
        pageCount: 6,
        uploaderEmail: widget.userEmail, // Set to current user so it appears as yours
        currentUserId: widget.userEmail,
      ),
    ];
  }

  List<Resource> get _visibleResources {
    return _resources.where((r) {
      final matchesType = _typeFilter == null || r.type == _typeFilter;
      final matchesQuery = _query.isEmpty || r.title.toLowerCase().contains(_query);
      return matchesType && matchesQuery;
    }).toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  void _showSnackBar(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: action,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _openUploadForm() async {
    final newResource = await Navigator.of(context).push<Resource>(
      MaterialPageRoute(
        builder: (_) => UploadResourceScreen(
          courseCode: widget.courseCode,
          userEmail: widget.userEmail,
        ),
      ),
    );
    if (newResource == null || !mounted) return;

    setState(() => _resources.add(newResource));
    _showSnackBar('"${newResource.title}" uploaded');
  }

  Future<void> _confirmDelete(Resource resource) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete resource?'),
        content: Text('"${resource.title}" will be removed from ${widget.courseCode}.'),
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
        onPressed: () => setState(() => _resources.add(resource)),
      ),
    );
  }

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
            Text(resource.title, style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(resource.summary),
            if (resource.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(resource.description),
            ],
            const SizedBox(height: 12),
            _DetailRow(label: 'Semester', value: resource.semester),
            _DetailRow(label: 'Material date', value: formatDate(resource.materialDate)),
            _DetailRow(label: 'Uploaded by', value: resource.uploaderEmail),
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
      ),
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
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search resources',
              ),
              onChanged: (text) => setState(() => _query = text.trim().toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<ResourceType?>(
              initialValue: _typeFilter,
              decoration: const InputDecoration(
                labelText: 'Type',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All resources')),
                for (final type in ResourceType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) => setState(() => _typeFilter = value),
            ),
          ),
          Expanded(
            child: resources.isEmpty
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
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(resource.type.icon),
                          ),
                          title: Text(resource.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(resource.summary),
                          trailing: resource.isMine
                              ? const Chip(label: Text('Yours'))
                              : const Icon(Icons.chevron_right),
                          onTap: () => _showDetails(resource),
                          onLongPress: resource.isMine ? () => _confirmDelete(resource) : null,
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
            child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: color)),
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
  });

  final String courseCode;
  final String userEmail;

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
  bool _saving = false;

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
      _materialDate != null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _materialDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _materialDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields')),
      );
      return;
    }

    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final pagesText = _pagesController.text.trim();
    final resource = Resource(
      title: _titleController.text.trim(),
      type: _type,
      semester: _semester,
      materialDate: _materialDate!,
      pageCount: pagesText.isEmpty ? null : int.parse(pagesText),
      description: _descriptionController.text.trim(),
      uploaderEmail: widget.userEmail,
      currentUserId: widget.userEmail,
    );
    Navigator.of(context).pop(resource);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges && !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Upload resource')),
        body: Form(
          key: _formKey,
          onChanged: () => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Sharing to ${widget.courseCode}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                enabled: !_saving,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Dart study notes'),
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
                onChanged: _saving ? null : (v) => setState(() => _semester = v!),
              ),
              const SizedBox(height: 16),
              FormField<DateTime>(
                validator: (_) => _materialDate == null ? 'Choose a date' : null,
                builder: (field) => InkWell(
                  onTap: _saving
                      ? null
                      : () async {
                          await _pickDate();
                          field.didChange(_materialDate);
                        },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Material date',
                      suffixIcon: const Icon(Icons.calendar_today),
                      errorText: field.errorText,
                    ),
                    child: Text(_materialDate == null ? 'Tap to choose' : formatDate(_materialDate!)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pagesController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number of pages (optional)'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                enabled: !_saving,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
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