import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'calendar_day_builder.dart';

class CustomCalendarComponent extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Map<DateTime, List<Map<String, dynamic>>> events;
  final Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final bool isUpdating;

  const CustomCalendarComponent({
    super.key,
    required this.focusedDay,
    this.selectedDay,
    required this.events,
    required this.onDaySelected,
    this.isUpdating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 500.0,
                maxWidth: 800.0,
              ),
              child: AnimatedOpacity(
                opacity: isUpdating ? 0.5 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: TableCalendar(
                  locale: 'ja_JP',
                  firstDay: DateTime.utc(2020),
                  lastDay: DateTime.utc(2030),
                  focusedDay: focusedDay,
                  rowHeight: 120.0,
                  daysOfWeekHeight: 20.0,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                  onDaySelected: onDaySelected,
                  startingDayOfWeek: StartingDayOfWeek.sunday,
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, date, focusedDay) =>
                        CalendarDayBuilder.buildDefaultDay(context, date, focusedDay, events),
                    selectedBuilder: (context, date, focusedDay) =>
                        CalendarDayBuilder.buildSelectedDay(context, date, focusedDay, events),
                    todayBuilder: (context, date, focusedDay) =>
                        CalendarDayBuilder.buildTodayDay(context, date, focusedDay, events),
                  ),
                  calendarStyle: const CalendarStyle(outsideDaysVisible: false),
                ),
              ),
            ),
          ),
          if (isUpdating)
            _buildUpdatingOverlay(),
        ],
      ),
    );
  }

  Widget _buildUpdatingOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('更新中...', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}