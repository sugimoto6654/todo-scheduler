class DateUtilities {
  static DateTime stripTime(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);

  static String formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final difference = taskDate.difference(today).inDays;

    if (difference < 0) {
      return '期限切れ (${dueDate.month}/${dueDate.day})';
    } else if (difference == 0) {
      return '今日まで';
    } else if (difference == 1) {
      return '明日まで';
    } else {
      return '${dueDate.month}/${dueDate.day}まで';
    }
  }

  static DueDateInfo getDueDateInfo(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final difference = taskDate.difference(today).inDays;

    if (difference < 0) {
      return DueDateInfo(
        text: '期限切れ (${dueDate.month}/${dueDate.day})',
        priority: DueDatePriority.overdue,
      );
    } else if (difference == 0) {
      return DueDateInfo(
        text: '今日まで',
        priority: DueDatePriority.today,
      );
    } else if (difference == 1) {
      return DueDateInfo(
        text: '明日まで',
        priority: DueDatePriority.tomorrow,
      );
    } else {
      return DueDateInfo(
        text: '${dueDate.month}/${dueDate.day}まで',
        priority: DueDatePriority.upcoming,
      );
    }
  }
}

class DueDateInfo {
  final String text;
  final DueDatePriority priority;

  DueDateInfo({required this.text, required this.priority});
}

enum DueDatePriority {
  overdue,
  today,
  tomorrow,
  upcoming,
}