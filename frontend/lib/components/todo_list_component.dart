import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TodoListComponent extends StatelessWidget {
  final List<Map<String, dynamic>> todos;
  final String apiUrl;
  final VoidCallback onTodoUpdate;

  const TodoListComponent({
    super.key,
    required this.todos,
    required this.apiUrl,
    required this.onTodoUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'タスク一覧',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: todos.map<Widget>(_todoItem).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _todoItem(Map<String, dynamic> todo) {
    final DateTime? dueDate =
        todo['date'] != null ? DateTime.parse(todo['date']).toLocal() : null;

    String? dueDateText;
    Color? dueDateColor;

    if (dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final taskDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final difference = taskDate.difference(today).inDays;

      if (difference < 0) {
        dueDateText = '期限切れ (${dueDate.month}/${dueDate.day})';
        dueDateColor = Colors.red.shade700;
      } else if (difference == 0) {
        dueDateText = '今日まで';
        dueDateColor = Colors.orange.shade800;
      } else if (difference == 1) {
        dueDateText = '明日まで';
        dueDateColor = Colors.orange.shade600;
      } else {
        dueDateText = '${dueDate.month}/${dueDate.day}まで';
        dueDateColor = Colors.blue.shade700;
      }
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: todo['done'] ? Colors.grey.shade200 : Colors.white,
      child: ListTile(
        leading: Checkbox(
          value: todo['done'],
          onChanged: (v) => _updateTodo(todo['id'], v),
          activeColor: Colors.green,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              todo['title'],
              style: TextStyle(
                decoration: todo['done'] ? TextDecoration.lineThrough : null,
                color: todo['done'] ? Colors.grey.shade600 : Colors.black87,
                fontSize: 15,
              ),
            ),
            if (dueDateText != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: dueDateColor),
                    const SizedBox(width: 4),
                    Text(
                      dueDateText,
                      style: TextStyle(fontSize: 12, color: dueDateColor),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
          onPressed: () => _deleteTodo(todo['id']),
        ),
      ),
    );
  }

  Future<void> _updateTodo(int id, bool? done) async {
    await http.patch(
      Uri.parse('$apiUrl/todos/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'done': done}),
    );
    onTodoUpdate();
  }

  Future<void> _deleteTodo(int id) async {
    await http.delete(Uri.parse('$apiUrl/todos/$id'));
    onTodoUpdate();
  }
}