import 'dart:convert';
import 'package:http/http.dart' as http;

class NotificationService {
  final String apiUrl;

  NotificationService({required this.apiUrl});

  Future<bool> sendTestNotification() async {
    try {
      final res = await http.post(
        Uri.parse('$apiUrl/debug/send-notification'),
        headers: {'Content-Type': 'application/json'},
      );
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSchedulerStatus() async {
    try {
      final res = await http.get(Uri.parse('$apiUrl/debug/scheduler-status'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}