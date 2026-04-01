import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class TerminalForegroundService {
  TerminalForegroundService._();
  static final instance = TerminalForegroundService._();

  bool _running = false;

  Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'garudan_terminal',
        channelName: 'Terminal',
        channelDescription: 'Keeps terminal sessions alive',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 30000, // heartbeat every 30s
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> start(String serverName) async {
    if (_running) {
      await update(serverName);
      return;
    }
    await FlutterForegroundTask.startService(
      notificationTitle: 'Terminal active',
      notificationText: serverName,
      callback: _taskCallback,
    );
    _running = true;
  }

  Future<void> update(String serverName) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Terminal active',
      notificationText: serverName,
    );
  }

  Future<void> stop() async {
    if (!_running) return;
    await FlutterForegroundTask.stopService();
    _running = false;
  }

  bool get isRunning => _running;
}

@pragma('vm:entry-point')
void _taskCallback() {
  FlutterForegroundTask.setTaskHandler(_TerminalTaskHandler());
}

class _TerminalTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat — keeps service alive
    FlutterForegroundTask.sendDataToMain({'type': 'heartbeat', 'ts': timestamp.toIso8601String()});
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}
