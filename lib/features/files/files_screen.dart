import 'dart:async';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/server_profile.dart';
import '../../services/storage_service.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key, required this.serverId});
  final String serverId;
  @override
  ConsumerState<FilesScreen> createState() => _State();
}

class _State extends ConsumerState<FilesScreen> {
  ServerProfile? _profile;
  Dio? _dio;
  List<Map<String,dynamic>> _entries = [];
  bool _loading = true;
  String? _error;
  String _path = '/';
  final List<String> _crumbs = ['/'];

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    final profiles = await ref.read(storageServiceProvider).getServerProfiles();
    try { _profile = profiles.firstWhere((p) => p.id == widget.serverId); }
    catch (_) { setState(() { _error = 'Server not found'; _loading = false; }); return; }
    _dio = Dio(BaseOptions(
      baseUrl: _profile!.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      headers: _profile!.apiToken != null ? {'Authorization': 'Bearer ${_profile!.apiToken}'} : {},
    ));
    await _list(_path);
  }

  Future<void> _list(String path) async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _dio!.get<dynamic>('/api/files/list', queryParameters: {'path': path});
      setState(() { _entries = (r.data['entries'] as List).cast<Map<String,dynamic>>(); _path = path; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  void _navigate(Map<String,dynamic> e) {
    if (e['is_dir'] == true) {
      _crumbs.add(e['path'] as String);
      _list(e['path'] as String);
    } else {
      _openFile(e);
    }
  }

  void _back() {
    if (_crumbs.length <= 1) return;
    _crumbs.removeLast();
    _list(_crumbs.last);
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
      });
      await _dio!.post<dynamic>('/api/files/upload', data: formData, queryParameters: {'path': _path});
      await _list(_path);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Uploaded ${file.name}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> _newFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await _dio!.post<dynamic>('/api/files/mkdir', queryParameters: {'path': _path, 'name': name});
      await _list(_path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  void _openFile(Map<String,dynamic> entry) {
    final mime = (entry['mime'] as String?) ?? '';
    final isText = mime.startsWith('text/') || mime.contains('json') || mime.contains('xml') ||
        mime.contains('javascript') || mime.contains('yaml') || mime.contains('script') ||
        (entry['name'] as String).contains('.');
    if (!isText) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Binary file — download only'))); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => _EditorScreen(dio: _dio!, entry: entry)));
  }

  void _longPressMenu(Map<String,dynamic> entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text(entry['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600))),
        ListTile(leading: const Icon(Icons.drive_file_rename_outline, color: Color(0xFF7C83FD)), title: const Text('Rename'),
          onTap: () { Navigator.pop(context); _rename(entry); }),
        ListTile(leading: const Icon(Icons.delete_outline, color: Color(0xFFFF5370)), title: const Text('Delete', style: TextStyle(color: Color(0xFFFF5370))),
          onTap: () { Navigator.pop(context); _delete(entry); }),
        const SizedBox(height: 16),
      ]),
    );
  }

  Future<void> _rename(Map<String,dynamic> entry) async {
    final ctrl = TextEditingController(text: entry['name'] as String);
    final name = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Rename'),
      content: TextField(controller: ctrl, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Rename')),
      ],
    ));
    if (name == null || name.isEmpty) return;
    try {
      await _dio!.post<dynamic>('/api/files/rename', queryParameters: {'path': entry['path'], 'new_name': name});
      await _list(_path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rename failed: $e')));
    }
  }

  Future<void> _delete(Map<String,dynamic> entry) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete'),
      content: Text('Delete "${entry['name']}"?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Color(0xFFFF5370)))),
      ],
    ));
    if (confirm != true) return;
    try {
      await _dio!.delete<dynamic>('/api/files/delete', queryParameters: {'path': entry['path']});
      await _list(_path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  String _size(int b) {
    if (b < 1024) return '$b B';
    if (b < 1048576) return '${(b/1024).toStringAsFixed(1)} KB';
    if (b < 1073741824) return '${(b/1048576).toStringAsFixed(1)} MB';
    return '${(b/1073741824).toStringAsFixed(1)} GB';
  }

  IconData _icon(Map<String,dynamic> e) {
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
    return PopScope(
      canPop: _crumbs.length <= 1,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _back(); },
      child: Scaffold(
        appBar: AppBar(
          leading: _crumbs.length > 1
              ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back)
              : IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Files', style: TextStyle(fontSize: 16)),
            Text(_path, style: const TextStyle(fontSize: 11, color: Color(0xFF666666), fontFamily: 'monospace'), overflow: TextOverflow.ellipsis),
          ]),
          actions: [
            IconButton(icon: const Icon(Icons.create_new_folder_outlined), tooltip: 'New folder', onPressed: _newFolder),
            IconButton(icon: const Icon(Icons.upload_file), tooltip: 'Upload file', onPressed: _upload),
            IconButton(icon: const Icon(Icons.refresh), onPressed: () => _list(_path)),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _entries.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: Color(0xFF444444)),
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Color(0xFF888888))),
                    const SizedBox(height: 16),
                    OutlinedButton(onPressed: () => _list(_path), child: const Text('Retry')),
                  ]))
                : _entries.isEmpty
                    ? const Center(child: Text('Empty directory', style: TextStyle(color: Color(0xFF555555))))
                    : ListView.separated(
                        itemCount: _entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 52),
                        itemBuilder: (_, i) {
                          final e = _entries[i];
                          final isDir = e['is_dir'] == true;
                          return ListTile(
                            leading: Icon(_icon(e), color: isDir ? const Color(0xFF7C83FD) : const Color(0xFF888888)),
                            title: Text(e['name'] as String, style: const TextStyle(fontSize: 14)),
                            subtitle: isDir ? null : Text(_size((e['size'] as num).toInt()),
                              style: const TextStyle(color: Color(0xFF555555), fontSize: 11)),
                            trailing: isDir ? const Icon(Icons.chevron_right, color: Color(0xFF444444)) : null,
                            onTap: () => _navigate(e),
                            onLongPress: () => _longPressMenu(e),
                          );
                        },
                      ),
      ),
    );
  }
}

