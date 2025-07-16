import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../components/todo_list_component.dart';
import '../components/custom_calendar_component.dart';
import '../components/chat_interface_component.dart';
import '../components/todo_input_component.dart';
import '../services/todo_service.dart';
import '../services/chat_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String _api = const String.fromEnvironment('API', defaultValue: 'http://backend:5000');

  late final TodoService _todoService;
  late final ChatService _chatService;

  List<Map<String, dynamic>> todos = [];
  Map<DateTime, List<Map<String, dynamic>>> _events = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  final List<Map<String, String>> _chatMessages = [];

  final TextEditingController _controller = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  final FocusNode _textFieldFocus = FocusNode();

  DateTime? _selectedDueDate;

  @override
  void initState() {
    super.initState();
    _todoService = TodoService(apiUrl: _api);
    _chatService = ChatService(apiUrl: _api);
    _fetchTodos();
  }

  @override
  void dispose() {
    _textFieldFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchTodos() async {
    final fetchedTodos = await _todoService.fetchTodos();
    final events = _todoService.organizeEventsByDate(fetchedTodos);

    setState(() {
      todos = fetchedTodos;
      _events = events;
    });
  }

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
    
    _controller.clear();
    _textFieldFocus.requestFocus();

    if (raw.startsWith('/chat ')) {
      await _sendChat(raw.substring(6).trim());
      return;
    }

    final date = _selectedDueDate ?? _selectedDay ?? DateTime.now();
    
    final success = await _todoService.addTodo(raw, date);
    if (success) {
      await _fetchTodos();
      setState(() {
        _selectedDueDate = null;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todo 追加に失敗しました')),
        );
      }
    }
  }

  Future<void> _sendChat(String prompt) async {
    setState(() {
      _chatMessages.add({'role': 'user', 'content': prompt});
    });

    try {
      // 現在フォーカス中の月のタスク情報を取得
      final currentMonthTasks = _todoService.getCurrentMonthTasks(todos, _focusedDay);
      final taskContext = _todoService.formatTasksForPrompt(currentMonthTasks, _focusedDay);
      
      final reply = await _chatService.sendMessage(
        _chatMessages,
        currentMonthTasks: taskContext,
      );
      if (reply != null) {
        setState(() {
          _chatMessages.add({'role': 'assistant', 'content': reply});
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
          title: const Text(
            'Todo Scheduler',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          Expanded(
                            child: TodoListComponent(
                              todos: todos,
                              apiUrl: _api,
                              onTodoUpdate: _fetchTodos,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ChatInterfaceComponent(
                            chatMessages: _chatMessages,
                            chatScrollController: _chatScroll,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: CustomCalendarComponent(
                        focusedDay: _focusedDay,
                        selectedDay: _selectedDay,
                        events: _events,
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            // Toggle functionality: if same date is clicked, unselect it
                            if (_selectedDay != null && 
                                _selectedDay!.year == selectedDay.year &&
                                _selectedDay!.month == selectedDay.month &&
                                _selectedDay!.day == selectedDay.day) {
                              _selectedDay = null;
                            } else {
                              _selectedDay = selectedDay;
                            }
                            _focusedDay = focusedDay;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TodoInputComponent(
                controller: _controller,
                focusNode: _textFieldFocus,
                selectedDueDate: _selectedDueDate,
                onSubmit: _addTodoOrChat,
                onSelectDueDate: _selectDueDate,
                onClearDueDate: _clearDueDate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}