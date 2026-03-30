import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../services/storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) => setState(() => _version = i.version));
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.read(storageServiceProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => context.pop()),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _section('Terminal'),
          ListTile(
            title: const Text('Font Size', style: TextStyle(color: Colors.white)),
            subtitle: Text('${storage.getTerminalFontSize().toStringAsFixed(1)}px',
              style: const TextStyle(color: Color(0xFF666666))),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF444444)),
            onTap: () {},
          ),
          ListTile(
            title: const Text('Theme', style: TextStyle(color: Colors.white)),
            subtitle: Text(storage.getTerminalTheme(),
              style: const TextStyle(color: Color(0xFF666666))),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFF444444)),
            onTap: () {},
          ),
          _section('About'),
          ListTile(
            title: const Text('Version', style: TextStyle(color: Colors.white)),
            subtitle: Text(_version.isEmpty ? AppConstants.appVersion : _version,
              style: const TextStyle(color: Color(0xFF666666))),
          ),
          ListTile(
            title: const Text('GitHub', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Source code & issues', style: TextStyle(color: Color(0xFF666666))),
            trailing: const Icon(Icons.open_in_new, color: Color(0xFF444444), size: 18),
            onTap: () => launchUrl(Uri.parse(AppConstants.githubUrl)),
          ),
          ListTile(
            title: const Text('Backend Setup', style: TextStyle(color: Colors.white)),
            subtitle: const Text('pip3 install garudan-server', style: TextStyle(color: Color(0xFF666666), fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
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
