import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/server_profile.dart';
import '../../services/storage_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, required this.serverId});
  final String serverId;
  @override
  ConsumerState<NotificationsScreen> createState() => _State();
}

class _State extends ConsumerState<NotificationsScreen> {
  ServerProfile? _profile;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;
  Dio? _dio;

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    final profiles = await ref.read(storageServiceProvider).getServerProfiles();
    try { _profile = profiles.firstWhere((p) => p.id == widget.serverId); }
    catch (_) { setState(() { _error = 'Server not found'; _loading = false; }); return; }

    if (_profile!.gotifyUrl == null || _profile!.gotifyToken == null) {
      setState(() { _error = 'Gotify not configured for this server.\nEdit server profile to add Gotify URL and token.'; _loading = false; });
      return;
    }

    _dio = Dio(BaseOptions(
      baseUrl: _profile!.gotifyUrl!,
      connectTimeout: const Duration(seconds: 10),
      headers: {'X-Gotify-Key': _profile!.gotifyToken!},
    ));
    await _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _dio!.get<dynamic>('/message', queryParameters: {'limit': 50});
      final data = r.data as Map;
      setState(() {
        _messages = (data['messages'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.notifications_off_outlined, size: 48, color: Color(0xFF444444)),
                    const SizedBox(height: 16),
                    Text(_error!, style: const TextStyle(color: Color(0xFF888888)), textAlign: TextAlign.center),
                    if (_profile != null) ...[
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => context.push('/servers/edit/${_profile!.id}'),
                        child: const Text('Configure Gotify'),
                      ),
                    ],
                  ]),
                ))
              : _messages.isEmpty
                  ? const Center(child: Text('No notifications', style: TextStyle(color: Color(0xFF888888))))
                  : ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final date = DateTime.tryParse(m['date'] as String? ?? '');
                        final priority = (m['priority'] as num?)?.toInt() ?? 1;
                        return ListTile(
                          leading: _PriorityDot(priority),
                          title: Text(m['title'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m['message'] as String? ?? ''),
                            if (date != null) Text(
                              DateFormat('MMM d, HH:mm').format(date.toLocal()),
                              style: const TextStyle(color: Color(0xFF666666), fontSize: 11),
                            ),
                          ]),
                          isThreeLine: true,
                        );
                      },
                    ),
    );
  }
}

class _PriorityDot extends StatelessWidget {
  const _PriorityDot(this.priority);
  final int priority;

  @override
  Widget build(BuildContext context) {
    final color = priority >= 8 ? const Color(0xFFFF5370)
        : priority >= 5 ? const Color(0xFFFFCB6B)
        : const Color(0xFF64FFDA);
    return Container(
      width: 10, height: 10, margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
