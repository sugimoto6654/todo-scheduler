import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../components/todo_list_component.dart';
import '../components/custom_calendar_component.dart';
import '../components/chat_interface_component.dart';
import '../components/todo_input_component.dart';
import '../services/todo_service.dart';
import '../services/chat_service.dart';
import '../services/action_handler.dart';
import '../models/input_mode.dart';

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
  bool _isUpdatingFromChat = false;
  InputMode _inputMode = InputMode.task;

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

  void _toggleInputMode() {
    setState(() {
      _inputMode = _inputMode == InputMode.task ? InputMode.chat : InputMode.task;
    });
    // Maintain focus on the text field after mode toggle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_textFieldFocus.context?.mounted == true) {
        _textFieldFocus.requestFocus();
      }
    });
  }

  Future<void> _addTodoOrChat() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    
    _controller.clear();
    _textFieldFocus.requestFocus();

    // Handle chat mode input
    if (_inputMode == InputMode.chat) {
      await _sendChat(raw);
      return;
    }

    // Handle task mode input (also support legacy /chat prefix)
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
      
      final response = await _chatService.sendMessage(
        _chatMessages,
        currentMonthTasks: taskContext,
      );
      
      if (response.success) {
        setState(() {
          _chatMessages.add({'role': 'assistant', 'content': response.reply});
        });
        
        // アクションが実行された場合、即座にカレンダーを更新
        if (response.hasActions) {
          await _updateCalendarFromChatActions(response.actions);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.error ?? 'エラーが発生しました')),
          );
        }
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

  Future<void> _updateCalendarFromChatActions(List<ExecutedAction> actions) async {
    setState(() {
      _isUpdatingFromChat = true;
    });

    try {
      // ChatGPTアクションの種類に応じて最適化された更新処理
      final needsFullRefresh = _shouldPerformFullRefresh(actions);
      
      if (needsFullRefresh) {
        // 全体のリフレッシュが必要な場合
        await _fetchTodos();
      } else {
        // 部分的な更新で済む場合
        await _performOptimizedUpdate(actions);
      }

      // 成功通知を表示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('${actions.length}件のアクションが実行されました'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // エラーが発生した場合はフォールバックとして全体リフレッシュ
      print('Optimized update failed, falling back to full refresh: $e');
      
      try {
        await _fetchTodos();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: 8),
                  Text('カレンダーを更新しました（フォールバック）'),
                ],
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (fallbackError) {
        // フォールバックも失敗した場合
        print('Fallback refresh also failed: $fallbackError');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Text('カレンダーの更新に失敗しました'),
                ],
              ),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: '再試行',
                textColor: Colors.white,
                onPressed: () => _fetchTodos(),
              ),
            ),
          );
        }
      }
    } finally {
      setState(() {
        _isUpdatingFromChat = false;
      });
    }
  }

  bool _shouldPerformFullRefresh(List<ExecutedAction> actions) {
    // 以下の場合は全体リフレッシュが必要
    for (final action in actions) {
      if (action.type == 'split_task' || 
          action.type == 'create_tasks' || 
          actions.length > 5) {
        return true;
      }
    }
    return false;
  }

  Future<void> _performOptimizedUpdate(List<ExecutedAction> actions) async {
    // 最適化された部分更新処理
    try {
      // キャッシュをクリアしてフレッシュなデータを取得
      _todoService.clearCache();
      
      // 効率的なデータ取得
      final fetchedTodos = await _todoService.fetchTodosOptimized();
      final events = _todoService.organizeEventsByDate(fetchedTodos);

      setState(() {
        todos = fetchedTodos;
        _events = events;
      });
    } catch (e) {
      // エラーの場合は通常のfetchTodosにフォールバック
      await _fetchTodos();
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
      home: Focus(
        autofocus: true,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.tab) {
            _toggleInputMode();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Scaffold(
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
                              isUpdatingFromChat: _isUpdatingFromChat,
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
                          isUpdating: _isUpdatingFromChat,
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
                  inputMode: _inputMode,
                  onToggleMode: _toggleInputMode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}