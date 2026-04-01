import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Foreground service that keeps SSH sessions alive when app is backgrounded.
/// Uses flutter_foreground_task 6.5.0 API.

@pragma('vm:entry-point')
void terminalForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

class _KeepAliveHandler extends TaskHandler {
  @override
  void onStart(DateTime timestamp, SendPort? sendPort) {}

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {
    // Ping the main isolate — main isolate pings SSH connections
    sendPort?.send('keepalive');
  }

  @override
  void onDestroy(DateTime timestamp, SendPort? sendPort) {}
}

class TerminalForegroundService {
  TerminalForegroundService._();
  static final instance = TerminalForegroundService._();

  bool _running = false;
  bool get isRunning => _running;

  void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'garudan_terminal',
        channelName: 'Terminal Sessions',
        channelDescription: 'Keeps SSH sessions alive in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 20000, // ping every 20s — same as old app
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> start({required int sessionCount}) async {
    if (_running) {
      await _update(sessionCount);
      return;
    }
    try {
      await FlutterForegroundTask.startService(
        notificationTitle: 'Terminal active',
        notificationText: '$sessionCount session${sessionCount != 1 ? 's' : ''} running',
        callback: terminalForegroundCallback,
      );
      _running = true;
    } catch (_) {}
  }

  Future<void> _update(int sessionCount) async {
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Terminal active',
        notificationText: '$sessionCount session${sessionCount != 1 ? 's' : ''} running',
      );
    } catch (_) {}
  }

  Future<void> updateCount(int count) => _update(count);

  Future<void> stop() async {
    if (!_running) return;
    try {
      await FlutterForegroundTask.stopService();
    } catch (_) {}
    _running = false;
  }

  Future<void> requestBatteryExemption() async {
    try {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (_) {}
  }
}
