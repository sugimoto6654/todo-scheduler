import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  final String apiUrl;

  ChatService({required this.apiUrl});

  Future<String?> sendMessage(
    List<Map<String, String>> messages, {
    String? currentMonthTasks,
  }) async {
    try {
      final requestBody = <String, dynamic>{
        'messages': messages,
      };
      
      // 現在月のタスク情報があれば追加
      if (currentMonthTasks != null && currentMonthTasks.isNotEmpty) {
        requestBody['current_month_tasks'] = currentMonthTasks;
      }
      
      final res = await http.post(
        Uri.parse('$apiUrl/chat'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(requestBody),
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