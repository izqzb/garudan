import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../models/server_profile.dart';
import '../../services/storage_service.dart';

class AddServerScreen extends ConsumerStatefulWidget {
  const AddServerScreen({super.key, this.editId});
  final String? editId;

  @override
  ConsumerState<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends ConsumerState<AddServerScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _testOk = false;
  String? _testError;

  final _name       = TextEditingController(text: 'My Server');
  final _host       = TextEditingController();
  final _sshPort    = TextEditingController(text: '22');
  final _sshUser    = TextEditingController();
  final _sshPass    = TextEditingController();
  final _apiUrl     = TextEditingController();
  final _tsUrl      = TextEditingController();
  final _apiToken   = TextEditingController();

  bool _showPass  = false;
  bool _showToken = false;

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
        _name.text     = p.name;
        _host.text     = p.host;
        _sshPort.text  = p.port.toString();
        _sshUser.text  = p.sshUser;
        _sshPass.text  = p.sshPassword ?? '';
        _apiUrl.text   = p.apiBaseUrl;
        _tsUrl.text    = p.tailscaleUrl ?? '';
        _apiToken.text = p.apiToken ?? '';
      });
    } catch (_) {}
  }

  Future<void> _testConnection() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _testOk = false; _testError = null; });
    final url = '${_apiUrl.text.trimRight().replaceAll(RegExp(r"/$"), "")}/health';
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: _apiToken.text.isNotEmpty
            ? {'Authorization': 'Bearer ${_apiToken.text.trim()}'}
            : {},
      ));
      final resp = await dio.get<dynamic>(url);
      if (resp.statusCode == 200) {
        setState(() { _testOk = true; });
      } else {
        setState(() { _testError = 'HTTP ${resp.statusCode}'; });
      }
    } on DioException catch (e) {
      setState(() { _testError = e.message ?? e.toString(); });
    } catch (e) {
      setState(() { _testError = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final profile = ServerProfile(
      id: widget.editId ?? const Uuid().v4(),
      name: _name.text.trim(),
      host: _host.text.trim(),
      port: int.tryParse(_sshPort.text) ?? 22,
      sshUser: _sshUser.text.trim(),
      sshPassword: _sshPass.text.isEmpty ? null : _sshPass.text,
      apiBaseUrl: _apiUrl.text.trimRight().replaceAll(RegExp(r'/$'), ''),
      tailscaleUrl: _tsUrl.text.isEmpty ? null : _tsUrl.text.trim(),
      apiToken: _apiToken.text.isEmpty ? null : _apiToken.text.trim(),
      createdAt: DateTime.now(),
    );
    await ref.read(storageServiceProvider).addServerProfile(profile);
    if (mounted) context.go('/servers');
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _sshPort, _sshUser, _sshPass, _apiUrl, _tsUrl, _apiToken]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.editId != null ? 'Edit Server' : 'Add Server'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader('Server Details'),
            _Field('Name', _name, hint: 'Home Lab', required: true),
            _Field('SSH Host / IP', _host, hint: '192.168.1.10 or domain.com', required: true),
            _Field('SSH Port', _sshPort, hint: '22', type: TextInputType.number),
            _Field('SSH Username', _sshUser, hint: 'ubuntu', required: true),
            _Field('SSH Password', _sshPass,
              hint: 'Leave empty if using key auth on server',
              obscure: !_showPass,
              suffix: _eyeBtn(_showPass, () => setState(() => _showPass = !_showPass)),
            ),
            const SizedBox(height: 24),
            _SectionHeader('API Connection'),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: const SelectableText(
                'Install on your server:\n'
                '\$ pip3 install garudan-server\n'
                '\$ garudan-server setup\n'
                '\$ garudan-server start',
                style: TextStyle(
                  color: Color(0xFF64FFDA),
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _Field('API Base URL', _apiUrl,
              hint: 'https://server.example.com  or  http://IP:8400',
              required: true,
            ),
            _Field('Tailscale / Fallback URL', _tsUrl,
              hint: 'http://100.x.x.x:8400  (optional)',
            ),
            _Field('API Token', _apiToken,
              hint: 'Copy from garudan-server after login',
              obscure: !_showToken,
              suffix: _eyeBtn(_showToken, () => setState(() => _showToken = !_showToken)),
            ),
            const SizedBox(height: 12),
            // Test button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _testConnection,
                icon: _loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering, size: 18),
                label: const Text('Test Connection'),
              ),
            ),
            if (_testOk)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Row(children: [
                  Icon(Icons.check_circle, color: Color(0xFF64FFDA), size: 18),
                  SizedBox(width: 6),
                  Text('Connected!', style: TextStyle(color: Color(0xFF64FFDA))),
                ]),
              ),
            if (_testError != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.error_outline, color: Color(0xFFFF5370), size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_testError!,
                      style: const TextStyle(color: Color(0xFFFF5370), fontSize: 12),
                    ),
                  ),
                ]),
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
              child: Text(
                widget.editId != null ? 'Save Changes' : 'Add Server',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _eyeBtn(bool show, VoidCallback onTap) => IconButton(
    icon: Icon(show ? Icons.visibility_off : Icons.visibility, size: 18),
    onPressed: onTap,
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF7C83FD),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field(
    this.label,
    this.ctrl, {
    this.hint,
    this.required = false,
    this.obscure = false,
    this.type,
    this.suffix,
  });

  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final bool required;
  final bool obscure;
  final TextInputType? type;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffix,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
      ),
    );
  }
}
