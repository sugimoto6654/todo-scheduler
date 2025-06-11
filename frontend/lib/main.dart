import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TodoApp());
}

class Todo {
  int id;
  String title;
  bool done;

  Todo({required this.id, required this.title, required this.done});

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as int,
      title: json['title'] as String,
      done: json['done'] as bool,
    );
  }
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  final TextEditingController _controller = TextEditingController();
  final String _apiBase = const String.fromEnvironment('API_BASE', defaultValue: '/api');
  List<Todo> _todos = [];

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  Future<void> _fetchTodos() async {
    final res = await http.get(Uri.parse('$_apiBase/todos'));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as List;
      setState(() {
        _todos = data.map((e) => Todo.fromJson(e)).toList();
      });
    }
  }

  Future<void> _addTodo(String title) async {
    final res = await http.post(
      Uri.parse('$_apiBase/todos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'title': title}),
    );
    if (res.statusCode == 201) {
      setState(() {
        _todos.add(Todo.fromJson(jsonDecode(res.body)));
      });
      _controller.clear();
    }
  }

  Future<void> _toggleDone(Todo todo) async {
    final res = await http.put(
      Uri.parse('$_apiBase/todos/${todo.id}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'done': !todo.done}),
    );
    if (res.statusCode == 200) {
      setState(() {
        todo.done = !todo.done;
      });
    }
  }

  Future<void> _deleteTodo(int id) async {
    final res = await http.delete(Uri.parse('$_apiBase/todos/$id'));
    if (res.statusCode == 204) {
      setState(() {
        _todos.removeWhere((t) => t.id == id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Todo App')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(hintText: 'Add todo'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        _addTodo(text);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchTodos,
                child: ListView(
                  children: _todos
                      .map((todo) => ListTile(
                            leading: Checkbox(
                              value: todo.done,
                              onChanged: (_) => _toggleDone(todo),
                            ),
                            title: Text(
                              todo.title,
                              style: todo.done
                                  ? const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                    )
                                  : null,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteTodo(todo.id),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
