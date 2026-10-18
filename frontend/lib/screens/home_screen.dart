import 'package:flutter/material.dart';
import 'login_screen.dart' show AppColors;
import '../widgets/app_bottom_nav.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Home only shows the latest few; "View all" is for the full list.
  static const int _maxShown = 5;

  final _authService = AuthService();

  List<ConversationSummary> _conversations = [];
  bool _isLoading = true;
  String? _error;

  bool _isAdmin = false;
  int? _docCount; // null = unknown (not loaded yet, or the request failed)
  String _fullName = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadProfile();
  }

  // ---------- data ----------

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

  Future<void> _loadProfile() async {
    final role = await _authService.getCurrentRole();
    final name = await _authService.getCurrentName();
    if (!mounted) return;
    setState(() {
      _isAdmin = role == 'admin';
      _fullName = name;
    });
    if (_isAdmin) _loadDocCount();
  }

  Future<void> _loadDocCount() async {
    try {
      final docs = await ApiService.listDocuments();
      if (mounted) setState(() => _docCount = docs.length);
    } catch (_) {
      if (mounted) setState(() => _docCount = null);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadConversations(),
      if (_isAdmin) _loadDocCount(),
    ]);
  }

  // ---------- navigation ----------

  /// Wait for the pushed screen to close, then reload the list
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

  Future<void> _openAdminDocuments() async {
    await Navigator.of(context).pushNamed('/admin-documents');
    if (mounted) _loadDocCount(); // the admin may have added or deleted files
  }

  // ---------- helpers ----------

  String get _firstName =>
      _fullName.isEmpty ? '' : _fullName.split(RegExp(r'\s+')).first;

  String get _initials {
    final parts =
        _fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
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

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.skyBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
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
                      _buildStartChatCard(),
                      if (_isAdmin) ...[
                        const SizedBox(height: 14),
                        _buildAdminCard(),
                      ],
                      const SizedBox(height: 28),
                      _buildRecentConversationsHeader(),
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

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B82F6), AppColors.brandBlue],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.school, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 10),
            RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(text: 'Uni', style: TextStyle(color: AppColors.navy)),
                  TextSpan(
                      text: 'Assist',
                      style: TextStyle(color: AppColors.brandBlue)),
                ],
              ),
            ),
          ],
        ),
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.skyLight,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.skyBorder, width: 2),
          ),
          child: Text(
            _initials,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.brandBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeHeader() {
    final greeting = _firstName.isEmpty
        ? 'Welcome back! 👋'
        : 'Welcome back, $_firstName! 👋';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
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

  Widget _buildStartChatCard() {
    return GestureDetector(
      // No conversationId = brand-new conversation.
      onTap: () => _openChat(),
      child: Container(
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            // Decorative soft circle, top-right.
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.chat_bubble_outline,
                        color: AppColors.brandBlue, size: 26),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Start New Chat',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ask me about your courses, campus info, or tasks.',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.white.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tap to begin new prompt',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward,
                            color: AppColors.brandBlue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shown to admins only. A UI convenience: the real protection is the
  /// backend's @require_admin on every /admin route.
  Widget _buildAdminCard() {
    final subtitle = _docCount == null
        ? 'Upload and remove course files'
        : _docCount == 1
            ? '1 document indexed'
            : '$_docCount documents indexed';
    return GestureDetector(
      onTap: _openAdminDocuments,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.folder, color: AppColors.brandBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage Documents',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentConversationsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Recent Conversations',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.navy,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.of(context).pushNamed('/chat-history'),
          child: const Text(
            'View all',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.brandBlue,
            ),
          ),
        ),
      ],
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
              child: _buildConversationTile(c),
            ))
        .toList();
  }

  Widget _buildConversationTile(ConversationSummary c) {
    return GestureDetector(
      onTap: () => _openChat(conversationId: c.id, title: c.title),
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