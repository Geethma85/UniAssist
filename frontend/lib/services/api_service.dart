import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ConversationSummary {
  final String id;
  final String title;
  final String lastMessagePreview;
  final DateTime? updatedAt;

  ConversationSummary({
    required this.id,
    required this.title,
    required this.lastMessagePreview,
    this.updatedAt,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        lastMessagePreview: (json['lastMessagePreview'] as String?) ?? '',
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String).toLocal(),
      );
}

class ChatReply {
  final String reply;
  final String conversationId;
  final bool saved;
  ChatReply({required this.reply, required this.conversationId, required this.saved});
}

class ApiService {
  // localhost works for Chrome. Android emulator: http://10.0.2.2:5000
  static const String baseUrl = 'http://localhost:5000';
  static const Duration _timeout = Duration(seconds: 25);

  static Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw ApiException('Not signed in');
    final idToken = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
  }

  static Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw ApiException(
          (decoded['error'] as String?) ?? 'Something went wrong. Please try again.');
    }
    return decoded;
  }

  static Future<ChatReply> sendMessage(String message, {String? conversationId}) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/chat'),
          headers: await _headers(),
          body: jsonEncode({
            'message': message,
            if (conversationId != null) 'conversation_id': conversationId,
          }),
        )
        .timeout(_timeout);
    final data = _decode(response);
    return ChatReply(
      reply: data['reply'] as String,
      conversationId: data['conversation_id'] as String,
      saved: (data['saved'] as bool?) ?? true,
    );
  }

  static Future<List<ConversationSummary>> listConversations() async {
    final response = await http
        .get(Uri.parse('$baseUrl/conversations'), headers: await _headers())
        .timeout(_timeout);
    final data = _decode(response);
    return (data['conversations'] as List)
        .map((c) => ConversationSummary.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  static Future<List<ChatMessage>> getMessages(String conversationId) async {
    final response = await http
        .get(Uri.parse('$baseUrl/conversations/$conversationId'),
            headers: await _headers())
        .timeout(_timeout);
    final data = _decode(response);
    return (data['messages'] as List)
        .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }
}