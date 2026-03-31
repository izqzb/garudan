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
  ConsumerState<DockerScreen> createState() => _State();
}

class _State extends ConsumerState<DockerScreen> {
  ServerProfile? _profile;
  List<Map<String, dynamic>> _containers = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;
  Dio? _dio;
  String _filter = 'all';

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
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final r = await _dio!.get<dynamic>('/api/docker/containers', queryParameters: {'all': true});
      if (mounted) setState(() { _containers = (r.data as List).cast<Map<String,dynamic>>(); _error = null; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _action(String id, String action) async {
    try {
      await _dio!.post<dynamic>('/api/docker/containers/$id/action', data: {'action': action});
      await _fetch();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$action failed')));
    }
  }

  List<Map<String,dynamic>> get _filtered {
    if (_filter == 'running') return _containers.where((c) => c['status'] == 'running').toList();
    if (_filter == 'stopped') return _containers.where((c) => c['status'] != 'running').toList();
    return _containers;
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
          title: const Text('Docker'),
          actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch)],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(children: ['all','running','stopped'].map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f[0].toUpperCase() + f.substring(1)),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: const Color(0xFF7C83FD).withValues(alpha: 0.2),
                  checkmarkColor: const Color(0xFF7C83FD),
                  labelStyle: TextStyle(color: _filter == f ? const Color(0xFF7C83FD) : const Color(0xFF888888), fontSize: 12),
                ),
              )).toList()),
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _containers.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: Color(0xFF444444)),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Color(0xFF888888))),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: _fetch, child: const Text('Retry')),
                  ]))
                : _filtered.isEmpty
                    ? const Center(child: Text('No containers', style: TextStyle(color: Color(0xFF555555))))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _ContainerCard(
                          data: _filtered[i],
                          onAction: _action,
                          onLogs: (id) => _showLogs(id),
                          onLongPress: (id) => _quickSheet(id, _filtered[i]),
                        ),
                      ),
      ),
    );
  }

  void _showLogs(String id) => showModalBottomSheet(
    context: context, isScrollControlled: true,
    backgroundColor: const Color(0xFF0D0D0D),
    builder: (_) => _LogsSheet(dio: _dio!, id: id),
  );

  void _quickSheet(String id, Map<String,dynamic> data) {
    final running = data['status'] == 'running';
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(data['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
        ListTile(leading: Icon(running ? Icons.stop : Icons.play_arrow, color: running ? const Color(0xFFFF5370) : const Color(0xFF64FFDA)),
          title: Text(running ? 'Stop' : 'Start'), onTap: () { Navigator.pop(context); _action(id, running ? 'stop' : 'start'); }),
        ListTile(leading: const Icon(Icons.restart_alt, color: Color(0xFFFFCB6B)),
          title: const Text('Restart'), onTap: () { Navigator.pop(context); _action(id, 'restart'); }),
        ListTile(leading: const Icon(Icons.article_outlined, color: Color(0xFF7C83FD)),
          title: const Text('View Logs'), onTap: () { Navigator.pop(context); _showLogs(id); }),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _ContainerCard extends StatelessWidget {
  const _ContainerCard({required this.data, required this.onAction, required this.onLogs, required this.onLongPress});
  final Map<String,dynamic> data;
  final Future<void> Function(String,String) onAction;
  final void Function(String) onLogs, onLongPress;

  bool get _running => data['status'] == 'running';

  @override
  Widget build(BuildContext context) {
    final id = data['id'] as String;
    final name = data['name'] as String? ?? id;
    final image = data['image'] as String? ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onLongPress: () => onLongPress(id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle,
                color: _running ? const Color(0xFF64FFDA) : const Color(0xFFFF5370))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(image, style: const TextStyle(color: Color(0xFF666666), fontSize: 11, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
              ])),
              _statusChip(data['status'] as String? ?? ''),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _Btn(_running ? Icons.stop : Icons.play_arrow, _running ? 'Stop' : 'Start',
                _running ? const Color(0xFFFF5370) : const Color(0xFF64FFDA),
                () => onAction(id, _running ? 'stop' : 'start')),
              const SizedBox(width: 8),
              _Btn(Icons.restart_alt, 'Restart', const Color(0xFFFFCB6B), () => onAction(id, 'restart')),
              const SizedBox(width: 8),
              _Btn(Icons.article_outlined, 'Logs', const Color(0xFF7C83FD), () => onLogs(id)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = status == 'running' ? const Color(0xFF64FFDA) : status == 'paused' ? const Color(0xFFFFCB6B) : const Color(0xFFFF5370);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.icon, this.label, this.color, this.onTap);
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color), const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

class _LogsSheet extends StatefulWidget {
  const _LogsSheet({required this.dio, required this.id});
  final Dio dio; final String id;
  @override State<_LogsSheet> createState() => _LogsSheetState();
}

class _LogsSheetState extends State<_LogsSheet> {
  String _logs = 'Loading...';
  final _scroll = ScrollController();

  @override
  void initState() { super.initState(); _fetch(); }

  Future<void> _fetch() async {
    try {
      final r = await widget.dio.get<dynamic>('/api/docker/containers/${widget.id}/logs', queryParameters: {'tail': 200});
      final logs = (r.data as Map)['logs'] as String? ?? '';
      if (mounted) {
        setState(() => _logs = logs);
        WidgetsBinding.instance.addPostFrameCallback((_) { if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent); });
      }
    } catch (e) { if (mounted) setState(() => _logs = 'Error: $e'); }
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.7, maxChildSize: 0.95, minChildSize: 0.3, expand: false,
    builder: (_, sc) => Column(children: [
      Container(height: 4, width: 40, margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(2))),
      Padding(padding: const EdgeInsets.fromLTRB(16, 0, 8, 8), child: Row(children: [
        const Text('Logs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF888888)), onPressed: _fetch),
      ])),
      Expanded(child: SingleChildScrollView(controller: _scroll, padding: const EdgeInsets.all(12),
        child: SelectableText(_logs, style: const TextStyle(color: Color(0xFFC0C0C0), fontFamily: 'monospace', fontSize: 11, height: 1.5)))),
    ]),
  );
}
