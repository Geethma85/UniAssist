import 'package:flutter/material.dart';
import 'login_screen.dart' show AppColors;
import '../widgets/chat_history_drawer.dart';

enum MessageSender { user, assistant }

class ChatMessage {
  final MessageSender sender;
  final String text;
  final String? sourceCitation;

  ChatMessage({required this.sender, required this.text, this.sourceCitation});
}

class ChatScreen extends StatefulWidget {
  /// Pass these when opening an existing conversation (e.g. from the
  /// drawer or Home's "Recent Conversations" list). Leave both null to
  /// open a fresh, blank chat — the default entry point from the
  /// bottom nav's Chat tab and Home's "Start New Chat" card.
  final String? conversationTitle;
  final List<ChatMessage>? initialMessages;

  const ChatScreen({
    super.key,
    this.conversationTitle,
    this.initialMessages,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late List<ChatMessage> _messages;
  late String? _conversationTitle;
  bool _isAssistantTyping = false;

  bool get _isBlankState => _messages.isEmpty;

  @override
  void initState() {
    super.initState();
    _messages = widget.initialMessages ?? [];
    _conversationTitle = widget.conversationTitle;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(sender: MessageSender.user, text: text));
      _isAssistantTyping = true;
    });
    _messageController.clear();
    _scrollToBottom();

    // TODO: replace this simulated delay + canned reply with a real call
    // to the Flask backend, e.g.:
    //   final reply = await ChatService().sendMessage(
    //     conversationId: _conversationId, // null on first send -> backend creates one
    //     message: text,
    //   );
    // The backend should also generate a short topic title from the first
    // exchange and return it, so we can set _conversationTitle here.
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _isAssistantTyping = false;
      _conversationTitle ??= _deriveFallbackTitle(text);
      _messages.add(
        ChatMessage(
          sender: MessageSender.assistant,
          text: "This is a placeholder response — not yet connected to "
              "the real backend.",
        ),
      );
    });
    _scrollToBottom();
  }

  // TODO: temporary client-side stand-in. Real title generation should
  // happen server-side via a small Claude API call once the backend exists.
  String _deriveFallbackTitle(String firstMessage) {
    final trimmed = firstMessage.trim();
    return trimmed.length <= 40 ? trimmed : '${trimmed.substring(0, 40)}...';
  }

  void _startNewChat() {
    setState(() {
      _messages = [];
      _conversationTitle = null;
      _isAssistantTyping = false;
    });
    _messageController.clear();
  }

  void _openConversation(ConversationSummary conversation) {
    // TODO: replace with a real fetch of this conversation's messages
    // from Firestore, keyed by conversation.id.
    setState(() {
      _conversationTitle = conversation.title;
      _messages = [
        ChatMessage(
          sender: MessageSender.assistant,
          text: 'This is a placeholder reload of "${conversation.title}" — '
              'not yet wired to real stored messages.',
        ),
      ];
      _isAssistantTyping = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: ChatHistoryDrawer(
        onSelectConversation: _openConversation,
        onNewChat: _startNewChat,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _isBlankState ? _buildWelcomeState() : _buildConversation(),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: AppColors.onSurface),
              tooltip: 'Chat history',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          Expanded(
            child: Text(
              _conversationTitle ?? 'UniAssist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_square, color: AppColors.primary),
            tooltip: 'New chat',
            onPressed: _startNewChat,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 20),
            Text(
              // TODO: personalize with the signed-in user's first name
              'Hi, welcome back!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me about your courses, campus info, or tasks.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversation() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        ..._messages.map(_buildMessageBubble),
        if (_isAssistantTyping) _buildTypingIndicator(),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.sender == MessageSender.user;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUser ? AppColors.primary : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message.text,
        style: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: isUser ? AppColors.onPrimary : AppColors.onSurface,
        ),
      ),
    );

    final row = Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: isUser
          ? [Flexible(child: bubble)]
          : [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surfaceContainerLow,
                child: Icon(Icons.school_outlined, size: 14, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Flexible(child: bubble),
            ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          row,
          if (message.sourceCitation != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 36),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined, size: 14, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Source: ${message.sourceCitation}',
                    style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.surfaceContainerLow,
            child: Icon(Icons.smart_toy_outlined, size: 14, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'UniAssist is thinking',
                  style: TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.add, color: AppColors.onSurfaceVariant),
                  onPressed: () {
                    // TODO: attach file / context (e.g. document upload for RAG)
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Ask UniAssist...',
                      hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _handleSend,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'AI responses may be inaccurate. Please verify important academic dates.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}