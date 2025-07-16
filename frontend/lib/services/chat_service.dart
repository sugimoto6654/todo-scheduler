import 'dart:convert';
import 'package:http/http.dart' as http;
import 'action_handler.dart';

class ChatService {
  final String apiUrl;
  late final ActionHandler _actionHandler;

  ChatService({required this.apiUrl}) {
    _actionHandler = ActionHandler(apiUrl: apiUrl);
  }

  Future<ChatResponse> sendMessage(
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
        
        // アクション実行結果を処理
        final actionResult = await _actionHandler.handleChatActions(data);
        
        return ChatResponse(
          reply: actionResult.fullMessage,
          actions: actionResult.actions,
          success: true,
        );
      } else {
        final errorData = jsonDecode(res.body);
        throw Exception('Backend error: ${errorData['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      return ChatResponse(
        reply: 'ChatGPT エラー: $e',
        actions: [],
        success: false,
        error: e.toString(),
      );
    }
  }
}

class ChatResponse {
  final String reply;
  final List<ExecutedAction> actions;
  final bool success;
  final String? error;

  ChatResponse({
    required this.reply,
    required this.actions,
    required this.success,
    this.error,
  });

  bool get hasActions => actions.isNotEmpty;
}