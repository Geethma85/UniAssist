import 'package:flutter/material.dart';
import '../screens/login_screen.dart' show AppColors;

class ConversationSummary {
  final String id;
  final String title;
  final String timestamp;

  const ConversationSummary({
    required this.id,
    required this.title,
    required this.timestamp,
  });
}

/// Slide-out drawer listing past conversations, Claude/ChatGPT-style.
/// Each title is meant to be AI-generated server-side from the first
/// exchange in that conversation (a small extra Claude API call on the
/// backend when a conversation is created) — not something Flutter
/// generates itself. For now this uses placeholder data.
class ChatHistoryDrawer extends StatelessWidget {
  final void Function(ConversationSummary conversation) onSelectConversation;
  final VoidCallback onNewChat;

  const ChatHistoryDrawer({
    super.key,
    required this.onSelectConversation,
    required this.onNewChat,
  });

  // TODO: replace with real conversations fetched from Firestore for the
  // signed-in user, ordered by most recent activity.
  static const List<ConversationSummary> _conversations = [
    ConversationSummary(id: '1', title: 'Course Registration Help', timestamp: 'Today'),
    ConversationSummary(id: '2', title: 'Campus Library Hours', timestamp: 'Yesterday'),
    ConversationSummary(id: '3', title: 'Exam Timetable Questions', timestamp: '3 days ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surfaceContainerLowest,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.school_outlined, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'UniAssist',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(); // close drawer
                  onNewChat();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'RECENT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    title: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: AppColors.onSurface),
                    ),
                    subtitle: Text(
                      conversation.timestamp,
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                    onTap: () {
                      Navigator.of(context).pop(); // close drawer
                      onSelectConversation(conversation);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}