import 'dart:collection';
import 'package:flutter/material.dart';

/// 앱 화면에 디버그 로그를 표시하는 오버레이
class DebugLogOverlay extends StatefulWidget {
  final bool isVisible;

  const DebugLogOverlay({
    super.key,
    this.isVisible = true,
  });

  @override
  State<DebugLogOverlay> createState() => _DebugLogOverlayState();
}

class _DebugLogOverlayState extends State<DebugLogOverlay> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      left: 8,
      right: 8,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: _isExpanded ? 400 : 120,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green, width: 1),
        ),
        child: Column(
          children: [
            // 헤더
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bug_report,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Task 4 디버그 로그',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.green,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            
            // 로그 내용
            if (_isExpanded)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: ValueListenableBuilder<List<DebugLogEntry>>(
                    valueListenable: DebugLogger.instance.logs,
                    builder: (context, logs, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: logs.map((log) => _buildLogEntry(log)).toList(),
                      );
                    },
                  ),
                ),
              )
            else
              // 축약된 상태에서는 최근 3개 로그만 표시
              Container(
                padding: const EdgeInsets.all(8),
                height: 80,
                child: ValueListenableBuilder<List<DebugLogEntry>>(
                  valueListenable: DebugLogger.instance.logs,
                  builder: (context, logs, child) {
                    final recentLogs = logs.length > 3 
                        ? logs.sublist(logs.length - 3)
                        : logs;
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: recentLogs.map((log) => _buildLogEntry(log, compact: true)).toList(),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogEntry(DebugLogEntry log, {bool compact = false}) {
    Color textColor;
    IconData icon;
    
    switch (log.level) {
      case DebugLogLevel.error:
        textColor = Colors.red;
        icon = Icons.error;
        break;
      case DebugLogLevel.warning:
        textColor = Colors.orange;
        icon = Icons.warning;
        break;
      case DebugLogLevel.success:
        textColor = Colors.green;
        icon = Icons.check_circle;
        break;
      case DebugLogLevel.info:
        textColor = Colors.white;
        icon = Icons.info;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 12),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              compact ? log.message.substring(0, log.message.length > 50 ? 50 : log.message.length) + (log.message.length > 50 ? '...' : '')
                     : log.message,
              style: TextStyle(
                color: textColor,
                fontSize: compact ? 10 : 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum DebugLogLevel { error, warning, success, info }

class DebugLogEntry {
  final String message;
  final DebugLogLevel level;
  final DateTime timestamp;

  DebugLogEntry({
    required this.message,
    required this.level,
  }) : timestamp = DateTime.now();
}

/// 싱글톤 디버그 로거
class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  static DebugLogger get instance => _instance;
  
  DebugLogger._internal();

  final ValueNotifier<List<DebugLogEntry>> logs = ValueNotifier<List<DebugLogEntry>>([]);
  final Queue<DebugLogEntry> _logQueue = Queue<DebugLogEntry>();
  static const int maxLogs = 50;

  void error(String message) {
    _addLog(DebugLogEntry(message: message, level: DebugLogLevel.error));
  }

  void warning(String message) {
    _addLog(DebugLogEntry(message: message, level: DebugLogLevel.warning));
  }

  void success(String message) {
    _addLog(DebugLogEntry(message: message, level: DebugLogLevel.success));
  }

  void info(String message) {
    _addLog(DebugLogEntry(message: message, level: DebugLogLevel.info));
  }

  void _addLog(DebugLogEntry entry) {
    _logQueue.add(entry);
    
    // 최대 로그 수 유지
    while (_logQueue.length > maxLogs) {
      _logQueue.removeFirst();
    }
    
    logs.value = List.from(_logQueue);
  }

  void clear() {
    _logQueue.clear();
    logs.value = [];
  }
}