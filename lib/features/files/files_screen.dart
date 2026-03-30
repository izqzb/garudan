import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/server_profile.dart';
import '../../services/storage_service.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key, required this.serverId});
  final String serverId;
  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  ServerProfile? _profile;
  Dio? _dio;
  List<Map<String, dynamic>> _entries = [];
  bool _loading = true;
  String? _error;
  String _currentPath = '/';
  final List<String> _breadcrumbs = ['/'];

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    final profiles = await ref.read(storageServiceProvider).getServerProfiles();
    try { _profile = profiles.firstWhere((p) => p.id == widget.serverId); }
    catch (_) { setState(() { _error = 'Server not found'; _loading = false; }); return; }
    _dio = Dio(BaseOptions(
      baseUrl: _profile!.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: _profile!.apiToken != null ? {'Authorization': 'Bearer ${_profile!.apiToken}'} : {},
    ));
    await _list(_currentPath);
  }

  Future<void> _list(String path) async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _dio!.get<dynamic>('/api/files/list', queryParameters: {'path': path});
      final data = r.data as Map;
      setState(() {
        _entries = (data['entries'] as List).cast<Map<String, dynamic>>();
        _currentPath = path;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _navigate(Map<String, dynamic> entry) {
    if (entry['is_dir'] == true) {
      _breadcrumbs.add(entry['path'] as String);
      _list(entry['path'] as String);
    }
  }

  void _goBack() {
    if (_breadcrumbs.length <= 1) return;
    _breadcrumbs.removeLast();
    _list(_breadcrumbs.last);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }

  IconData _icon(Map<String, dynamic> e) {
    if (e['is_dir'] == true) return Icons.folder;
    final mime = (e['mime'] as String?) ?? '';
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.startsWith('video/')) return Icons.videocam_outlined;
    if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mime.contains('zip') || mime.contains('tar') || mime.contains('gz')) return Icons.archive_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: _breadcrumbs.length > 1
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
            : IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Files', style: TextStyle(fontSize: 16)),
          Text(_currentPath,
            style: const TextStyle(fontSize: 11, color: Color(0xFF666666), fontFamily: 'monospace'),
            overflow: TextOverflow.ellipsis,
          ),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _list(_currentPath)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _entries.isEmpty
              ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFF888888))))
              : _entries.isEmpty
                  ? const Center(child: Text('Empty directory', style: TextStyle(color: Color(0xFF555555))))
                  : ListView.separated(
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 52),
                      itemBuilder: (ctx, i) {
                        final e = _entries[i];
                        final isDir = e['is_dir'] == true;
                        return ListTile(
                          leading: Icon(_icon(e),
                            color: isDir ? const Color(0xFF7C83FD) : const Color(0xFF888888)),
                          title: Text(e['name'] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 14)),
                          subtitle: isDir ? null : Text(
                            _formatSize((e['size'] as num).toInt()),
                            style: const TextStyle(color: Color(0xFF555555), fontSize: 11),
                          ),
                          trailing: isDir
                              ? const Icon(Icons.chevron_right, color: Color(0xFF444444))
                              : IconButton(
                                  icon: const Icon(Icons.download_outlined, size: 18, color: Color(0xFF666666)),
                                  onPressed: () => _downloadFile(e),
                                ),
                          onTap: () => _navigate(e),
                        );
                      },
                    ),
    );
  }

  void _downloadFile(Map<String, dynamic> entry) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download: ${entry['name']} (coming soon)')),
    );
  }
}
