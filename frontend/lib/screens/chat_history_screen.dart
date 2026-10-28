import 'package:flutter/material.dart';
import 'login_screen.dart' show AppColors;
import '../widgets/app_bottom_nav.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  List<ConversationSummary> _conversations = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _deletingIds = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await ApiService.listConversations();
      if (!mounted) return;
      setState(() => _conversations = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      debugPrint('chat history error: $e');
      if (mounted) setState(() => _error = "Couldn't load your conversations.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openChat(ConversationSummary c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: c.id,
          conversationTitle: c.title,
        ),
      ),
    );
    if (mounted) _load();
  }

    Future<void> _deleteChat(ConversationSummary conversation) async {
    if (_deletingIds.contains(conversation.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text(
          'This permanently removes the conversation and its messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (_deletingIds.contains(conversation.id)) return;

    setState(() => _deletingIds.add(conversation.id));

    try {
      await ApiService.deleteConversation(conversation.id);
      if (!mounted) return;

      setState(() {
        _conversations.removeWhere((item) => item.id == conversation.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation deleted.')),
      );
    } catch (error) {
      if (!mounted) return;

      final message = error is ApiException
          ? error.message
          : 'Could not confirm deletion. Refresh history before trying again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingIds.remove(conversation.id));
      }
    }
  }

  String _formatTimestamp(DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.skyBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Chat History',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All your conversations with UniAssist.',
                      style: TextStyle(
                          fontSize: 15, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    ..._buildContent(),
                  ],
                ),
              ),
            ),
            const AppBottomNav(currentTab: AppTab.history),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        Text(_error!, style: TextStyle(color: Colors.red.shade700)),
        const SizedBox(height: 8),
        TextButton(onPressed: _load, child: const Text('Retry')),
      ];
    }
    if (_conversations.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Text(
            'No conversations yet. Start a chat from the Home tab!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: AppColors.onSurfaceVariant),
          ),
        ),
      ];
    }
    return _conversations
        .map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTile(c),
            ))
        .toList();
  }

  Widget _buildTile(ConversationSummary c) {
    final deleting = _deletingIds.contains(c.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.skyBorder.withValues(alpha: 0.7),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        onTap: deleting ? null : () => _openChat(c),
        leading: const Icon(
          Icons.chat_bubble_outline,
          color: AppColors.brandBlue,
        ),
        title: Text(
          c.title.isEmpty ? 'Untitled chat' : c.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        subtitle: Text(
          [
            if (c.lastMessagePreview.isNotEmpty) c.lastMessagePreview,
            _formatTimestamp(c.updatedAt),
          ].where((text) => text.isNotEmpty).join('\n'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: deleting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : IconButton(
                tooltip: 'Delete conversation',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteChat(c),
              ),
      ),
    );
  }
}