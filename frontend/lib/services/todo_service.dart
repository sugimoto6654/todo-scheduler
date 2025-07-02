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
}