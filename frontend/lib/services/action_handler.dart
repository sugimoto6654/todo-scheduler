import 'dart:convert';
import 'package:http/http.dart' as http;

class ActionHandler {
  final String apiUrl;

  ActionHandler({required this.apiUrl});

  /// ChatGPTのアクション実行結果を処理
  Future<ActionResult> handleChatActions(Map<String, dynamic> chatResponse) async {
    final actionsExecuted = chatResponse['actions_executed'] as List<dynamic>?;
    
    if (actionsExecuted == null || actionsExecuted.isEmpty) {
      return ActionResult(
        success: true,
        message: chatResponse['reply'] ?? '',
        actions: [],
      );
    }

    final List<ExecutedAction> actions = [];
    
    for (final actionData in actionsExecuted) {
      final action = ExecutedAction.fromJson(actionData);
      actions.add(action);
    }

    return ActionResult(
      success: true,
      message: chatResponse['reply'] ?? '',
      actions: actions,
    );
  }

  /// タスクの一括作成
  Future<bool> createTasks(List<Map<String, dynamic>> tasks) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/todos/bulk'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'todos': tasks}),
      );

      return response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// タスクの一括更新
  Future<bool> updateTasks(List<Map<String, dynamic>> updates) async {
    try {
      final response = await http.patch(
        Uri.parse('$apiUrl/todos/bulk'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'updates': updates}),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// アクション実行結果の表示用テキストを生成
  String getActionSummary(List<ExecutedAction> actions) {
    if (actions.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('\n📋 実行されたアクション:');

    for (final action in actions) {
      switch (action.type) {
        case 'split_task':
          buffer.writeln('• タスク分割: ${action.message}');
          break;
        case 'adjust_deadline':
          buffer.writeln('• 期限調整: ${action.message}');
          break;
        case 'create_tasks':
          buffer.writeln('• ✅ タスク作成: ${action.message}');
          if (action.success) {
            final createdTasks = action.getCreatedTasks();
            if (createdTasks != null && createdTasks.isNotEmpty) {
              buffer.writeln('  追加されたタスク:');
              for (final task in createdTasks) {
                final date = task['date'] != null ? ' (${task['date']})' : '';
                buffer.writeln('  - ${task['title']}$date');
              }
            }
          }
          break;
        case 'update_tasks':
          buffer.writeln('• タスク更新: ${action.message}');
          break;
        default:
          buffer.writeln('• ${action.message}');
      }
    }

    return buffer.toString();
  }
}

class ActionResult {
  final bool success;
  final String message;
  final List<ExecutedAction> actions;
  final String? error;

  ActionResult({
    required this.success,
    required this.message,
    required this.actions,
    this.error,
  });

  bool get hasActions => actions.isNotEmpty;

  String get fullMessage {
    if (!hasActions) return message;
    
    final actionHandler = ActionHandler(apiUrl: '');
    final actionSummary = actionHandler.getActionSummary(actions);
    return '$message$actionSummary';
  }
}

class ExecutedAction {
  final String type;
  final bool success;
  final String message;
  final Map<String, dynamic> data;

  ExecutedAction({
    required this.type,
    required this.success,
    required this.message,
    required this.data,
  });

  factory ExecutedAction.fromJson(Map<String, dynamic> json) {
    return ExecutedAction(
      type: json['type'] ?? '',
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json,
    );
  }

  /// 分割されたタスクの情報を取得
  List<Map<String, dynamic>>? get createdTasks {
    if (type == 'split_task') {
      return (data['created_tasks'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>();
    }
    return null;
  }

  /// 作成されたタスクの情報を取得
  List<Map<String, dynamic>>? getCreatedTasks() {
    if (type == 'create_tasks') {
      return (data['created_tasks'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>();
    }
    return null;
  }

  /// 更新されたタスクの情報を取得
  List<Map<String, dynamic>>? get updatedTasks {
    if (type == 'adjust_deadline') {
      return (data['updated_tasks'] as List<dynamic>?)
          ?.cast<Map<String, dynamic>>();
    }
    return null;
  }

  /// 元のタスクID（分割の場合）
  int? get originalTaskId {
    if (type == 'split_task') {
      return data['original_task_id'];
    }
    return null;
  }
}