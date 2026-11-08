/// A single chat message in a course discussion (matches the proposal's
/// Message class: text, sender, timestamp).
class Message {
  Message({
    required this.id,
    required this.text,
    required this.senderEmail,
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();

  final String id;
  final String text;
  final String senderEmail;
  final DateTime sentAt;

  /// Friendly name shown above a message, e.g. "raqeeb" from raqeeb@mail.com.
  String get senderName => senderEmail.split('@').first;

  bool isFrom(String email) => senderEmail.toLowerCase() == email.toLowerCase();
}

String formatTime(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
}