// ── Text Editor ───────────────────────────────────────────────────────────────

class _EditorScreen extends StatefulWidget {
  const _EditorScreen({required this.dio, required this.entry});
  final Dio dio; final Map<String,dynamic> entry;
  @override State<_EditorScreen> createState() => _EditorState();
}

class _EditorState extends State<_EditorScreen> {
  String _content = '';
  bool _loading = true, _saving = false, _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() { super.initState(); _ctrl = TextEditingController(); _load(); }

  Future<void> _load() async {
    try {
      final r = await widget.dio.get<dynamic>('/api/files/read', queryParameters: {'path': widget.entry['path']});
      _content = (r.data as Map)['content'] as String? ?? '';
      _ctrl.text = _content;
      setState(() => _loading = false);
    } catch (e) { setState(() { _loading = false; _content = 'Error: $e'; }); }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.dio.post<dynamic>('/api/files/write',
        queryParameters: {'path': widget.entry['path']},
        data: _ctrl.text,
        options: Options(contentType: 'text/plain'),
      );
      _content = _ctrl.text;
      setState(() { _saving = false; _editing = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved ✓')));
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  String _lang() {
    final name = widget.entry['name'] as String;
    if (name.endsWith('.py')) return 'python';
    if (name.endsWith('.dart')) return 'dart';
    if (name.endsWith('.js') || name.endsWith('.ts')) return 'javascript';
    if (name.endsWith('.sh') || name.endsWith('.bash')) return 'bash';
    if (name.endsWith('.json')) return 'json';
    if (name.endsWith('.yaml') || name.endsWith('.yml')) return 'yaml';
    if (name.endsWith('.html')) return 'html';
    if (name.endsWith('.css')) return 'css';
    if (name.endsWith('.xml')) return 'xml';
    if (name.endsWith('.md')) return 'markdown';
    if (name.endsWith('.go')) return 'go';
    if (name.endsWith('.rs')) return 'rust';
    return 'plaintext';
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry['name'] as String),
        actions: [
          if (!_editing)
            IconButton(icon: const Icon(Icons.edit), tooltip: 'Edit', onPressed: () => setState(() => _editing = true))
          else ...[
            IconButton(icon: const Icon(Icons.close), onPressed: () { _ctrl.text = _content; setState(() => _editing = false); }),
            if (_saving)
              const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            else
              IconButton(icon: const Icon(Icons.save, color: Color(0xFF64FFDA)), onPressed: _save),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _editing
              ? TextField(
                  controller: _ctrl,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.white),
                  decoration: const InputDecoration(
                    filled: true, fillColor: Color(0xFF000000),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                )
              : SingleChildScrollView(
                  child: HighlightView(
                    _content,
                    language: _lang(),
                    theme: atomOneDarkTheme,
                    padding: const EdgeInsets.all(16),
                    textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
                  ),
                ),
    );
  }
}
