import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Simple in-memory chat message. Not persisted anywhere yet — that's a
/// later session. If the app restarts, this history is gone.
class ChatMessage {
  final String role; // "user" or "assistant"
  final String content;
  ChatMessage({required this.role, required this.content});

  Map<String, String> toJson() => {"role": role, "content": content};
}

class ChatScreen extends StatefulWidget {
  final String? conversationTitle;
  final List<ChatMessage>? initialMessages;

  const ChatScreen({super.key, this.conversationTitle, this.initialMessages});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Seed with any prior messages passed in (empty for now, since chat
    // history persistence isn't built yet — this is just here so an
    // already-existing conversation could be reopened later without
    // another change to this file).
    if (widget.initialMessages != null) {
      _messages.addAll(widget.initialMessages!);
    }
  }

  // TODO: point this at your real backend once deployed.
  // localhost works when testing on Chrome (flutter run -d chrome).
  // If you switch to testing on an Android emulator, change this to
  // http://10.0.2.2:5000/chat instead (10.0.2.2 is the emulator's alias
  // for your host machine). For a physical device on the same WiFi, use
  // your computer's LAN IP instead, e.g. http://192.168.1.X:5000/chat.
  static const String _backendUrl = "http://localhost:5000/chat";

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(role: "user", content: text));
      _isLoading = true;
      _errorMessage = null;
    });
    _controller.clear();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Not signed in");
      }
      final idToken = await user.getIdToken();

      // Everything except the message we just added is "history" — the
      // backend expects the current message separately from prior turns.
      final history = _messages
          .sublist(0, _messages.length - 1)
          .map((m) => m.toJson())
          .toList();

      final response = await http
          .post(
            Uri.parse(_backendUrl),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $idToken",
            },
            body: jsonEncode({"message": text, "history": history}),
          )
          .timeout(const Duration(seconds: 25));

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        setState(() {
          _messages.add(ChatMessage(role: "assistant", content: decoded["reply"] as String));
        });
      } else {
        setState(() {
          _errorMessage = (decoded["error"] as String?) ?? "Something went wrong. Please try again.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Couldn't reach UniAssist. Check your connection and try again.";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            child: _messages.isEmpty
                ? const Center(child: Text("Ask UniAssist something to get started."))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg.role == "user";
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.blue.shade400 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Text(
                            msg.content,
                            style: TextStyle(color: isUser ? Colors.white : Colors.black87),
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