import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/dashboard/dashboard_screen.dart';
import 'features/docker/docker_screen.dart';
import 'features/files/files_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/add_server_screen.dart';
import 'features/processes/processes_screen.dart';
import 'features/servers/servers_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/ssh_keys/ssh_keys_screen.dart';
import 'features/terminal/terminal_screen.dart';
import 'models/server_profile.dart';
import 'services/storage_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final storage = ref.read(storageServiceProvider);
  return GoRouter(
    initialLocation: storage.isFirstLaunch() ? '/onboarding' : '/servers',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(
        path: '/servers',
        builder: (_, __) => const ServersScreen(),
        routes: [
          GoRoute(path: 'add', builder: (_, __) => const AddServerScreen()),
          GoRoute(path: 'edit/:id', builder: (_, s) => AddServerScreen(editId: s.pathParameters['id'])),
        ],
      ),
      GoRoute(path: '/dashboard/:id', builder: (_, s) => DashboardScreen(serverId: s.pathParameters['id']!)),
      GoRoute(
        path: '/terminal/:id',
        builder: (_, s) => TerminalScreen(profile: s.extra as ServerProfile),
      ),
      GoRoute(path: '/docker/:id', builder: (_, s) => DockerScreen(serverId: s.pathParameters['id']!)),
      GoRoute(path: '/files/:id', builder: (_, s) => FilesScreen(serverId: s.pathParameters['id']!)),
      GoRoute(path: '/processes/:id', builder: (_, s) => ProcessesScreen(serverId: s.pathParameters['id']!)),
      GoRoute(path: '/notifications/:id', builder: (_, s) => NotificationsScreen(serverId: s.pathParameters['id']!)),
      GoRoute(path: '/ssh-keys', builder: (_, __) => const SshKeysScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});
