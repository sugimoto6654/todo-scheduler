import 'package:flutter/material.dart';

class CalendarDayBuilder {
  static DateTime _stripTime(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);

  static Widget buildDefaultDay(
    BuildContext context,
    DateTime date,
    DateTime focusedDay,
    Map<DateTime, List<Map<String, dynamic>>> events,
  ) {
    final tasks = events[_stripTime(date)] ?? [];
    return Container(
      margin: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(2.0),
            child: Text('${date.day}', style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...tasks.take(6).map((task) => _buildTaskContainer(task, false)),
                  if (tasks.length > 6) _buildMoreTasksIndicator(tasks.length - 6, false),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildSelectedDay(
    BuildContext context,
    DateTime date,
    DateTime focusedDay,
    Map<DateTime, List<Map<String, dynamic>>> events,
  ) {
    final tasks = events[_stripTime(date)] ?? [];
    return Container(
      margin: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: Colors.orange.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...tasks.take(6).map((task) => _buildTaskContainer(task, true)),
                  if (tasks.length > 6) _buildMoreTasksIndicator(tasks.length - 6, true),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildTodayDay(
    BuildContext context,
    DateTime date,
    DateTime focusedDay,
    Map<DateTime, List<Map<String, dynamic>>> events,
  ) {
    final tasks = events[_stripTime(date)] ?? [];
    return Container(
      margin: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...tasks.take(6).map((task) => _buildTaskContainer(task, false, isToday: true)),
                  if (tasks.length > 6) _buildMoreTasksIndicator(tasks.length - 6, false, isToday: true),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildTaskContainer(Map<String, dynamic> task, bool isSelected, {bool isToday = false}) {
    Color backgroundColor;
    Color textColor;

    if (task['done']) {
      backgroundColor = Colors.grey.shade300;
      textColor = Colors.grey.shade600;
    } else if (isSelected) {
      backgroundColor = Colors.white;
      textColor = Colors.orange.shade800;
    } else if (isToday) {
      backgroundColor = Colors.white;
      textColor = Colors.blue.shade800;
    } else {
      backgroundColor = Colors.blue.shade100;
      textColor = Colors.blue.shade800;
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 12.0, maxHeight: 12.0),
      margin: const EdgeInsets.only(bottom: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 0.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        task['title'] ?? '',
        style: TextStyle(
          fontSize: 7,
          color: textColor,
          decoration: task['done'] ? TextDecoration.lineThrough : null,
          height: 1.0,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  static Widget _buildMoreTasksIndicator(int count, bool isSelected, {bool isToday = false}) {
    Color backgroundColor;
    Color textColor;

    if (isSelected) {
      backgroundColor = Colors.white;
      textColor = Colors.orange.shade800;
    } else if (isToday) {
      backgroundColor = Colors.white;
      textColor = Colors.blue.shade800;
    } else {
      backgroundColor = Colors.orange.shade100;
      textColor = Colors.orange.shade800;
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 12.0, maxHeight: 12.0),
      margin: const EdgeInsets.only(top: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 1.5, vertical: 0.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        '他${count}件',
        style: TextStyle(
          fontSize: 6,
          color: textColor,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }
}