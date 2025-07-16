import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/json_filter.dart';

void main() {
  group('JsonFilterUtils', () {
    test('should filter JSON code blocks', () {
      const input = '''
こんにちは！タスクを追加します。

```json
{
  "action": "add_task",
  "task": "新しいタスク"
}
```

タスクが追加されました。
''';

      final result = JsonFilterUtils.filterJsonActions(input);
      
      expect(result, contains('こんにちは！タスクを追加します。'));
      expect(result, contains('タスクが追加されました。'));
      expect(result, isNot(contains('```json')));
      expect(result, isNot(contains('"action"')));
    });

    test('should filter JSON code blocks with trailing newlines', () {
      const input = '''
テキスト前

```json
{
  "action": "test"
}
```


テキスト後
''';

      final result = JsonFilterUtils.filterJsonActions(input);
      
      expect(result, contains('テキスト前'));
      expect(result, contains('テキスト後'));
      expect(result, isNot(contains('```json')));
      expect(result, isNot(contains('"action"')));
      // Should not have excessive newlines
      expect(result, isNot(contains('\n\n\n')));
    });

    test('should filter standalone JSON objects', () {
      const input = '''
タスクを更新します。

{
  "action": "update_task",
  "id": "123"
}

更新完了しました。
''';

      final result = JsonFilterUtils.filterJsonActions(input);
      
      expect(result, contains('タスクを更新します。'));
      expect(result, contains('更新完了しました。'));
      expect(result, isNot(contains('"action"')));
    });

    test('should return placeholder when only JSON is present', () {
      const input = '''
```json
{
  "action": "delete_task",
  "id": "456"
}
```
''';

      final result = JsonFilterUtils.getCleanDisplayText(input);
      
      expect(result, equals('アクションを実行しました。'));
    });

    test('should preserve user messages without filtering', () {
      const input = 'ユーザーメッセージ: {"action": "test"}';
      
      final result = JsonFilterUtils.filterJsonActions(input);
      
      expect(result, equals(input));
    });

    test('should detect JSON actions correctly', () {
      const withJson = '''
テキスト
```json
{"action": "test"}
```
''';

      const withoutJson = '普通のテキストメッセージ';
      
      expect(JsonFilterUtils.hasJsonActions(withJson), isTrue);
      expect(JsonFilterUtils.hasJsonActions(withoutJson), isFalse);
    });
  });
}