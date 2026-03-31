import 'dart:convert';

class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.sshUser,
    required this.apiBaseUrl,
    this.sshPassword,
    this.sshPrivateKeyId,
    this.tailscaleUrl,
    this.apiToken,
    this.netdataUrl,
    this.gotifyUrl,
    this.gotifyToken,
    this.color = 0xFF7C83FD,
    this.createdAt,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String sshUser;
  final String? sshPassword;
  final String? sshPrivateKeyId;
  final String apiBaseUrl;
  final String? tailscaleUrl;
  final String? apiToken;
  final String? netdataUrl;
  final String? gotifyUrl;
  final String? gotifyToken;
  final int color;
  final DateTime? createdAt;

  // Convert http/https → ws/wss correctly
  String get wsTerminalUrl {
    final base = apiBaseUrl
        .replaceFirst(RegExp(r'^https://'), 'wss://')
        .replaceFirst(RegExp(r'^http://'), 'ws://')
        .replaceAll(RegExp(r'/$'), '');
    final token = apiToken ?? '';
    return '$base/ws/terminal?token=${Uri.encodeComponent(token)}';
  }

  String? get wsFallbackUrl {
    if (tailscaleUrl == null || tailscaleUrl!.isEmpty) return null;
    final base = tailscaleUrl!
        .replaceFirst(RegExp(r'^https://'), 'wss://')
        .replaceFirst(RegExp(r'^http://'), 'ws://')
        .replaceAll(RegExp(r'/$'), '');
    final token = apiToken ?? '';
    return '$base/ws/terminal?token=${Uri.encodeComponent(token)}';
  }

  ServerProfile copyWith({
    String? id, String? name, String? host, int? port,
    String? sshUser, String? sshPassword, String? sshPrivateKeyId,
    String? apiBaseUrl, String? tailscaleUrl, String? apiToken,
    String? netdataUrl, String? gotifyUrl, String? gotifyToken,
    int? color, DateTime? createdAt,
  }) => ServerProfile(
    id: id ?? this.id, name: name ?? this.name,
    host: host ?? this.host, port: port ?? this.port,
    sshUser: sshUser ?? this.sshUser, sshPassword: sshPassword ?? this.sshPassword,
    sshPrivateKeyId: sshPrivateKeyId ?? this.sshPrivateKeyId,
    apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl, tailscaleUrl: tailscaleUrl ?? this.tailscaleUrl,
    apiToken: apiToken ?? this.apiToken, netdataUrl: netdataUrl ?? this.netdataUrl,
    gotifyUrl: gotifyUrl ?? this.gotifyUrl, gotifyToken: gotifyToken ?? this.gotifyToken,
    color: color ?? this.color, createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'host': host, 'port': port,
    'sshUser': sshUser, 'sshPassword': sshPassword, 'sshPrivateKeyId': sshPrivateKeyId,
    'apiBaseUrl': apiBaseUrl, 'tailscaleUrl': tailscaleUrl, 'apiToken': apiToken,
    'netdataUrl': netdataUrl, 'gotifyUrl': gotifyUrl, 'gotifyToken': gotifyToken,
    'color': color, 'createdAt': createdAt?.toIso8601String(),
  };

  factory ServerProfile.fromJson(Map<String, dynamic> j) => ServerProfile(
    id: j['id'], name: j['name'], host: j['host'], port: (j['port'] as num).toInt(),
    sshUser: j['sshUser'], sshPassword: j['sshPassword'], sshPrivateKeyId: j['sshPrivateKeyId'],
    apiBaseUrl: j['apiBaseUrl'], tailscaleUrl: j['tailscaleUrl'], apiToken: j['apiToken'],
    netdataUrl: j['netdataUrl'], gotifyUrl: j['gotifyUrl'], gotifyToken: j['gotifyToken'],
    color: (j['color'] as num?)?.toInt() ?? 0xFF7C83FD,
    createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
  );

  static List<ServerProfile> listFromJson(String raw) =>
      (json.decode(raw) as List).map((e) => ServerProfile.fromJson(e)).toList();

  static String listToJson(List<ServerProfile> p) =>
      json.encode(p.map((e) => e.toJson()).toList());
}

class SshKeyPair {
  const SshKeyPair({
    required this.id, required this.name,
    required this.publicKey, required this.fingerprint,
    required this.createdAt,
  });
  final String id;
  final String name;
  final String publicKey;
  final String fingerprint;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'publicKey': publicKey,
    'fingerprint': fingerprint, 'createdAt': createdAt.toIso8601String(),
  };
  factory SshKeyPair.fromJson(Map<String, dynamic> j) => SshKeyPair(
    id: j['id'], name: j['name'], publicKey: j['publicKey'],
    fingerprint: j['fingerprint'], createdAt: DateTime.parse(j['createdAt']),
  );
}

class CommandSnippet {
  const CommandSnippet({required this.id, required this.label, required this.command, this.serverId});
  final String id;
  final String label;
  final String command;
  final String? serverId;
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'command': command, 'serverId': serverId};
  factory CommandSnippet.fromJson(Map<String, dynamic> j) =>
      CommandSnippet(id: j['id'], label: j['label'], command: j['command'], serverId: j['serverId']);
}
