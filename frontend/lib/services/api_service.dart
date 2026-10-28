import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import 'dart:typed_data';

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

class AdminDocument {
  final String id;
  final String filename;
  final int chunkCount;
  final DateTime? uploadDate;

  AdminDocument({
    required this.id,
    required this.filename,
    required this.chunkCount,
    this.uploadDate,
  });

  factory AdminDocument.fromJson(Map<String, dynamic> json) => AdminDocument(
        id: json['document_id'] as String,
        filename: (json['filename'] as String?) ?? 'unknown',
        chunkCount: (json['chunk_count'] as int?) ?? 0,
        uploadDate: (json['upload_date'] as String?) == null
            ? null
            : DateTime.tryParse(json['upload_date'] as String)?.toLocal(),
      );
}

class ApiService {
  // Set at run time: flutter run --dart-define=API_BASE_URL=http://<pc-ip>:5000
  // Defaults to localhost, which works for Chrome. Android emulator: http://10.0.2.2:5000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );
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
    if (response.statusCode != 200 && response.statusCode != 201) {
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

    static Future<void> deleteConversation(String conversationId) async {
    final response = await http
        .delete(
          Uri.parse(
            '$baseUrl/conversations/${Uri.encodeComponent(conversationId)}',
          ),
          headers: await _headers(),
        )
        .timeout(const Duration(seconds: 90));

    // Successful deletion returns 204 with no JSON body.
    if (response.statusCode == 204) return;

    _decode(response);
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

    // Token only: for multipart uploads, http sets Content-Type itself.
  static Future<Map<String, String>> _authHeader() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw ApiException('Not signed in');
    final idToken = await user.getIdToken();
    return {'Authorization': 'Bearer $idToken'};
  }

  static Future<List<AdminDocument>> listDocuments() async {
    final response = await http
        .get(Uri.parse('$baseUrl/admin/documents'), headers: await _headers())
        .timeout(_timeout);
    final data = _decode(response);
    return (data['documents'] as List)
        .map((d) => AdminDocument.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  static Future<void> uploadDocument({
    required String filename,
    required Uint8List bytes,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/admin/documents/upload'),
    )
      ..headers.addAll(await _authHeader())
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    // Longer timeout: the server embeds every chunk before replying.
    final streamed = await request.send().timeout(const Duration(seconds: 90));
    final response = await http.Response.fromStream(streamed);
    _decode(response);
  }

  static Future<void> deleteDocument(String documentId) async {
    final response = await http
        .delete(Uri.parse('$baseUrl/admin/documents/$documentId'),
            headers: await _headers())
        .timeout(_timeout);
    _decode(response);
  }
}