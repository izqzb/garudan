import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/dashboard/dashboard_screen.dart';
import 'features/docker/docker_screen.dart';
import 'features/files/files_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/add_server_screen.dart';
import 'features/processes/processes_screen.dart';
import 'features/servers/servers_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/terminal/terminal_screen.dart';
import 'models/server_profile.dart';
import 'services/storage_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final storage = ref.read(storageServiceProvider);
  return GoRouter(
    initialLocation: storage.isFirstLaunch() ? '/onboarding' : '/servers',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/servers',
        builder: (_, __) => const ServersScreen(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (_, __) => const AddServerScreen(),
          ),
          GoRoute(
            path: 'edit/:id',
            builder: (ctx, state) => AddServerScreen(
              editId: state.pathParameters['id'],
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (ctx, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard/:serverId',
            builder: (ctx, state) => DashboardScreen(
              serverId: state.pathParameters['serverId']!,
            ),
          ),
          GoRoute(
            path: '/terminal/:serverId',
            builder: (ctx, state) {
              final extra = state.extra as ServerProfile?;
              return TerminalScreen(profile: extra!);
            },
          ),
          GoRoute(
            path: '/docker/:serverId',
            builder: (ctx, state) => DockerScreen(
              serverId: state.pathParameters['serverId']!,
            ),
          ),
          GoRoute(
            path: '/files/:serverId',
            builder: (ctx, state) => FilesScreen(
              serverId: state.pathParameters['serverId']!,
            ),
          ),
          GoRoute(
            path: '/processes/:serverId',
            builder: (ctx, state) => ProcessesScreen(
              serverId: state.pathParameters['serverId']!,
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
