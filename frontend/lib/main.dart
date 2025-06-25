import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
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
  final FocusNode _textFieldFocus = FocusNode();

  // --- Date Picker ---------------------------------------------------------
  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    _fetchTodos();
  }

  @override
  void dispose() {
    _textFieldFocus.dispose();
    super.dispose();
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

    // 日付に基づいてタスクを並び替え
    tmpTodos.sort((a, b) {
      final dateA = a['date'] != null ? DateTime.parse(a['date']) : null;
      final dateB = b['date'] != null ? DateTime.parse(b['date']) : null;
      
      // 日付がないタスクは最後に表示
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      
      // 日付で昇順ソート（早い日付が上に）
      return dateA.compareTo(dateB);
    });

    setState(() {
      todos = tmpTodos;
      _events = tmpEvents;
    });
  }

  // -------------------------------------------------------------------------
  // Date picker methods
  // -------------------------------------------------------------------------
  Future<void> _selectDueDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
      });
    }
  }

  void _clearDueDate() {
    setState(() {
      _selectedDueDate = null;
    });
  }

  Future<void> _addTodoOrChat() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    _controller.clear();           // 先にクリアしておく
    _textFieldFocus.requestFocus(); // テキストフィールドにフォーカスを戻す

    // Chat モード ----------------------------------------------
    if (raw.startsWith('/chat ')) {
      await _sendChat(raw.substring(6).trim());
      return;
    }

    // Todo モード ----------------------------------------------
    final date = _selectedDueDate ?? _selectedDay ?? DateTime.now();
    
    // タスクを追加後、due dateをクリア
    final taskDate = date;
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
          'date': taskDate.toIso8601String(),
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        await _fetchTodos();
        // タスク追加成功後、due dateをクリア
        setState(() {
          _selectedDueDate = null;
        });
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
    setState(() {
      _chatMessages.add({'role': 'user', 'content': prompt});
    });

    try {
      final res = await http.post(
        Uri.parse('$_api/chat'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'messages': _chatMessages,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply = data['reply'] as String;
        setState(() {
          _chatMessages.add({'role': 'assistant', 'content': reply});
        });
      } else {
        final errorData = jsonDecode(res.body);
        throw Exception('Backend error: ${errorData['error'] ?? 'Unknown error'}');
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
  Widget _todoItem(Map<String, dynamic> todo) {
    final DateTime? dueDate = todo['date'] != null 
        ? DateTime.parse(todo['date']).toLocal() 
        : null;
    
    // 期限の表示用文字列と色を決定
    String? dueDateText;
    Color? dueDateColor;
    
    if (dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final taskDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
      final difference = taskDate.difference(today).inDays;
      
      if (difference < 0) {
        dueDateText = '期限切れ (${dueDate.month}/${dueDate.day})';
        dueDateColor = Colors.red;
      } else if (difference == 0) {
        dueDateText = '今日まで';
        dueDateColor = Colors.orange.shade700;
      } else if (difference == 1) {
        dueDateText = '明日まで';
        dueDateColor = Colors.orange;
      } else {
        dueDateText = '${dueDate.month}/${dueDate.day}まで';
        dueDateColor = Colors.blue.shade600;
      }
    }
    
    return ListTile(
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            todo['title'],
            style: TextStyle(
              decoration: todo['done'] ? TextDecoration.lineThrough : null,
            ),
          ),
          if (dueDateText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: dueDateColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dueDateText,
                    style: TextStyle(
                      fontSize: 12,
                      color: dueDateColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: () async {
          await http.delete(Uri.parse('$_api/todos/${todo["id"]}'));
          _fetchTodos();
        },
      ),
    );
  }

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
                          calendarStyle: const CalendarStyle(
                            selectedDecoration: BoxDecoration(
                              color: Colors.transparent,
                            ),
                            todayDecoration: BoxDecoration(
                              color: Colors.transparent,
                            ),
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
                              final isSelected = _selectedDay != null && 
                                  _stripTime(day) == _stripTime(_selectedDay!);
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isSelected ? Colors.green : Colors.blueAccent,
                                    width: isSelected ? 3 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  // ignore: deprecated_member_use
                                  color: isSelected ? Colors.green.withOpacity(0.1) : null,
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
                            selectedBuilder: (context, day, focusedDay) {
                              final key = _stripTime(day);
                              final tasks = _events[key] ?? [];
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.green, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                  // ignore: deprecated_member_use
                                  color: Colors.green.withOpacity(0.1),
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
                child: Column(
                  children: [
                    // Due date display row
                    if (_selectedDueDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              '期限: ${_selectedDueDate!.month}/${_selectedDueDate!.day}',
                              style: const TextStyle(color: Colors.blue, fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _clearDueDate,
                              child: const Icon(Icons.close, size: 16, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    // Input row
                    Row(
                      children: [
                        // Date picker button
                        IconButton(
                          icon: Icon(
                            Icons.calendar_today,
                            color: _selectedDueDate != null ? Colors.blue : Colors.grey,
                          ),
                          onPressed: _selectDueDate,
                          tooltip: '期限を選択',
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _textFieldFocus,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}