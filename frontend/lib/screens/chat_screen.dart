import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../widgets/app_bottom_nav.dart';

class ChatScreen extends StatefulWidget {
  /// null = start a brand-new conversation. The backend creates the id
  /// when the first reply comes back.
  final String? conversationId;
  final String? conversationTitle;

  const ChatScreen({super.key, this.conversationId, this.conversationTitle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingHistory = false;
  String? _errorMessage;
  String? _conversationId; // null until the backend creates one

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    if (_conversationId != null) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final msgs = await ApiService.getMessages(_conversationId!);
      if (!mounted) return;
      setState(() => _messages.addAll(msgs));
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = "Couldn't load this conversation.");
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading || _isLoadingHistory) return;

    setState(() {
      _messages.add(ChatMessage(role: "user", content: text));
      _isLoading = true;
      _errorMessage = null;
    });
    _controller.clear();

    try {
      final result = await ApiService.sendMessage(
        text,
        conversationId: _conversationId,
      );
      if (!mounted) return;
      setState(() {
        _conversationId = result.conversationId; // remember for follow-ups
        _messages.add(ChatMessage(role: "assistant", content: result.reply));
        if (!result.saved) {
          _errorMessage = "This reply couldn't be saved to your history.";
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
        } catch (e) {
      debugPrint("sendMessage error: $e");
      if (mounted) {
        setState(() => _errorMessage =
            "Couldn't reach UniAssist. Check your connection and try again.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.conversationTitle ?? "UniAssist Chat")),
      bottomNavigationBar: const AppBottomNav(currentTab: AppTab.chat),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.red.shade100,
              padding: const EdgeInsets.all(8),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text("Ask UniAssist something to get started."))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isUser = msg.role == "user";
                          return Align(
                            alignment: isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isUser
                                    ? Colors.blue.shade400
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Text(
                                msg.content,
                                style: TextStyle(
                                    color: isUser
                                        ? Colors.white
                                        : Colors.black87),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Ask UniAssist something...",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}