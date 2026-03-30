import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/server_profile.dart';
import '../../services/storage_service.dart';

class ProcessesScreen extends ConsumerStatefulWidget {
  const ProcessesScreen({super.key, required this.serverId});
  final String serverId;
  @override
  ConsumerState<ProcessesScreen> createState() => _ProcessesScreenState();
}

class _ProcessesScreenState extends ConsumerState<ProcessesScreen> {
  ServerProfile? _profile;
  Dio? _dio;
  List<Map<String, dynamic>> _procs = [];
  bool _loading = true;
  String? _error;
  String _sort = 'cpu';
  Timer? _timer;

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
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetch());
  }

  Future<void> _fetch() async {
    try {
      final r = await _dio!.get<dynamic>('/api/system/processes',
        queryParameters: {'sort': _sort, 'limit': 50});
      if (mounted) setState(() {
        _procs = (r.data as List).cast<Map<String, dynamic>>();
        _loading = false; _error = null;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
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
        title: const Text('Processes'),
        actions: [
          DropdownButton<String>(
            value: _sort,
            dropdownColor: const Color(0xFF1C1C1C),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'cpu', child: Text('Sort: CPU', style: TextStyle(color: Colors.white, fontSize: 13))),
              DropdownMenuItem(value: 'mem', child: Text('Sort: MEM', style: TextStyle(color: Colors.white, fontSize: 13))),
            ],
            onChanged: (v) { setState(() => _sort = v!); _fetch(); },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _procs.isEmpty
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFF888888))))
              : Column(children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFF0D0D0D),
                    child: const Row(children: [
                      SizedBox(width: 50, child: Text('PID', style: TextStyle(color: Color(0xFF666666), fontSize: 11))),
                      Expanded(child: Text('Name', style: TextStyle(color: Color(0xFF666666), fontSize: 11))),
                      SizedBox(width: 50, child: Text('CPU%', style: TextStyle(color: Color(0xFF666666), fontSize: 11), textAlign: TextAlign.right)),
                      SizedBox(width: 50, child: Text('MEM%', style: TextStyle(color: Color(0xFF666666), fontSize: 11), textAlign: TextAlign.right)),
                    ]),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _procs.length,
                      itemBuilder: (ctx, i) {
                        final p = _procs[i];
                        final cpu = (p['cpu'] as num).toDouble();
                        final mem = (p['mem'] as num).toDouble();
                        return InkWell(
                          onLongPress: () => _killDialog(p),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(children: [
                              SizedBox(width: 50, child: Text('${p['pid']}',
                                style: const TextStyle(color: Color(0xFF555555), fontSize: 12, fontFamily: 'monospace'))),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p['name'] as String,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                                if ((p['username'] as String?)?.isNotEmpty == true)
                                  Text(p['username'] as String,
                                    style: const TextStyle(color: Color(0xFF555555), fontSize: 11)),
                              ])),
                              SizedBox(width: 50, child: Text('${cpu.toStringAsFixed(1)}',
                                style: TextStyle(
                                  color: cpu > 50 ? const Color(0xFFFF5370)
                                      : cpu > 20 ? const Color(0xFFFFCB6B)
                                      : const Color(0xFF888888),
                                  fontSize: 12, fontFamily: 'monospace',
                                ),
                                textAlign: TextAlign.right)),
                              SizedBox(width: 50, child: Text('${mem.toStringAsFixed(1)}',
                                style: TextStyle(
                                  color: mem > 20 ? const Color(0xFFFF5370)
                                      : mem > 10 ? const Color(0xFFFFCB6B)
                                      : const Color(0xFF888888),
                                  fontSize: 12, fontFamily: 'monospace',
                                ),
                                textAlign: TextAlign.right)),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ]),
    );
  }

  void _killDialog(Map<String, dynamic> p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kill Process'),
        content: Text('Send SIGTERM to "${p['name']}" (PID ${p['pid']})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _dio!.post<dynamic>('/api/system/processes/${p['pid']}/kill');
              await _fetch();
            },
            child: const Text('Kill', style: TextStyle(color: Color(0xFFFF5370))),
          ),
        ],
      ),
    );
  }
}
