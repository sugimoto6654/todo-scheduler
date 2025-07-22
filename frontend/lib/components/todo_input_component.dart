import 'package:flutter/material.dart';
import '../models/input_mode.dart';

class TodoInputComponent extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final DateTime? selectedDueDate;
  final VoidCallback onSubmit;
  final VoidCallback onSelectDueDate;
  final VoidCallback onClearDueDate;
  final InputMode inputMode;
  final VoidCallback onToggleMode;

  const TodoInputComponent({
    super.key,
    required this.controller,
    required this.focusNode,
    this.selectedDueDate,
    required this.onSubmit,
    required this.onSelectDueDate,
    required this.onClearDueDate,
    required this.inputMode,
    required this.onToggleMode,
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
        _buildModeIndicator(),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: inputMode.placeholder,
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

  Widget _buildModeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: inputMode == InputMode.task ? Colors.blue.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: inputMode == InputMode.task ? Colors.blue.shade300 : Colors.green.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inputMode == InputMode.task ? Icons.task_alt : Icons.chat_bubble_outline,
            size: 16,
            color: inputMode == InputMode.task ? Colors.blue : Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            inputMode.displayName,
            style: TextStyle(
              color: inputMode == InputMode.task ? Colors.blue : Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}