import 'dart:async';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/server_profile.dart';
import '../../services/storage_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key, required this.serverId});
  final String serverId;
  @override
  ConsumerState<DashboardScreen> createState() => _State();
}

class _State extends ConsumerState<DashboardScreen> {
  ServerProfile? _profile;
  Map<String, dynamic>? _stats;
  String? _error;
  bool _loading = true;
  Timer? _timer;
  Dio? _dio;

  // Graph history
  final List<double> _cpuHistory  = [];
  final List<double> _ramHistory  = [];
  final List<double> _diskHistory = [];
  static const _maxPoints = 20;

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    final profiles = await ref.read(storageServiceProvider).getServerProfiles();
    try { _profile = profiles.firstWhere((p) => p.id == widget.serverId); }
    catch (_) { setState(() { _error = 'Server not found'; _loading = false; }); return; }
    _dio = Dio(BaseOptions(
      baseUrl: _profile!.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      headers: _profile!.apiToken != null ? {'Authorization': 'Bearer ${_profile!.apiToken}'} : {},
    ));
    await _fetch();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final r = await _dio!.get<dynamic>('/api/system/stats');
      final data = r.data as Map<String, dynamic>;
      final cpu  = (data['cpu']?['percent']    as num?)?.toDouble() ?? 0;
      final ram  = (data['memory']?['percent'] as num?)?.toDouble() ?? 0;
      final disk = (data['disk']?['percent']   as num?)?.toDouble() ?? 0;

      if (_cpuHistory.length >= _maxPoints)  _cpuHistory.removeAt(0);
      if (_ramHistory.length >= _maxPoints)  _ramHistory.removeAt(0);
      if (_diskHistory.length >= _maxPoints) _diskHistory.removeAt(0);
      _cpuHistory.add(cpu); _ramHistory.add(ram); _diskHistory.add(disk);

      if (mounted) setState(() { _stats = data; _error = null; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_profile?.name ?? 'Dashboard'),
          leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
          actions: [
            if (_profile?.gotifyUrl != null)
              IconButton(icon: const Icon(Icons.notifications_outlined),
                onPressed: () => context.push('/notifications/${widget.serverId}')),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
          ],
        ),
        body: _error != null && _stats == null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off, size: 48, color: Color(0xFFFF5370)),
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFF888888)), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(onPressed: _fetch, child: const Text('Retry')),
              ]))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _QuickActions(profile: _profile!, serverId: widget.serverId),
                  const SizedBox(height: 20),
                  _uptimeCard(),
                  const SizedBox(height: 12),
                  // CPU Graph
                  _GraphCard('CPU', _cpuHistory, const Color(0xFF7C83FD),
                    ((_stats?['cpu']?['percent'] as num?)?.toDouble() ?? 0)),
                  const SizedBox(height: 12),
                  // RAM Graph
                  _GraphCard('RAM', _ramHistory, const Color(0xFF64FFDA),
                    ((_stats?['memory']?['percent'] as num?)?.toDouble() ?? 0)),
                  const SizedBox(height: 12),
                  // Disk
                  _diskCard(),
                  const SizedBox(height: 12),
                  // Temps if available
                  if (_stats?['temperatures'] != null) _tempsCard(),
                ],
              ),
      ),
    );
  }

  Widget _uptimeCard() {
    final secs = (_stats?['uptime_seconds'] as num?)?.toInt() ?? 0;
    final d = Duration(seconds: secs);
    return _Card(child: Row(children: [
      const Icon(Icons.access_time, color: Color(0xFF7C83FD), size: 20),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Uptime', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
        Text('${d.inDays}d ${d.inHours % 24}h ${d.inMinutes % 60}m',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ]),
      const Spacer(),
      if (_error != null) const Icon(Icons.wifi_off, color: Color(0xFFFFCB6B), size: 16),
    ]));
  }

  Widget _diskCard() {
    final disk = (_stats?['disk'] as Map?)?.cast<String, dynamic>() ?? {};
    final used  = (disk['used']    as num?)?.toInt() ?? 0;
    final total = (disk['total']   as num?)?.toInt() ?? 1;
    final pct   = (disk['percent'] as num?)?.toDouble() ?? 0;
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            pct > 90 ? const Color(0xFFFF5370) : pct > 75 ? const Color(0xFFFFCB6B) : const Color(0xFF7C83FD)),
          minHeight: 10,
        ),
      ),
      const SizedBox(height: 6),
      Text('${pct.toStringAsFixed(1)}% used',
        style: const TextStyle(fontWeight: FontWeight.w600)),
    ]));
  }

  Widget _tempsCard() {
    final temps = _stats!['temperatures'] as Map<String, dynamic>;
    final entries = <String>[];
    temps.forEach((key, val) {
      for (final e in (val as List)) {
        final label = (e['label'] as String?)?.isNotEmpty == true ? e['label'] : key;
        final cur = (e['current'] as num?)?.toDouble() ?? 0;
        if (cur > 0) entries.add('$label: ${cur.toStringAsFixed(1)}°C');
      }
    });
    if (entries.isEmpty) return const SizedBox.shrink();
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Temperatures', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 6, children: entries.map((e) => _TempChip(e)).toList()),
    ]));
  }
}

class _GraphCard extends StatelessWidget {
  const _GraphCard(this.label, this.history, this.color, this.current);
  final String label;
  final List<double> history;
  final Color color;
  final double current;

  @override
  Widget build(BuildContext context) {
    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        Text('${current.toStringAsFixed(1)}%',
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 20)),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 60,
        child: history.length < 2
            ? const Center(child: Text('Collecting data...', style: TextStyle(color: Color(0xFF444444), fontSize: 12)))
            : LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minX: 0, maxX: (history.length - 1).toDouble(),
                  minY: 0, maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                  lineTouchData: const LineTouchData(enabled: false),
                ),
              ),
      ),
    ]));
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
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

class _TempChip extends StatelessWidget {
  const _TempChip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1C1C),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFF2A2A2A)),
    ),
    child: Text(label, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFFB0B0B0))),
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.profile, required this.serverId});
  final ServerProfile profile;
  final String serverId;

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Terminal',  Icons.terminal,              () => context.push('/terminal/$serverId', extra: profile)),
      ('Docker',    Icons.widgets_outlined,       () => context.push('/docker/$serverId')),
      ('Files',     Icons.folder_outlined,        () => context.push('/files/$serverId')),
      ('Processes', Icons.monitor_heart_outlined, () => context.push('/processes/$serverId')),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: actions.map((a) => GestureDetector(
        onTap: a.$3,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(a.$2, color: const Color(0xFF7C83FD), size: 24),
            const SizedBox(height: 6),
            Text(a.$1, style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 11)),
          ]),
        ),
      )).toList(),
    );
  }
}
