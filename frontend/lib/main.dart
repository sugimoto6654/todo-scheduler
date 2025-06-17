import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const TodoApp());

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});
  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  final _api =
      const String.fromEnvironment('API', defaultValue: 'http://backend:5000');

  // ✅ 型を明示しておく
  List<Map<String, dynamic>> todos = [];

  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  Future<void> _fetchTodos() async {
    final res = await http.get(Uri.parse('$_api/todos'));

    // ✅ JSON から戻ってくる List<dynamic> を目的の型にキャスト
    final List<dynamic> data = jsonDecode(res.body);
    setState(() => todos = data.cast<Map<String, dynamic>>());
  }

  Future<void> _addTodo() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    await http.post(
      Uri.parse('$_api/todos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title}),
    );

    _controller.clear();
    _fetchTodos();
  }

  // ✅ 受け取る引数にも同じ Map<String, dynamic> 型を指定
  Widget _todoItem(Map<String, dynamic> todo) => ListTile(
        leading: Checkbox(
          value: todo['done'],
          onChanged: (v) async {
            await http.patch(
              Uri.parse('$_api/todos/${todo["id"]}'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'done': v}),
            );
            _fetchTodos();
          },
        ),
        title: Text(todo['title']),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async {
            await http.delete(Uri.parse('$_api/todos/${todo["id"]}'));
            _fetchTodos();
          },
        ),
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Todo')),
          body: Column(
            children: [
              Expanded(
                // ✅ map に型を指定：map<Widget>
                child: ListView(
                  children: todos.map<Widget>(_todoItem).toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration:
                            const InputDecoration(hintText: 'Add task'),
                        onSubmitted: (_) => _addTodo(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _addTodo,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
