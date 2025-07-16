import 'dart:convert';
import 'package:http/http.dart' as http;

class TodoService {
  final String apiUrl;

  TodoService({required this.apiUrl});

  Future<List<Map<String, dynamic>>> fetchTodos() async {
    final res = await http.get(Uri.parse('$apiUrl/todos'));
    if (res.statusCode != 200) return [];

    final List<dynamic> data = jsonDecode(res.body);
    final tmpTodos = data.cast<Map<String, dynamic>>();

    tmpTodos.sort((a, b) {
      final dateA = a['date'] != null ? DateTime.parse(a['date']) : null;
      final dateB = b['date'] != null ? DateTime.parse(b['date']) : null;
      
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      
      return dateA.compareTo(dateB);
    });

    return tmpTodos;
  }

  Map<DateTime, List<Map<String, dynamic>>> organizeEventsByDate(
    List<Map<String, dynamic>> todos,
  ) {
    final events = <DateTime, List<Map<String, dynamic>>>{};
    
    for (final todo in todos) {
      final day = todo['date'] != null
          ? DateTime.parse(todo['date']).toLocal()
          : DateTime.now();
      final key = _stripTime(day);
      events.putIfAbsent(key, () => []).add(todo);
    }
    
    return events;
  }

  Future<bool> addTodo(String title, DateTime date) async {
    try {
      final res = await http.post(
        Uri.parse('$apiUrl/todos'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'title': title,
          'date': date.toIso8601String(),
        }),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateTodoDone(int id, bool done) async {
    try {
      final res = await http.patch(
        Uri.parse('$apiUrl/todos/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'done': done}),
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteTodo(int id) async {
    try {
      final res = await http.delete(Uri.parse('$apiUrl/todos/$id'));
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  DateTime _stripTime(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);

  /// 指定された月のタスクを取得
  List<Map<String, dynamic>> getCurrentMonthTasks(
    List<Map<String, dynamic>> todos,
    DateTime focusedMonth,
  ) {
    final targetYear = focusedMonth.year;
    final targetMonth = focusedMonth.month;
    
    return todos.where((todo) {
      if (todo['date'] == null) return false;
      
      final taskDate = DateTime.parse(todo['date']);
      return taskDate.year == targetYear && taskDate.month == targetMonth;
    }).toList();
  }

  /// タスク情報をChatGPTプロンプト用にフォーマット
  String formatTasksForPrompt(List<Map<String, dynamic>> monthTasks, DateTime focusedMonth) {
    if (monthTasks.isEmpty) {
      return "${focusedMonth.year}年${focusedMonth.month}月には登録されているタスクがありません。";
    }

    final buffer = StringBuffer();
    buffer.writeln("【${focusedMonth.year}年${focusedMonth.month}月のタスク一覧】");
    buffer.writeln();

    // 日付でグループ化
    final tasksByDate = <String, List<Map<String, dynamic>>>{};
    for (final task in monthTasks) {
      final date = task['date'] as String;
      final dateKey = DateTime.parse(date);
      final dateStr = "${dateKey.month}月${dateKey.day}日";
      tasksByDate.putIfAbsent(dateStr, () => []).add(task);
    }

    // 日付順でソート
    final sortedDates = tasksByDate.keys.toList()
      ..sort((a, b) {
        final dateA = _parseJapaneseDate(a, focusedMonth.year);
        final dateB = _parseJapaneseDate(b, focusedMonth.year);
        return dateA.compareTo(dateB);
      });

    for (final dateStr in sortedDates) {
      buffer.writeln("■ $dateStr");
      final tasksForDate = tasksByDate[dateStr]!;
      
      for (final task in tasksForDate) {
        final id = task['id'];
        final title = task['title'];
        final done = task['done'] as bool;
        final status = done ? '完了' : '未完了';
        
        buffer.writeln("  - ID:$id \"$title\" ($status)");
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// 日本語の日付文字列をDateTimeに変換するヘルパー
  DateTime _parseJapaneseDate(String dateStr, int year) {
    final regex = RegExp(r'(\d+)月(\d+)日');
    final match = regex.firstMatch(dateStr);
    if (match != null) {
      final month = int.parse(match.group(1)!);
      final day = int.parse(match.group(2)!);
      return DateTime(year, month, day);
    }
    return DateTime.now();
  }
}