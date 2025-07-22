import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class DebugPanel extends StatefulWidget {
  final String apiUrl;

  const DebugPanel({
    super.key,
    required this.apiUrl,
  });

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> {
  late NotificationService _notificationService;
  bool _isExpanded = false;
  bool _isSending = false;
  String _statusMessage = '';
  Map<String, dynamic>? _schedulerStatus;

  @override
  void initState() {
    super.initState();
    _notificationService = NotificationService(apiUrl: widget.apiUrl);
    _loadSchedulerStatus();
  }

  Future<void> _loadSchedulerStatus() async {
    final status = await _notificationService.getSchedulerStatus();
    if (mounted) {
      setState(() {
        _schedulerStatus = status;
      });
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() {
      _isSending = true;
      _statusMessage = '';
    });

    final success = await _notificationService.sendTestNotification();
    
    if (mounted) {
      setState(() {
        _isSending = false;
        _statusMessage = success 
            ? 'LINE通知テストを送信しました' 
            : 'LINE通知の送信に失敗しました';
      });

      // 3秒後にメッセージをクリア
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _statusMessage = '';
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.bug_report, color: Colors.orange),
            title: const Text('デバッグパネル'),
            trailing: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
            ),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
          ),
          if (_isExpanded) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // LINE通知テストボタン
                  ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendTestNotification,
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.notifications),
                    label: Text(_isSending ? '送信中...' : 'LINE通知テスト'),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // ステータスメッセージ
                  if (_statusMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: _statusMessage.contains('失敗')
                            ? Colors.red.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusMessage.contains('失敗')
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  
                  // スケジューラー状態
                  const Text(
                    'スケジューラー状態:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  if (_schedulerStatus != null) ...[
                    _buildStatusRow('実行中', _schedulerStatus!['status']?['running']?.toString() ?? 'N/A'),
                    _buildStatusRow('次回実行時刻', _getNextRunTime()),
                    _buildStatusRow('ジョブ数', _schedulerStatus!['status']?['jobs_count']?.toString() ?? 'N/A'),
                  ] else
                    const Text('状態を取得できませんでした'),
                  
                  const SizedBox(height: 8),
                  
                  // 更新ボタン
                  TextButton.icon(
                    onPressed: _loadSchedulerStatus,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('状態を更新'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getNextRunTime() {
    if (_schedulerStatus == null) return 'N/A';
    
    final jobs = _schedulerStatus!['status']?['jobs'] as List?;
    if (jobs == null || jobs.isEmpty) return 'N/A';
    
    // Find the earliest next_run_time from all jobs
    String? earliestTime;
    DateTime? earliestDateTime;
    
    for (final job in jobs) {
      final nextRunTime = job['next_run_time'] as String?;
      if (nextRunTime != null) {
        try {
          final dateTime = DateTime.parse(nextRunTime);
          if (earliestDateTime == null || dateTime.isBefore(earliestDateTime)) {
            earliestDateTime = dateTime;
            earliestTime = nextRunTime;
          }
        } catch (e) {
          // Ignore parsing errors
        }
      }
    }
    
    return earliestTime ?? 'N/A';
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}