import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  runApp(const TodoApp());
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});
  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  // --- Backend API ---------------------------------------------------------
  final _api =
      const String.fromEnvironment('API', defaultValue: 'http://backend:5000');

  // --- OpenAI --------------------------------------------------------------
  final _openaiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
  final _openaiModel = dotenv.env['OPENAI_MODEL'] ?? 'gpt-3.5-turbo';

  // --- Todo & Calendar -----------------------------------------------------
  List<Map<String, dynamic>> todos = [];
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // --- ChatGPT messages ----------------------------------------------------
  final List<Map<String, String>> _chatMessages = [];

  // --- Controllers ---------------------------------------------------------
  final TextEditingController _controller = TextEditingController();
  final ScrollController _chatScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  // Helper to remove the time part
  DateTime _stripTime(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);

  // -------------------------------------------------------------------------
  // Todo section
  // -------------------------------------------------------------------------
  Future<void> _fetchTodos() async {
    final res = await http.get(Uri.parse('$_api/todos'));
    if (res.statusCode != 200) return;

    final List<dynamic> data = jsonDecode(res.body);
    final tmpTodos = data.cast<Map<String, dynamic>>();
    final tmpEvents = <DateTime, List<Map<String, dynamic>>>{};

    for (final t in tmpTodos) {
      final day = t['date'] != null
          ? DateTime.parse(t['date']).toLocal()
          : DateTime.now();
      final key = _stripTime(day);
      tmpEvents.putIfAbsent(key, () => []).add(t);
    }

    setState(() {
      todos = tmpTodos;
      _events = tmpEvents;
    });
  }

  Future<void> _addTodoOrChat() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    _controller.clear();           // 先にクリアしておく

    // Chat モード ----------------------------------------------
    if (raw.startsWith('/chat ')) {
      await _sendChat(raw.substring(6).trim());
      return;
    }

    // Todo モード ----------------------------------------------
    final date = _selectedDay ?? DateTime.now();
    try {
      final res = await http.post(
        Uri.parse('$_api/todos'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'title': raw,
          // ↓もし API が 'YYYY-MM-DD' 形式を期待するなら:
          // 'date': DateFormat('yyyy-MM-dd').format(date),
          'date': date.toIso8601String(),
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchTodos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Todo 追加失敗: ${res.statusCode}\\n${res.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ネットワークエラー: $e')));
    }
  }

  Future<void> _sendChat(String prompt) async {
    if (_openaiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OPENAI_API_KEY が未設定です')),
      );
      return;
    }

    setState(() {
      _chatMessages.add({'role': 'user', 'content': prompt});
    });

    try {
      final res = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openaiKey',
        },
        body: jsonEncode({
          'model': _openaiModel,
          'messages': _chatMessages,
          'temperature': 0.7,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply = data['choices'][0]['message']['content'] as String;
        setState(() {
          _chatMessages.add({'role': 'assistant', 'content': reply.trim()});
        });
      } else {
        throw Exception('OpenAI error ${res.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ChatGPT エラー: $e')),
      );
    } finally {
      // 自動スクロール
      await Future.delayed(const Duration(milliseconds: 50));
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  // -------------------------------------------------------------------------
  // UI widgets
  // -------------------------------------------------------------------------
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

  Widget _chatBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue.shade200 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(msg['content'] ?? ''),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        locale: const Locale('ja', 'JP'),
        supportedLocales: const [
          Locale('en', 'US'),
          Locale('ja', 'JP'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          appBar: AppBar(title: const Text('Todo Scheduler')),
          body: Column(
            children: [
              // --- Todo & Calendar ----------------------------------------
              Expanded(
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          // Todo list
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.all(8),
                              children: todos.map<Widget>(_todoItem).toList(),
                            ),
                          ),
                          // --- ChatGPT area -----------------------------------------
                          Container(
                            height: 240,
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: Colors.grey.shade300)),
                            ),
                            child: _chatMessages.isEmpty
                                ? const Center(child: Text('ここに ChatGPT と対話が表示されます'))
                                : ListView.builder(
                                    controller: _chatScroll,
                                    itemCount: _chatMessages.length,
                                    itemBuilder: (context, idx) => _chatBubble(_chatMessages[idx]),
                                  ),
                          ),
                        ]
                      )
                    ),
                    const SizedBox(width: 24),
                    // Calendar
                    Expanded(
                      flex: 1,
                      child: Card(
                        elevation: 3,
                        margin: EdgeInsets.zero,
                        child: TableCalendar(
                          locale: 'ja_JP',
                          firstDay: DateTime.utc(2020),
                          lastDay: DateTime.utc(2030),
                          focusedDay: _focusedDay,
                          rowHeight: 130,
                          selectedDayPredicate: (day) => _selectedDay != null &&
                              _stripTime(day) == _stripTime(_selectedDay!),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          startingDayOfWeek: StartingDayOfWeek.sunday,
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: (context, day, focusedDay) {
                              final key = _stripTime(day);
                              final tasks = _events[key] ?? [];
                              return Padding(
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Align(
                                      alignment: Alignment.topRight,
                                      child: Text('${day.day}',
                                          style: const TextStyle(fontSize: 12)),
                                    ),
                                    const SizedBox(height: 2),
                                    ...tasks.take(6).map(
                                      (t) => Text('• ${t["title"]}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                              );
                            },
                            todayBuilder: (context, day, focusedDay) {
                              final key = _stripTime(day);
                              final tasks = _events[key] ?? [];
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blueAccent),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Align(
                                      alignment: Alignment.topRight,
                                      child: Text('${day.day}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12)),
                                    ),
                                    const SizedBox(height: 2),
                                    ...tasks.take(6).map(
                                      (t) => Text('• ${t["title"]}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                  ],
                ),
              ),

              // --- Input row (Todo & Chat) ------------------------------
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Add task or type /chat message',
                        ),
                        onSubmitted: (_) => _addTodoOrChat(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _addTodoOrChat,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}