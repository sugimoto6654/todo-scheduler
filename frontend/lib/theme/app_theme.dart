import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get theme => ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'NotoSansJP',
      );

  static const Locale japaneseLocale = Locale('ja', 'JP');
  static const Locale englishLocale = Locale('en', 'US');

  static const List<Locale> supportedLocales = [
    englishLocale,
    japaneseLocale,
  ];

  static Color get backgroundColor => Colors.grey.shade50;
  static Color get cardColor => Colors.white;
  static Color get appBarColor => Colors.white;
  static Color get appBarForegroundColor => Colors.black87;
}