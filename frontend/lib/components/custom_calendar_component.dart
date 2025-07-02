import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'calendar_day_builder.dart';

class CustomCalendarComponent extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Map<DateTime, List<Map<String, dynamic>>> events;
  final Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;

  const CustomCalendarComponent({
    super.key,
    required this.focusedDay,
    this.selectedDay,
    required this.events,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
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
    );
  }
}