import 'package:flutter/material.dart';

import 'message.dart';
import 'message_repository.dart';

/// The "Discussion" tab of the course hub: a shared course chat.
class DiscussionView extends StatefulWidget {
  const DiscussionView({
    super.key,
    required this.courseCode,
    required this.userEmail,
  });

  final String courseCode;
  final String userEmail;

  @override
  State<DiscussionView> createState() => _DiscussionViewState();
}

class _DiscussionViewState extends State<DiscussionView> {
  final _repo = MessageRepository.instance;
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _repo.send(widget.courseCode, text, widget.userEmail);
    _controller.clear();
    // Wait for the new bubble to be laid out, then jump to the bottom.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showActions(Message message) {
    final mine = message.isFrom(widget.userEmail);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete message'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDelete(message);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report message'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmReport(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This removes your message from the course chat.'),
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
    _repo.delete(widget.courseCode, message.id);
    _snack('Message deleted');
  }

  Future<void> _confirmReport(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report message?'),
        content: const Text(
          'Report this message as inappropriate or as sharing material '
          'that should not be distributed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _repo.report(message.id);
    _snack('Message reported. Thanks for helping keep the chat safe.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text('Shared course chat', style: theme.textTheme.bodySmall),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _repo,
            builder: (context, _) {
              final messages = _repo.messagesFor(widget.courseCode);
              if (messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No messages yet.\nStart the conversation!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                );
              }
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[i];
                  return _MessageBubble(
                    message: m,
                    isMine: m.isFrom(widget.userEmail),
                    reported: _repo.isReported(m.id),
                    onLongPress: () => _showActions(m),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Write a message',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Disabled while the box is empty, so blank messages can't be sent.
                ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed:
                        _controller.text.trim().isEmpty ? null : _send,
                    child: const Text('Send'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.reported,
    required this.onLongPress,
  });

  final Message message;
  final bool isMine;
  final bool reported;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = isMine ? 'You' : message.senderName;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: isMine
                ? scheme.primary.withValues(alpha: 0.12)
                : scheme.surface,
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: name, style: theme.textTheme.labelMedium),
                TextSpan(
                  text: '  ${formatTime(message.sentAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ])),
              const SizedBox(height: 4),
              Text(message.text, style: theme.textTheme.bodyLarge),
              if (reported)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Reported', style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ),
    );
  }
}