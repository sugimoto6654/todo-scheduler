class JsonFilterUtils {
  static final RegExp _jsonActionRegex = RegExp(
    r'```json\s*\{.*?\}\s*```\s*',
    multiLine: true,
    dotAll: true,
  );

  static final RegExp _jsonBlockRegex = RegExp(
    r'^\s*\{[\s\S]*?"action"[\s\S]*?\}\s*$',
    multiLine: true,
  );

  static String filterJsonActions(String text) {
    if (text.isEmpty) return text;
    
    // Remove JSON code blocks first
    String filtered = text.replaceAll(_jsonActionRegex, '');
    
    // Remove standalone JSON action objects
    filtered = filtered.replaceAll(_jsonBlockRegex, '');
    
    // Clean up extra whitespace and newlines more thoroughly
    filtered = filtered.replaceAll(RegExp(r'\n\s*\n\s*\n+'), '\n\n');
    filtered = filtered.replaceAll(RegExp(r'^\s*\n+'), '');
    filtered = filtered.replaceAll(RegExp(r'\n+\s*$'), '');
    filtered = filtered.trim();
    
    return filtered;
  }

  static List<String> extractJsonActions(String text) {
    List<String> actions = [];
    
    // Extract JSON code blocks
    final codeBlockMatches = _jsonActionRegex.allMatches(text);
    for (final match in codeBlockMatches) {
      actions.add(match.group(0) ?? '');
    }
    
    // Extract standalone JSON objects
    final jsonMatches = _jsonBlockRegex.allMatches(text);
    for (final match in jsonMatches) {
      actions.add(match.group(0) ?? '');
    }
    
    return actions;
  }

  static bool hasJsonActions(String text) {
    return _jsonActionRegex.hasMatch(text) || _jsonBlockRegex.hasMatch(text);
  }

  static String getCleanDisplayText(String text) {
    final filtered = filterJsonActions(text);
    
    // If the filtered text is empty or just whitespace, return a placeholder
    if (filtered.trim().isEmpty) {
      return 'アクションを実行しました。';
    }
    
    return filtered;
  }
}