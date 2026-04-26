import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AppLogger {
  static final List<String> _logs = [];
  static String? _logFilePath;

  static Future<void> init() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFilePath = '${directory.path}/error_logs.txt';
      
      // 기존 로그 파일 초기화 (새 세션마다 새로 시작하거나 이어서 작성 가능)
      final file = File(_logFilePath!);
      if (await file.exists()) {
        await file.writeAsString('--- New Session Started: ${DateTime.now()} ---\n');
      }
    } catch (e) {
      debugPrint('Failed to initialize AppLogger: $e');
    }
  }

  static void log(String message) async {
    final timestamp = DateTime.now().toString();
    final logMessage = '[$timestamp] $message';
    _logs.add(logMessage);
    debugPrint(logMessage);

    if (_logFilePath != null) {
      try {
        final file = File(_logFilePath!);
        await file.writeAsString('$logMessage\n', mode: FileMode.append);
      } catch (e) {
        debugPrint('Failed to write log to file: $e');
      }
    }
  }

  static List<String> get logs => List.unmodifiable(_logs);

  static Future<void> shareLogs() async {
    if (_logFilePath != null && await File(_logFilePath!).exists()) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_logFilePath!)],
          text: 'AR Card Battler Error Logs',
        ),
      );
    } else if (_logs.isNotEmpty) {
      await SharePlus.instance.share(
        ShareParams(
          text: _logs.join('\n'),
          subject: 'AR Card Battler Error Logs',
        ),
      );
    }
  }

  static Future<void> clearLogs() async {
    _logs.clear();
    if (_logFilePath != null) {
      try {
        final file = File(_logFilePath!);
        if (await file.exists()) await file.delete();
      } catch (e) {
        // Ignore deletion errors or log them if necessary
        debugPrint('Failed to delete log file: $e');
      }
    }
  }
}
