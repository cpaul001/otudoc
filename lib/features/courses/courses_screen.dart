import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
// Resources page (with local storage) lives in its own file now.
import '../resources/resources_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

/// A course students can join; joined courses open their Resources page.
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
