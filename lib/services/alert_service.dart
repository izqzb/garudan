import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/constants.dart';
import '../models/server_profile.dart';
import 'storage_service.dart';

class AlertService {
  AlertService._();
  static final AlertService instance = AlertService._();

  final _notifications = FlutterLocalNotificationsPlugin();
  Timer? _timer;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialized = true;
  }

  void startMonitoring(StorageService storage, List<ServerProfile> profiles) {
    _timer?.cancel();
    _timer = Timer.periodic(AppConstants.alertCheckInterval, (_) async {
      if (!storage.isAlertsEnabled()) return;
      for (final profile in profiles) {
        await _checkServer(storage, profile);
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkServer(StorageService storage, ServerProfile profile) async {
    if (profile.apiToken == null) return;
    try {
      final dio = Dio(BaseOptions(
        baseUrl: profile.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        headers: {'Authorization': 'Bearer ${profile.apiToken}'},
      ));
      final resp = await dio.get<dynamic>(AppConstants.pathSystemStats);
      final data = resp.data as Map<String, dynamic>;

      final cpu  = (data['cpu']?['percent']    as num?)?.toDouble() ?? 0;
      final ram  = (data['memory']?['percent'] as num?)?.toDouble() ?? 0;
      final disk = (data['disk']?['percent']   as num?)?.toDouble() ?? 0;

      final cpuT  = storage.getCpuThreshold();
      final ramT  = storage.getRamThreshold();
      final diskT = storage.getDiskThreshold();

      if (cpu > cpuT)  _notify('${profile.name}: High CPU', 'CPU usage is ${cpu.toStringAsFixed(1)}% (threshold: $cpuT%)');
      if (ram > ramT)  _notify('${profile.name}: High RAM', 'RAM usage is ${ram.toStringAsFixed(1)}% (threshold: $ramT%)');
      if (disk > diskT) _notify('${profile.name}: High Disk', 'Disk usage is ${disk.toStringAsFixed(1)}% (threshold: $diskT%)');
    } catch (_) {}
  }

  Future<void> _notify(String title, String body) async {
    await _notifications.show(
      title.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'garudan_alerts',
          'Server Alerts',
          channelDescription: 'CPU, RAM and disk threshold alerts',
          importance: Importance.high,
          priority: Priority.high,
          color: Color(0xFF7C83FD),
        ),
      ),
    );
  }
}

// Needed for Color in notification
class Color {
  const Color(this.value);
  final int value;
}
