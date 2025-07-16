import 'package:flutter/material.dart';
import '../utils/json_filter.dart';
import '../utils/settings.dart';

class ChatInterfaceComponent extends StatelessWidget {
  final List<Map<String, String>> chatMessages;
  final ScrollController chatScrollController;
  final bool isUpdatingFromChat;

  const ChatInterfaceComponent({
    super.key,
    required this.chatMessages,
    required this.chatScrollController,
    this.isUpdatingFromChat = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 240,
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: chatMessages.isEmpty
                      ? _buildEmptyState()
                      : ListenableBuilder(
                          listenable: AppSettings(),
                          builder: (context, child) {
                            return ListView.builder(
                              controller: chatScrollController,
                              itemCount: chatMessages.length,
                              itemBuilder: (context, idx) => _chatBubble(chatMessages[idx]),
                            );
                          },
                        ),
                ),
              ],
            ),
            if (isUpdatingFromChat)
              _buildUpdatingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ChatGPT',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          ListenableBuilder(
            listenable: AppSettings(),
            builder: (context, child) {
              return IconButton(
                icon: Icon(
                  AppSettings().showJsonActions ? Icons.code : Icons.code_off,
                  size: 16,
                ),
                onPressed: () {
                  AppSettings().toggleJsonActions();
                },
                tooltip: AppSettings().showJsonActions ? 'JSON非表示' : 'JSON表示',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 24,
                  minHeight: 24,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          const Text(
            'ChatGPT との対話を開始します',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _chatBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    final content = msg['content'] ?? '';
    
    // Filter JSON actions from assistant messages only, unless user wants to see them
    final showJson = AppSettings().showJsonActions;
    final displayText = isUser || showJson ? content : JsonFilterUtils.getCleanDisplayText(content);
    
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
          displayText,
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildUpdatingOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'カレンダーを更新中...',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}