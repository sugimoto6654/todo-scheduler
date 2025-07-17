class CalendarConstants {
  // Task display limits
  static const int maxVisibleTasks = 6;
  
  // Dimensions
  static const double dayContainerMinWidth = 120.0;
  static const double dayContainerMargin = 1.0;
  static const double dayContainerPadding = 1.0;
  static const double dayContainerBorderRadius = 4.0;
  static const double dayContainerBorderWidth = 0.5;
  
  // Day number styling
  static const double dayNumberPadding = 2.0;
  static const double dayNumberFontSize = 12.0;
  
  // Task container styling
  static const double taskContainerMinHeight = 12.0;
  static const double taskContainerMaxHeight = 12.0;
  static const double taskContainerBottomMargin = 0.5;
  static const double taskContainerHorizontalPadding = 1.5;
  static const double taskContainerVerticalPadding = 0.5;
  static const double taskContainerBorderRadius = 2.0;
  static const double taskFontSize = 7.0;
  static const double taskLineHeight = 1.0;
  
  // More tasks indicator styling
  static const double moreTasksIndicatorTopMargin = 0.5;
  static const double moreTasksIndicatorFontSize = 6.0;
  
  // Content padding
  static const double contentHorizontalPadding = 2.0;
  
  // Localized text
  static const String moreTasksText = '他';
  static const String moreTasksUnit = '件';
  
  static String getMoreTasksText(int count) => '$moreTasksText$count$moreTasksUnit';
}