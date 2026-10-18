import 'package:flutter/material.dart';
import 'login_screen.dart' show AppColors;
import '../widgets/app_bottom_nav.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // TODO: replace with real signed-in user's display name from AuthService
  static const String _userFirstName = 'Alex';

  // Home only shows the latest few; "View all" is for the full list.
  static const int _maxShown = 5;

  List<ConversationSummary> _conversations = [];
  bool _isLoading = true;
  String? _error;
    bool _isAdmin = false;
    final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadRole();  
  }

  Future<void> _loadConversations() async {
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
      debugPrint('listConversations error: $e');
      if (mounted) {
        setState(() => _error = "Couldn't load your conversations.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRole() async {
    final role = await _authService.getCurrentRole();
    if (mounted) setState(() => _isAdmin = role == 'admin');
  }

  /// Option A: wait for the pushed screen to close, then reload the list
  /// so new or updated conversations show up.
  Future<void> _openChat({String? conversationId, String? title}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          conversationTitle: title,
        ),
      ),
    );
    if (mounted) _loadConversations();
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadConversations,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(),
                      const SizedBox(height: 24),
                      _buildWelcomeHeader(),
                      const SizedBox(height: 20),
                      _buildStartChatCard(context),
                      if (_isAdmin) ...[
                        const SizedBox(height: 12),
                        _buildAdminCard(context),
                      ],
                      const SizedBox(height: 28),
                      _buildRecentConversationsHeader(context),
                      const SizedBox(height: 12),
                      ..._buildConversationsSection(),
                    ],
                  ),
                ),
              ),
            ),
            const AppBottomNav(currentTab: AppTab.home),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildConversationsSection() {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        Text(_error!, style: TextStyle(color: Colors.red.shade700)),
        const SizedBox(height: 8),
        TextButton(onPressed: _loadConversations, child: const Text('Retry')),
      ];
    }
    if (_conversations.isEmpty) {
      return [
        Text(
          'No conversations yet. Start a new chat above!',
          style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
        ),
      ];
    }
    return _conversations
        .take(_maxShown)
        .map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildConversationTile(context, c),
            ))
        .toList();
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(
              height: 28,
              width: 28,
              child: Image.asset(
                'assets/images/uniassist_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.school_outlined,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'UniAssist',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        // TODO: replace with real profile photo from Firebase user / Firestore
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.surfaceContainerLow,
          child: Icon(Icons.person, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome $_userFirstName!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'How can I assist you with your studies today?',
          style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildStartChatCard(BuildContext context) {
    return GestureDetector(
      // No conversationId = brand-new conversation.
      onTap: () => _openChat(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.chat_bubble, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              'Start New Chat',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me about your courses, campus info, or tasks.',
              style: TextStyle(fontSize: 15, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Icon(Icons.arrow_forward, color: AppColors.onSurface),
          ],
        ),
      ),
    );
  }

    Widget _buildAdminCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/admin-documents'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_open, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Manage documents',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            Icon(Icons.arrow_forward, color: AppColors.onSurface),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentConversationsHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Conversations',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/chat-history'),
          child: Text(
            'View all',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversationTile(BuildContext context, ConversationSummary c) {
    return GestureDetector(
      onTap: () => _openChat(conversationId: c.id, title: c.title),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history, size: 20, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title.isEmpty ? 'Untitled chat' : c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimestamp(c.updatedAt),
                    style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}