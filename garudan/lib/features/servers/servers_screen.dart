import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/server_profile.dart';
import '../../services/storage_service.dart';

final _serverListProvider = FutureProvider<List<ServerProfile>>((ref) async {
  return ref.read(storageServiceProvider).getServerProfiles();
});

class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(_serverListProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Servers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/servers/add').then((_) => ref.invalidate(_serverListProvider)),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: profiles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) return _EmptyState(onAdd: () => context.push('/servers/add'));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (ctx, i) => _ServerCard(
              profile: list[i],
              onTap: () => context.go('/dashboard/${list[i].id}'),
              onTerminal: () => context.push('/terminal/${list[i].id}', extra: list[i]),
              onEdit: () => context.push('/servers/edit/${list[i].id}')
                  .then((_) => ref.invalidate(_serverListProvider)),
              onDelete: () async {
                await ref.read(storageServiceProvider).removeServerProfile(list[i].id);
                ref.invalidate(_serverListProvider);
              },
            ),
          );
        },
      ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.profile,
    required this.onTap,
    required this.onTerminal,
    required this.onEdit,
    required this.onDelete,
  });

  final ServerProfile profile;
  final VoidCallback onTap;
  final VoidCallback onTerminal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Color(profile.color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.dns_outlined, color: Color(profile.color), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${profile.sshUser}@${profile.host}:${profile.port}',
                          style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    color: const Color(0xFF1C1C1C),
                    icon: const Icon(Icons.more_vert, color: Color(0xFF888888)),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') _confirmDelete(context);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 18, color: Color(0xFFB0B0B0)),
                          SizedBox(width: 8),
                          Text('Edit', style: TextStyle(color: Colors.white)),
                        ]),
                      ),
                      const PopupMenuItem(value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline, size: 18, color: Color(0xFFFF5370)),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Color(0xFFFF5370))),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                profile.apiBaseUrl,
                style: const TextStyle(color: Color(0xFF555555), fontSize: 11, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _QuickBtn(Icons.dashboard_outlined, 'Dashboard', onTap),
                  const SizedBox(width: 8),
                  _QuickBtn(Icons.terminal, 'Terminal', onTerminal),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Server'),
        content: Text('Remove "${profile.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(ctx); onDelete(); },
            child: const Text('Remove', style: TextStyle(color: Color(0xFFFF5370))),
          ),
        ],
      ),
    );
  }
}

class _QuickBtn extends StatelessWidget {
  const _QuickBtn(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: const Color(0xFF7C83FD)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12)),
        ]),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.dns_outlined, size: 64, color: Color(0xFF2A2A2A)),
        const SizedBox(height: 16),
        const Text('No servers yet', style: TextStyle(color: Color(0xFF888888), fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Add a server to get started', style: TextStyle(color: Color(0xFF444444))),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add Server'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C83FD),
            foregroundColor: Colors.black,
          ),
        ),
      ]),
    );
  }
}
