import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/server_profile.dart';
import '../../services/storage_service.dart';

class DockerScreen extends ConsumerStatefulWidget {
  const DockerScreen({super.key, required this.serverId});
  final String serverId;
  @override
  ConsumerState<DockerScreen> createState() => _DockerScreenState();
}

class _DockerScreenState extends ConsumerState<DockerScreen> {
  ServerProfile? _profile;
  List<Map<String, dynamic>> _containers = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;
  Dio? _dio;
  String _filter = 'all'; // all | running | stopped

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    final profiles = await ref.read(storageServiceProvider).getServerProfiles();
    try { _profile = profiles.firstWhere((p) => p.id == widget.serverId); }
    catch (_) { setState(() { _error = 'Server not found'; _loading = false; }); return; }
    _dio = Dio(BaseOptions(
      baseUrl: _profile!.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: _profile!.apiToken != null ? {'Authorization': 'Bearer ${_profile!.apiToken}'} : {},
    ));
    await _fetch();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final r = await _dio!.get<dynamic>('/api/docker/containers', queryParameters: {'all': true});
      final list = (r.data as List).cast<Map<String, dynamic>>();
      if (mounted) setState(() { _containers = list; _error = null; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _action(String id, String action) async {
    try {
      await _dio!.post<dynamic>('/api/docker/containers/$id/action', data: {'action': action});
      await _fetch();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$action failed: $e')));
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'running') return _containers.where((c) => c['status'] == 'running').toList();
    if (_filter == 'stopped') return _containers.where((c) => c['status'] != 'running').toList();
    return _containers;
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: const Text('Docker'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: _FilterChips(current: _filter, onChange: (f) => setState(() => _filter = f)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _containers.isEmpty
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFF888888))))
              : _filtered.isEmpty
                  ? const Center(child: Text('No containers', style: TextStyle(color: Color(0xFF555555))))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) => _ContainerCard(
                        data: _filtered[i],
                        onAction: _action,
                        onLogs: (id) => _showLogs(id),
                      ),
                    ),
    );
  }

  void _showLogs(String id) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _LogsSheet(dio: _dio!, containerId: id),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.current, required this.onChange});
  final String current;
  final void Function(String) onChange;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          for (final f in ['all', 'running', 'stopped'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(f[0].toUpperCase() + f.substring(1)),
                selected: current == f,
                onSelected: (_) => onChange(f),
                selectedColor: const Color(0xFF7C83FD).withOpacity(0.2),
                checkmarkColor: const Color(0xFF7C83FD),
                labelStyle: TextStyle(
                  color: current == f ? const Color(0xFF7C83FD) : const Color(0xFF888888),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContainerCard extends StatelessWidget {
  const _ContainerCard({required this.data, required this.onAction, required this.onLogs});
  final Map<String, dynamic> data;
  final Future<void> Function(String, String) onAction;
  final void Function(String) onLogs;

  bool get _running => data['status'] == 'running';

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String;
    final name = data['name'] as String? ?? id;
    final image = data['image'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _running ? const Color(0xFF64FFDA) : const Color(0xFFFF5370),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text(image, style: const TextStyle(color: Color(0xFF666666), fontSize: 11, fontFamily: 'monospace')),
              ]),
            ),
            _statusChip(data['status'] as String? ?? ''),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _ActionBtn(
              icon: _running ? Icons.stop : Icons.play_arrow,
              label: _running ? 'Stop' : 'Start',
              color: _running ? const Color(0xFFFF5370) : const Color(0xFF64FFDA),
              onTap: () => onAction(id, _running ? 'stop' : 'start'),
            ),
            const SizedBox(width: 8),
            _ActionBtn(
              icon: Icons.restart_alt,
              label: 'Restart',
              color: const Color(0xFFFFCB6B),
              onTap: () => onAction(id, 'restart'),
            ),
            const SizedBox(width: 8),
            _ActionBtn(
              icon: Icons.article_outlined,
              label: 'Logs',
              color: const Color(0xFF7C83FD),
              onTap: () => onLogs(id),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'running' ? const Color(0xFF64FFDA)
        : status == 'paused' ? const Color(0xFFFFCB6B)
        : const Color(0xFFFF5370);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _LogsSheet extends StatefulWidget {
  const _LogsSheet({required this.dio, required this.containerId});
  final Dio dio;
  final String containerId;
  @override
  State<_LogsSheet> createState() => _LogsSheetState();
}

class _LogsSheetState extends State<_LogsSheet> {
  String _logs = 'Loading...';
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final r = await widget.dio.get<dynamic>(
        '/api/docker/containers/${widget.containerId}/logs',
        queryParameters: {'tail': 200},
      );
      final logs = (r.data as Map)['logs'] as String? ?? '';
      if (mounted) {
        setState(() => _logs = logs);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _logs = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.3,
      expand: false,
      builder: (_, sc) => Column(children: [
        Container(
          height: 4, width: 40,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF444444),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Logs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
            IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF888888)), onPressed: _fetch),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              _logs,
              style: const TextStyle(
                color: Color(0xFFC0C0C0),
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
