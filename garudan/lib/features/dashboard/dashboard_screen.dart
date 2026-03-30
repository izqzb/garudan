import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/server_profile.dart';
import '../../services/storage_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, required this.serverId});
  final String serverId;

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  ServerProfile? _profile;
  Map<String, dynamic>? _stats;
  String? _error;
  bool _loading = true;
  Timer? _timer;
  late Dio _dio;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final profiles = await ref.read(storageServiceProvider).getServerProfiles();
    try {
      _profile = profiles.firstWhere((p) => p.id == widget.serverId);
    } catch (_) {
      if (mounted) setState(() { _error = 'Server not found'; _loading = false; });
      return;
    }

    _dio = Dio(BaseOptions(
      baseUrl: _profile!.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: _profile!.apiToken != null
          ? {'Authorization': 'Bearer ${_profile!.apiToken}'}
          : {},
    ));

    await _fetchStats();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchStats());
  }

  Future<void> _fetchStats() async {
    if (_profile == null) return;
    try {
      final resp = await _dio.get<dynamic>('/api/system/stats');
      if (mounted) {
        setState(() {
          _stats = resp.data as Map<String, dynamic>;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null && _loading) {
      return const Scaffold(backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _stats == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, title: const Text('Dashboard')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off, size: 48, color: Color(0xFFFF5370)),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xFF888888))),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _fetchStats, child: const Text('Retry')),
          ]),
        ),
      );
    }

    final cpu = (_stats?['cpu'] as Map?)?.cast<String, dynamic>() ?? {};
    final mem = (_stats?['memory'] as Map?)?.cast<String, dynamic>() ?? {};
    final disk = (_stats?['disk'] as Map?)?.cast<String, dynamic>() ?? {};
    final uptime = (_stats?['uptime_seconds'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(_profile?.name ?? 'Dashboard'),
        actions: [
          if (_error != null)
            const Icon(Icons.wifi_off, color: Color(0xFFFF5370), size: 18),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStats,
          ),
        ],
      ),
      body: _stats == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Quick actions
                _QuickActions(profile: _profile!, serverId: widget.serverId),
                const SizedBox(height: 20),

                // Stats grid
                Text('System', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _uptimeCard(uptime),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _GaugeCard('CPU', (cpu['percent'] as num?)?.toDouble() ?? 0, '%', color: const Color(0xFF7C83FD))),
                  const SizedBox(width: 10),
                  Expanded(child: _GaugeCard('RAM', (mem['percent'] as num?)?.toDouble() ?? 0, '%', color: const Color(0xFF64FFDA))),
                ]),
                const SizedBox(height: 10),
                _diskCard(disk),
                const SizedBox(height: 10),
                if (cpu['per_core'] != null) _coresCard(cpu['per_core'] as List),
              ],
            ),
    );
  }

  Widget _uptimeCard(double seconds) {
    final d = Duration(seconds: seconds.toInt());
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    return _Card(
      child: Row(children: [
        const Icon(Icons.access_time, color: Color(0xFF7C83FD), size: 20),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Uptime', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
          Text('${days}d ${hours}h ${mins}m',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }

  Widget _diskCard(Map<String, dynamic> disk) {
    final used = (disk['used'] as num?)?.toInt() ?? 0;
    final total = (disk['total'] as num?)?.toInt() ?? 1;
    final pct = (disk['percent'] as num?)?.toDouble() ?? 0;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Disk', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
          Text('${(used / 1e9).toStringAsFixed(1)} / ${(total / 1e9).toStringAsFixed(1)} GB',
            style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(
              pct > 90 ? const Color(0xFFFF5370)
                  : pct > 75 ? const Color(0xFFFFCB6B)
                  : const Color(0xFFFFCB6B),
            ),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text('${pct.toStringAsFixed(1)}% used',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _coresCard(List cores) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('CPU Cores', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: cores.asMap().entries.map((e) {
            final pct = (e.value as num).toDouble();
            return Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                width: 28, height: 28,
                child: CircularProgressIndicator(
                  value: pct / 100,
                  strokeWidth: 3,
                  backgroundColor: const Color(0xFF2A2A2A),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF7C83FD)),
                ),
              ),
              const SizedBox(height: 4),
              Text('${pct.toInt()}%',
                style: const TextStyle(color: Color(0xFF888888), fontSize: 10)),
            ]);
          }).toList(),
        ),
      ]),
    );
  }
}

class _GaugeCard extends StatelessWidget {
  const _GaugeCard(this.label, this.value, this.unit, {this.color = const Color(0xFF7C83FD)});
  final String label;
  final double value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        const SizedBox(height: 8),
        Text('${value.toStringAsFixed(1)}$unit',
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: const Color(0xFF2A2A2A),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: child,
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.profile, required this.serverId});
  final ServerProfile profile;
  final String serverId;

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Terminal', Icons.terminal, () => context.push('/terminal/$serverId', extra: profile)),
      ('Docker', Icons.widgets_outlined, () => context.go('/docker/$serverId')),
      ('Files', Icons.folder_outlined, () => context.go('/files/$serverId')),
      ('Processes', Icons.monitor_heart_outlined, () => context.go('/processes/$serverId')),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: actions.map((a) => _ActionTile(a.$1, a.$2, a.$3)).toList(),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(this.label, this.icon, this.onTap);
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: const Color(0xFF7C83FD), size: 24),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 11)),
        ]),
      ),
    );
  }
}
