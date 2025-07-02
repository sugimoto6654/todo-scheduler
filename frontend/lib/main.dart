import 'package:flutter/material.dart';
import 'screens/home_page.dart';

void main() async {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}