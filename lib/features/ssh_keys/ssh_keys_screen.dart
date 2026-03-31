import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/server_profile.dart';
import '../../services/storage_service.dart';

class SshKeysScreen extends ConsumerStatefulWidget {
  const SshKeysScreen({super.key});
  @override
  ConsumerState<SshKeysScreen> createState() => _State();
}

class _State extends ConsumerState<SshKeysScreen> {
  List<SshKeyPair> _keys = [];
  bool _generating = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final keys = await ref.read(storageServiceProvider).getSshKeys();
    setState(() => _keys = keys);
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    try {
      // Generate ED25519 keypair
      final keypair = await SSHKeyPair.generate();
      final id = const Uuid().v4();
      final privateKey = keypair.toPem();
      final publicKey = keypair.toPublicKeyString();
      // Fingerprint from first 8 chars of base64
      final bytes = base64.decode(publicKey.split(' ')[1]);
      final fp = bytes.take(6).map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');

      final pair = SshKeyPair(
        id: id, name: 'ED25519 Key ${_keys.length + 1}',
        publicKey: publicKey, fingerprint: fp,
        createdAt: DateTime.now(),
      );

      final storage = ref.read(storageServiceProvider);
      await storage.saveSshPrivateKey(id, privateKey);
      final updated = [..._keys, pair];
      await storage.saveSshKeys(updated);
      setState(() => _keys = updated);

      if (mounted) _showPublicKey(pair);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Key generation failed: $e')));
    } finally {
      setState(() => _generating = false);
    }
  }

  void _showPublicKey(SshKeyPair pair) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Public Key Generated!', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Copy this to your server\'s ~/.ssh/authorized_keys',
            style: TextStyle(color: Color(0xFF888888), fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0D0D0D), borderRadius: BorderRadius.circular(8)),
            child: SelectableText(pair.publicKey,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF64FFDA))),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () { Clipboard.setData(ClipboardData(text: pair.publicKey)); Navigator.pop(context); },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy to Clipboard'),
            )),
          ]),
          const SizedBox(height: 8),
          const Text('Add to server with:\necho "PUBLIC_KEY" >> ~/.ssh/authorized_keys',
            style: TextStyle(color: Color(0xFF666666), fontSize: 11, fontFamily: 'monospace'), textAlign: TextAlign.center),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH Keys'),
        actions: [
          IconButton(
            icon: _generating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add),
            onPressed: _generating ? null : _generate,
            tooltip: 'Generate new ED25519 key',
          ),
        ],
      ),
      body: _keys.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.vpn_key_outlined, size: 64, color: Color(0xFF2A2A2A)),
                const SizedBox(height: 16),
                const Text('No SSH keys yet', style: TextStyle(color: Color(0xFF888888), fontSize: 18)),
                const SizedBox(height: 8),
                const Text('Tap + to generate an ED25519 key pair', style: TextStyle(color: Color(0xFF555555))),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _generating ? null : _generate,
                  icon: const Icon(Icons.add),
                  label: const Text('Generate Key'),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C83FD), foregroundColor: Colors.black),
                ),
              ]),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _keys.length,
              itemBuilder: (_, i) {
                final k = _keys[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.vpn_key, color: Color(0xFF7C83FD)),
                    title: Text(k.name),
                    subtitle: Text('${k.fingerprint}\n${k.createdAt.toString().substring(0, 10)}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                    isThreeLine: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copy public key',
                        onPressed: () => _showPublicKey(k),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFFF5370)),
                        tooltip: 'Delete key',
                        onPressed: () => _confirmDelete(k),
                      ),
                    ]),
                  ),
                );
              },
            ),
    );
  }

  void _confirmDelete(SshKeyPair k) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Key'),
        content: Text('Delete "${k.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(storageServiceProvider).deleteSshKey(k.id);
              await _load();
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF5370))),
          ),
        ],
      ),
    );
  }
}
