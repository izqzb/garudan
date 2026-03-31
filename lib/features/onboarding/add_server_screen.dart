import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../models/server_profile.dart';
import '../../services/storage_service.dart';
import '../../core/constants.dart';

class AddServerScreen extends ConsumerStatefulWidget {
  const AddServerScreen({super.key, this.editId});
  final String? editId;
  @override
  ConsumerState<AddServerScreen> createState() => _State();
}

class _State extends ConsumerState<AddServerScreen> {
  final _form = GlobalKey<FormState>();
  bool _loading = false, _testOk = false;
  String? _testError;
  bool _showPass = false, _showToken = false;
  int _color = 0xFF7C83FD;
  bool _advancedExpanded = false;

  final _name      = TextEditingController(text: 'My Server');
  final _host      = TextEditingController();
  final _sshPort   = TextEditingController(text: '22');
  final _sshUser   = TextEditingController();
  final _sshPass   = TextEditingController();
  final _apiUrl    = TextEditingController();
  final _tsUrl     = TextEditingController();
  final _apiToken  = TextEditingController();
  final _netdata   = TextEditingController();
  final _gotifyUrl = TextEditingController();
  final _gotifyTok = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.editId != null) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final profiles = await ref.read(storageServiceProvider).getServerProfiles();
    try {
      final p = profiles.firstWhere((p) => p.id == widget.editId);
      setState(() {
        _name.text      = p.name;
        _host.text      = p.host;
        _sshPort.text   = p.port.toString();
        _sshUser.text   = p.sshUser;
        _sshPass.text   = p.sshPassword ?? '';
        _apiUrl.text    = p.apiBaseUrl;
        _tsUrl.text     = p.tailscaleUrl ?? '';
        _apiToken.text  = p.apiToken ?? '';
        _netdata.text   = p.netdataUrl ?? '';
        _gotifyUrl.text = p.gotifyUrl ?? '';
        _gotifyTok.text = p.gotifyToken ?? '';
        _color = p.color;
      });
    } catch (_) {}
  }

  Future<void> _test() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _testOk = false; _testError = null; });
    final url = '${_apiUrl.text.trim().replaceAll(RegExp(r"/$"), "")}/health';
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        headers: _apiToken.text.isNotEmpty ? {'Authorization': 'Bearer ${_apiToken.text.trim()}'} : {},
      ));
      final r = await dio.get<dynamic>(url);
      setState(() { _testOk = r.statusCode == 200; });
    } catch (e) {
      setState(() { _testError = e.toString().replaceAll(RegExp(r'DioException.*?:'), '').trim(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final p = ServerProfile(
      id: widget.editId ?? const Uuid().v4(),
      name: _name.text.trim(),
      host: _host.text.trim(),
      port: int.tryParse(_sshPort.text) ?? 22,
      sshUser: _sshUser.text.trim(),
      sshPassword: _sshPass.text.isEmpty ? null : _sshPass.text,
      apiBaseUrl: _apiUrl.text.trim().replaceAll(RegExp(r'/$'), ''),
      tailscaleUrl: _tsUrl.text.isEmpty ? null : _tsUrl.text.trim(),
      apiToken: _apiToken.text.isEmpty ? null : _apiToken.text.trim(),
      netdataUrl: _netdata.text.isEmpty ? null : _netdata.text.trim(),
      gotifyUrl: _gotifyUrl.text.isEmpty ? null : _gotifyUrl.text.trim(),
      gotifyToken: _gotifyTok.text.isEmpty ? null : _gotifyTok.text.trim(),
      color: _color,
      createdAt: DateTime.now(),
    );
    await ref.read(storageServiceProvider).addServerProfile(p);
    if (mounted) context.go('/servers');
  }

  @override
  void dispose() {
    for (final c in [_name,_host,_sshPort,_sshUser,_sshPass,_apiUrl,_tsUrl,_apiToken,_netdata,_gotifyUrl,_gotifyTok]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: Text(widget.editId != null ? 'Edit Server' : 'Add Server')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _Section('Server Details'),
              _Field('Name', _name, required: true),
              _Field('SSH Host / IP', _host, hint: '192.168.1.10 or domain.com', required: true),
              _Field('SSH Port', _sshPort, hint: '22', type: TextInputType.number),
              _Field('SSH Username', _sshUser, hint: 'ubuntu', required: true),
              _Field('SSH Password', _sshPass,
                hint: 'Leave empty if using SSH key auth',
                obscure: !_showPass,
                suffix: _eye(_showPass, () => setState(() => _showPass = !_showPass)),
              ),
              const SizedBox(height: 20),

              _Section('API Connection'),
              _installHint(),
              const SizedBox(height: 12),
              _Field('API Base URL', _apiUrl,
                hint: 'https://garuda.example.com or http://IP:8400',
                required: true,
              ),
              _Field('Tailscale / Fallback URL', _tsUrl,
                hint: 'http://100.x.x.x:8400 (optional)',
              ),
              _Field('API Token', _apiToken,
                hint: 'From: garudan-server start → /api/auth/token',
                obscure: !_showToken,
                suffix: _eye(_showToken, () => setState(() => _showToken = !_showToken)),
              ),

              // Color picker
              const SizedBox(height: 16),
              _Section('Profile Color'),
              Wrap(spacing: 10, children: [
                0xFF7C83FD, 0xFF64FFDA, 0xFFFF5370, 0xFFFFCB6B,
                0xFFC792EA, 0xFF89DDFF, 0xFFFF9800, 0xFF4CAF50,
              ].map((c) => GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: _color == c ? Border.all(color: Colors.white, width: 3) : null,
                  ),
                ),
              )).toList()),
              const SizedBox(height: 20),
              // Test button
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _test,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_tethering, size: 18),
                label: const Text('Test Connection'),
              ),
              if (_testOk) _statusRow(Icons.check_circle, 'Connected!', const Color(0xFF64FFDA)),
              if (_testError != null) _statusRow(Icons.error_outline, _testError!, const Color(0xFFFF5370)),

              const SizedBox(height: 20),

              // Optional services
              ExpansionTile(
                title: const Text('Optional Services', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Netdata, Gotify', style: TextStyle(fontSize: 12)),
                children: [
                  _Section('Netdata (Live Graphs)'),
                  _docsRow('What is Netdata?', AppConstants.netdataDocsUrl),
                  _Field('Netdata URL', _netdata, hint: 'http://IP:19999'),
                  const SizedBox(height: 12),
                  _Section('Gotify (Push Notifications)'),
                  _docsRow('What is Gotify?', AppConstants.gotifyDocsUrl),
                  _Field('Gotify URL', _gotifyUrl, hint: 'https://gotify.example.com'),
                  _Field('Gotify Token', _gotifyTok, hint: 'App token from Gotify dashboard'),
                ],
              ),

              const SizedBox(height: 32),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C83FD),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(widget.editId != null ? 'Save Changes' : 'Add Server',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _installHint() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF0D0D0D),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF2A2A2A)),
    ),
    child: const SelectableText(
      'Install backend on your server:\n'
      '\$ pip3 install garudan-server\n'
      '\$ garudan-server setup\n'
      '\$ garudan-server start',
      style: TextStyle(color: Color(0xFF64FFDA), fontSize: 12, fontFamily: 'monospace', height: 1.6),
    ),
  );

  Widget _docsRow(String label, String url) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: GestureDetector(
      onTap: () => launchUrl(Uri.parse(url)),
      child: Row(children: [
        const Icon(Icons.open_in_new, size: 14, color: Color(0xFF7C83FD)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Color(0xFF7C83FD), fontSize: 12)),
      ]),
    ),
  );

  Widget _statusRow(IconData icon, String msg, Color color) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 6),
      Expanded(child: Text(msg, style: TextStyle(color: color, fontSize: 12))),
    ]),
  );

  Widget _eye(bool show, VoidCallback onTap) =>
      IconButton(icon: Icon(show ? Icons.visibility_off : Icons.visibility, size: 18), onPressed: onTap);
}

class _Section extends StatelessWidget {
  const _Section(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(label.toUpperCase(), style: const TextStyle(
      color: Color(0xFF7C83FD), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.ctrl, {this.hint, this.required = false, this.obscure = false, this.type, this.suffix});
  final String label; final TextEditingController ctrl;
  final String? hint; final bool required, obscure;
  final TextInputType? type; final Widget? suffix;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: ctrl, obscureText: obscure, keyboardType: type,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: InputDecoration(labelText: label, hintText: hint, suffixIcon: suffix),
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null : null,
    ),
  );
}
