import 'package:flutter/material.dart';

class TodoInputComponent extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final DateTime? selectedDueDate;
  final VoidCallback onSubmit;
  final VoidCallback onSelectDueDate;
  final VoidCallback onClearDueDate;

  const TodoInputComponent({
    super.key,
    required this.controller,
    required this.focusNode,
    this.selectedDueDate,
    required this.onSubmit,
    required this.onSelectDueDate,
    required this.onClearDueDate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            if (selectedDueDate != null) _buildDueDateDisplay(),
            _buildInputRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildDueDateDisplay() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '期限: ${selectedDueDate!.month}/${selectedDueDate!.day}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onClearDueDate,
                  child: const Icon(Icons.close, size: 18, color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.calendar_today_outlined,
            color: selectedDueDate != null ? Colors.blue : Colors.grey.shade600,
          ),
          onPressed: onSelectDueDate,
          tooltip: '期限を選択',
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: const InputDecoration(
              hintText: 'タスクを追加、または /chat で話しかける',
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: onSubmit,
          tooltip: '追加',
          color: Colors.blue,
        ),
      ],
    );
  }
}