import 'package:flutter/foundation.dart';

import 'message.dart';

/// Holds course chat messages. Screens only talk to this class, so replacing
/// the in-memory list with Cloud Firestore later only changes this file.
class MessageRepository extends ChangeNotifier {
  MessageRepository._();
  static final MessageRepository instance = MessageRepository._();

  final Map<String, List<Message>> _byCourse = {};
  final Set<String> _reportedIds = {};
  int _nextId = 0;

  List<Message> messagesFor(String courseCode) {
    final list = _byCourse.putIfAbsent(courseCode, () => _seed(courseCode));
    return List.unmodifiable(list);
  }

  bool isReported(String messageId) => _reportedIds.contains(messageId);

  void send(String courseCode, String text, String senderEmail) {
    final list = _byCourse.putIfAbsent(courseCode, () => _seed(courseCode));
    list.add(Message(
      id: 'm${_nextId++}',
      text: text,
      senderEmail: senderEmail,
    ));
    notifyListeners();
  }

  void delete(String courseCode, String messageId) {
    _byCourse[courseCode]?.removeWhere((m) => m.id == messageId);
    notifyListeners();
  }

  void report(String messageId) {
    _reportedIds.add(messageId);
    notifyListeners();
  }

  // Sample conversation so the screen is not empty in the demo.
  List<Message> _seed(String courseCode) {
    if (courseCode != 'CSCI 3101U') return [];
    final now = DateTime.now();
    return [
      Message(
        id: 'm${_nextId++}',
        text: 'Can someone explain nullable variables?',
        senderEmail: 'student1@ontariotechu.net',
        sentAt: now.subtract(const Duration(minutes: 40)),
      ),
      Message(
        id: 'm${_nextId++}',
        text: 'The study notes have an example on page 2.',
        senderEmail: 'sample.student@ontariotechu.net',
        sentAt: now.subtract(const Duration(minutes: 35)),
      ),
    ];
  }
}