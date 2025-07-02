import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  final String apiUrl;

  ChatService({required this.apiUrl});

  Future<String?> sendMessage(List<Map<String, String>> messages) async {
    try {
      final res = await http.post(
        Uri.parse('$apiUrl/chat'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'messages': messages}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['reply'] as String;
      } else {
        final errorData = jsonDecode(res.body);
        throw Exception('Backend error: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      throw Exception('ChatGPT エラー: $e');
    }
  }
}