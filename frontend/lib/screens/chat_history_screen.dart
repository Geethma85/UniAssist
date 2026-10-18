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
    return GestureDetector(
      onTap: () => _openChat(c),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.skyBorder.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.skyLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  size: 22, color: AppColors.brandBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.title.isEmpty ? 'Untitled chat' : c.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(c.updatedAt),
                        style: TextStyle(
                            fontSize: 12, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  if (c.lastMessagePreview.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      c.lastMessagePreview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}