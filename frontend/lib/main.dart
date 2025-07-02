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
    final DateTime? dueDate =
        todo['date'] != null ? DateTime.parse(todo['date']).toLocal() : null;

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
          onChanged: (v) async {
            await http.patch(
              Uri.parse('$_api/todos/${todo["id"]}'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'done': v}),
            );
            _fetchTodos();
          },
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
          onPressed: () async {
            await http.delete(Uri.parse('$_api/todos/${todo["id"]}'));
            _fetchTodos();
          },
        ),
      ),
    );
  }

  Widget _chatBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          msg['content'] ?? '',
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'NotoSansJP',
        ),
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
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: const Text('Todo Scheduler',
                style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 1,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // --- Todo & Calendar ----------------------------------------
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Left Pane (Todo List & Chat) ---
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            // Todo list
                            Expanded(
                              child: Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                                      child: Text('タスク一覧',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    Expanded(
                                      child: ListView(
                                        padding: const EdgeInsets.all(8),
                                        children: todos
                                            .map<Widget>(_todoItem)
                                            .toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // --- ChatGPT area ---
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Container(
                                height: 240,
                                padding: const EdgeInsets.all(8),
                                child: _chatMessages.isEmpty
                                    ? Center(
                                        child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.chat_bubble_outline,
                                              size: 40,
                                              color: Colors.grey.shade400),
                                          const SizedBox(height: 8),
                                          const Text('ChatGPT との対話を開始します',
                                              style: TextStyle(
                                                  color: Colors.grey)),
                                        ],
                                      ))
                                    : ListView.builder(
                                        controller: _chatScroll,
                                        itemCount: _chatMessages.length,
                                        itemBuilder: (context, idx) =>
                                            _chatBubble(_chatMessages[idx]),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Calendar
                      Expanded(
                        flex: 2,
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TableCalendar(
                              locale: 'ja_JP',
                              firstDay: DateTime.utc(2020),
                              lastDay: DateTime.utc(2030),
                              focusedDay: _focusedDay,
                              rowHeight: 120.0,
                              daysOfWeekHeight: 20.0,
                              headerStyle: const HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                                titleTextStyle: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              selectedDayPredicate: (day) =>
                                  isSameDay(_selectedDay, day),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                              },
                              startingDayOfWeek: StartingDayOfWeek.sunday,
                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, date, focusedDay) {
                                  final tasks = _events[_stripTime(date)] ?? [];
                                  return Container(
                                    margin: const EdgeInsets.all(2.0),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 0.5,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 日付の表示
                                        Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: Text(
                                            '${date.day}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                        // タスクの表示（最大6つ）
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // 最大6つのタスクを表示
                                                ...tasks.take(6).map((task) => Container(
                                                  width: double.infinity,
                                                  constraints: const BoxConstraints(
                                                    minHeight: 12.0,
                                                    maxHeight: 12.0,
                                                  ),
                                                  margin: const EdgeInsets.only(bottom: 0.5),
                                                  padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 0.5),
                                                  decoration: BoxDecoration(
                                                    color: task['done'] 
                                                        ? Colors.grey.shade300 
                                                        : Colors.blue.shade100,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                  child: Text(
                                                    task['title'] ?? '',
                                                    style: TextStyle(
                                                      fontSize: 7,
                                                      color: task['done'] 
                                                          ? Colors.grey.shade600 
                                                          : Colors.blue.shade800,
                                                      decoration: task['done'] 
                                                          ? TextDecoration.lineThrough 
                                                          : null,
                                                      height: 1.0,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    softWrap: false,
                                                  ),
                                                )).toList(),
                                                // 6つ以上のタスクがある場合の表示
                                                if (tasks.length > 6)
                                                  Container(
                                                    width: double.infinity,
                                                    constraints: const BoxConstraints(
                                                      minHeight: 12.0,
                                                      maxHeight: 12.0,
                                                    ),
                                                    margin: const EdgeInsets.only(top: 0.5),
                                                    padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 0.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.shade100,
                                                      borderRadius: BorderRadius.circular(2),
                                                    ),
                                                    child: Text(
                                                      '他${tasks.length - 6}件',
                                                      style: TextStyle(
                                                        fontSize: 6,
                                                        color: Colors.orange.shade800,
                                                        fontWeight: FontWeight.bold,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                // 残りのスペースを埋める
                                                const Spacer(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                selectedBuilder: (context, date, focusedDay) {
                                  final tasks = _events[_stripTime(date)] ?? [];
                                  return Container(
                                    margin: const EdgeInsets.all(2.0),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade300,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 日付の表示
                                        Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: Text(
                                            '${date.day}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        // タスクの表示（最大6つ）
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // 最大6つのタスクを表示
                                                ...tasks.take(6).map((task) => Container(
                                                  width: double.infinity,
                                                  constraints: const BoxConstraints(
                                                    minHeight: 12.0,
                                                    maxHeight: 12.0,
                                                  ),
                                                  margin: const EdgeInsets.only(bottom: 0.5),
                                                  padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 0.5),
                                                  decoration: BoxDecoration(
                                                    color: task['done'] 
                                                        ? Colors.grey.shade300 
                                                        : Colors.white,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                  child: Text(
                                                    task['title'] ?? '',
                                                    style: TextStyle(
                                                      fontSize: 7,
                                                      color: task['done'] 
                                                          ? Colors.grey.shade600 
                                                          : Colors.orange.shade800,
                                                      decoration: task['done'] 
                                                          ? TextDecoration.lineThrough 
                                                          : null,
                                                      height: 1.0,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    softWrap: false,
                                                  ),
                                                )).toList(),
                                                // 6つ以上のタスクがある場合の表示
                                                if (tasks.length > 6)
                                                  Container(
                                                    width: double.infinity,
                                                    constraints: const BoxConstraints(
                                                      minHeight: 12.0,
                                                      maxHeight: 12.0,
                                                    ),
                                                    margin: const EdgeInsets.only(top: 0.5),
                                                    padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 0.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(2),
                                                    ),
                                                    child: Text(
                                                      '他${tasks.length - 6}件',
                                                      style: TextStyle(
                                                        fontSize: 6,
                                                        color: Colors.orange.shade800,
                                                        fontWeight: FontWeight.bold,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                // 残りのスペースを埋める
                                                const Spacer(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                todayBuilder: (context, date, focusedDay) {
                                  final tasks = _events[_stripTime(date)] ?? [];
                                  return Container(
                                    margin: const EdgeInsets.all(2.0),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 日付の表示
                                        Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: Text(
                                            '${date.day}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue.shade800,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        // タスクの表示（最大6つ）
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // 最大6つのタスクを表示
                                                ...tasks.take(6).map((task) => Container(
                                                  width: double.infinity,
                                                  constraints: const BoxConstraints(
                                                    minHeight: 12.0,
                                                    maxHeight: 12.0,
                                                  ),
                                                  margin: const EdgeInsets.only(bottom: 0.5),
                                                  padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 0.5),
                                                  decoration: BoxDecoration(
                                                    color: task['done'] 
                                                        ? Colors.grey.shade300 
                                                        : Colors.white,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                  child: Text(
                                                    task['title'] ?? '',
                                                    style: TextStyle(
                                                      fontSize: 7,
                                                      color: task['done'] 
                                                          ? Colors.grey.shade600 
                                                          : Colors.blue.shade800,
                                                      decoration: task['done'] 
                                                          ? TextDecoration.lineThrough 
                                                          : null,
                                                      height: 1.0,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    softWrap: false,
                                                  ),
                                                )).toList(),
                                                // 6つ以上のタスクがある場合の表示
                                                if (tasks.length > 6)
                                                  Container(
                                                    width: double.infinity,
                                                    constraints: const BoxConstraints(
                                                      minHeight: 12.0,
                                                      maxHeight: 12.0,
                                                    ),
                                                    margin: const EdgeInsets.only(top: 0.5),
                                                    padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 0.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(2),
                                                    ),
                                                    child: Text(
                                                      '他${tasks.length - 6}件',
                                                      style: TextStyle(
                                                        fontSize: 6,
                                                        color: Colors.blue.shade800,
                                                        fontWeight: FontWeight.bold,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                // 残りのスペースを埋める
                                                const Spacer(),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              calendarStyle: const CalendarStyle(
                                outsideDaysVisible: false,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // --- Input row (Todo & Chat) ------------------------------
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Column(
                      children: [
                        // Due date display row
                        if (_selectedDueDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today,
                                          size: 16, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Text(
                                        '期限: ${_selectedDueDate!.month}/${_selectedDueDate!.day}',
                                        style: const TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: _clearDueDate,
                                        child: const Icon(Icons.close,
                                            size: 18, color: Colors.blue),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Input row
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.calendar_today_outlined,
                                color: _selectedDueDate != null
                                    ? Colors.blue
                                    : Colors.grey.shade600,
                              ),
                              onPressed: _selectDueDate,
                              tooltip: '期限を選択',
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _textFieldFocus,
                                decoration: const InputDecoration(
                                  hintText: 'タスクを追加、または /chat で話しかける',
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                ),
                                onSubmitted: (_) => _addTodoOrChat(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _addTodoOrChat,
                              tooltip: '追加',
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}