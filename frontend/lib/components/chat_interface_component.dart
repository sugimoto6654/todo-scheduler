import 'package:flutter/material.dart';

class ChatInterfaceComponent extends StatelessWidget {
  final List<Map<String, String>> chatMessages;
  final ScrollController chatScrollController;

  const ChatInterfaceComponent({
    super.key,
    required this.chatMessages,
    required this.chatScrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 240,
        padding: const EdgeInsets.all(8),
        child: chatMessages.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                controller: chatScrollController,
                itemCount: chatMessages.length,
                itemBuilder: (context, idx) => _chatBubble(chatMessages[idx]),
              ),
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
}