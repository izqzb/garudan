import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../main.dart';
import '../../services/storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _State();
}

class _State extends ConsumerState<SettingsScreen> {
  String _version = '';
  late double _fontSize;
  late String _termTheme;
  late bool _isDark;
  late bool _alertsEnabled;
  late double _cpuT, _diskT, _ramT;

  @override
  void initState() {
    super.initState();
    final s = ref.read(storageServiceProvider);
    _fontSize      = s.getTerminalFontSize();
    _termTheme     = s.getTerminalTheme();
    _isDark        = s.isDarkMode();
    _alertsEnabled = s.isAlertsEnabled();
    _cpuT          = s.getCpuThreshold();
    _diskT         = s.getDiskThreshold();
    _ramT          = s.getRamThreshold();
    PackageInfo.fromPlatform().then((i) => setState(() => _version = i.version));
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.read(storageServiceProvider);
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(children: [

          // ── Appearance ──────────────────────────────────────────────────
          _section('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: Text(_isDark ? 'AMOLED Black' : 'Light Gray'),
            secondary: Icon(_isDark ? Icons.dark_mode : Icons.light_mode),
            value: _isDark,
            activeColor: const Color(0xFF7C83FD),
            onChanged: (v) async {
              setState(() => _isDark = v);
              await storage.setDarkMode(v);
              ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light;
            },
          ),

          // ── Terminal ─────────────────────────────────────────────────
          _section('Terminal'),
          ListTile(
            title: const Text('Font Size'),
            subtitle: Text('${_fontSize.toStringAsFixed(1)}px'),
            leading: const Icon(Icons.format_size),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () async {
                  final v = (_fontSize - 1).clamp(AppConstants.minFontSize, AppConstants.maxFontSize);
                  setState(() => _fontSize = v);
                  await storage.setTerminalFontSize(v);
                },
              ),
              Text(_fontSize.toStringAsFixed(0), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () async {
                  final v = (_fontSize + 1).clamp(AppConstants.minFontSize, AppConstants.maxFontSize);
                  setState(() => _fontSize = v);
                  await storage.setTerminalFontSize(v);
                },
              ),
            ]),
          ),
          ListTile(
            title: const Text('Terminal Theme'),
            subtitle: Text(_prettyTheme(_termTheme)),
            leading: const Icon(Icons.palette_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemePicker(storage),
          ),

          // ── Alerts ───────────────────────────────────────────────────
          _section('System Alerts'),
          SwitchListTile(
            title: const Text('Enable Alerts'),
            subtitle: const Text('CPU, RAM, disk threshold notifications'),
            secondary: const Icon(Icons.notifications_active_outlined),
            value: _alertsEnabled,
            activeColor: const Color(0xFF7C83FD),
            onChanged: (v) async {
              setState(() => _alertsEnabled = v);
              await storage.setAlertsEnabled(v);
            },
          ),
          if (_alertsEnabled) ...[
            _thresholdTile('CPU Alert', 'Notify when CPU >', _cpuT, '%', (v) async {
              setState(() => _cpuT = v);
              await storage.setCpuThreshold(v);
            }),
            _thresholdTile('RAM Alert', 'Notify when RAM >', _ramT, '%', (v) async {
              setState(() => _ramT = v);
              await storage.setRamThreshold(v);
            }),
            _thresholdTile('Disk Alert', 'Notify when disk >', _diskT, '%', (v) async {
              setState(() => _diskT = v);
              await storage.setDiskThreshold(v);
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Checks every ${AppConstants.alertCheckInterval.inMinutes} minutes',
                style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
            ),
          ],

          // ── About ────────────────────────────────────────────────────
          _section('About'),
          ListTile(
            title: const Text('Version'),
            subtitle: Text(_version.isEmpty ? AppConstants.appVersion : _version),
            leading: const Icon(Icons.info_outline),
          ),
          ListTile(
            title: const Text('GitHub — App'),
            subtitle: const Text('Source code, issues, releases'),
            leading: const Icon(Icons.code),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(Uri.parse(AppConstants.githubUrl)),
          ),
          ListTile(
            title: const Text('GitHub — Backend'),
            subtitle: const Text('garudan-server pip package'),
            leading: const Icon(Icons.dns_outlined),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(Uri.parse(AppConstants.githubServerUrl)),
          ),
          ListTile(
            title: const Text('SSH Keys'),
            subtitle: const Text('Manage your SSH key pairs'),
            leading: const Icon(Icons.vpn_key_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/ssh-keys'),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(label.toUpperCase(), style: const TextStyle(
      color: Color(0xFF7C83FD), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
  );

  Widget _thresholdTile(String title, String sub, double value, String unit, Future<void> Function(double) onChanged) {
    return ListTile(
      title: Text(title),
      subtitle: Text('$sub ${value.toInt()}$unit'),
      trailing: SizedBox(
        width: 160,
        child: Slider(
          value: value, min: 50, max: 99, divisions: 49,
          activeColor: const Color(0xFF7C83FD),
          onChanged: (v) => onChanged(v),
        ),
      ),
    );
  }

  void _showThemePicker(StorageService storage) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('Terminal Theme', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
        ...TerminalThemeName.values.map((t) => ListTile(
          title: Text(t.label),
          trailing: _termTheme == t.name ? const Icon(Icons.check, color: Color(0xFF7C83FD)) : null,
          onTap: () async {
            setState(() => _termTheme = t.name);
            await storage.setTerminalTheme(t.name);
            if (mounted) Navigator.pop(context);
          },
        )),
        const SizedBox(height: 16),
      ]),
    );
  }

  String _prettyTheme(String t) => TerminalThemeName.values
      .firstWhere((e) => e.name == t, orElse: () => TerminalThemeName.amoled).label;
}
