import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../services/storage_service.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),
              // Logo
              Image.asset('assets/images/logo.png', width: 72, height: 72,
                errorBuilder: (_, __, ___) => Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C83FD).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF7C83FD), width: 1.5),
                  ),
                  child: const Icon(Icons.terminal, color: Color(0xFF7C83FD), size: 36),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Garudan', style: TextStyle(
                color: Colors.white, fontSize: 42,
                fontWeight: FontWeight.w800, letterSpacing: -1.5,
              )),
              const SizedBox(height: 8),
              const Text('Your self-hosted server,\nin your pocket.',
                style: TextStyle(color: Color(0xFF888888), fontSize: 20, height: 1.4)),
              const SizedBox(height: 40),
              ...[
                ('SSH Terminal',   'Multi-tab, persistent, auto-reconnect',    Icons.terminal),
                ('Docker',         'Manage containers, view logs and stats',    Icons.widgets_outlined),
                ('Files',          'Browse, upload, edit files on your server', Icons.folder_outlined),
                ('Monitoring',     'CPU, RAM, disk graphs + smart alerts',      Icons.monitor_heart_outlined),
                ('Notifications',  'Gotify push + in-app notification list',    Icons.notifications_outlined),
              ].map((f) => _Feature(icon: f.$3, title: f.$1, subtitle: f.$2)),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await ref.read(storageServiceProvider).setFirstLaunchDone();
                    if (context.mounted) context.go('/servers/add');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C83FD),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add Your Server',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () async {
                    await ref.read(storageServiceProvider).setFirstLaunchDone();
                    if (context.mounted) context.go('/servers');
                  },
                  child: const Text('Skip for now',
                    style: TextStyle(color: Color(0xFF555555))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.subtitle});
  final IconData icon; final String title, subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: const Color(0xFF7C83FD), size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        Text(subtitle, style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
      ])),
    ]),
  );
}
