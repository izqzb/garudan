import 'dart:convert';

/// A server profile stores all connection details for a remote server.
class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.sshUser,
    required this.apiBaseUrl,
    this.sshPassword,
    this.sshPrivateKey,
    this.tailscaleUrl,
    this.apiToken,
    this.color = 0xFF7C83FD,
    this.icon = 'server',
    this.createdAt,
  });

  final String id;
  final String name;

  // SSH direct connection
  final String host;
  final int port;
  final String sshUser;
  final String? sshPassword;
  final String? sshPrivateKey;

  // garudan-server API
  final String apiBaseUrl;   // e.g. https://server.example.com
  final String? tailscaleUrl; // e.g. http://100.x.x.x:8400
  final String? apiToken;

  // UI customisation
  final int color;
  final String icon;
  final DateTime? createdAt;

  String get wsTerminalUrl {
    final base = apiBaseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    return '$base/ws/terminal';
  }

  String get wsFallbackUrl {
    if (tailscaleUrl == null) return wsTerminalUrl;
    final base = tailscaleUrl!.replaceFirst(RegExp(r'^http'), 'ws');
    return '$base/ws/terminal';
  }

  ServerProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? sshUser,
    String? sshPassword,
    String? sshPrivateKey,
    String? apiBaseUrl,
    String? tailscaleUrl,
    String? apiToken,
    int? color,
    String? icon,
    DateTime? createdAt,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      sshUser: sshUser ?? this.sshUser,
      sshPassword: sshPassword ?? this.sshPassword,
      sshPrivateKey: sshPrivateKey ?? this.sshPrivateKey,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      tailscaleUrl: tailscaleUrl ?? this.tailscaleUrl,
      apiToken: apiToken ?? this.apiToken,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'sshUser': sshUser,
        'sshPassword': sshPassword,
        'sshPrivateKey': sshPrivateKey,
        'apiBaseUrl': apiBaseUrl,
        'tailscaleUrl': tailscaleUrl,
        'apiToken': apiToken,
        'color': color,
        'icon': icon,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory ServerProfile.fromJson(Map<String, dynamic> json) => ServerProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        host: json['host'] as String,
        port: (json['port'] as num).toInt(),
        sshUser: json['sshUser'] as String,
        sshPassword: json['sshPassword'] as String?,
        sshPrivateKey: json['sshPrivateKey'] as String?,
        apiBaseUrl: json['apiBaseUrl'] as String,
        tailscaleUrl: json['tailscaleUrl'] as String?,
        apiToken: json['apiToken'] as String?,
        color: (json['color'] as num?)?.toInt() ?? 0xFF7C83FD,
        icon: json['icon'] as String? ?? 'server',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  static List<ServerProfile> listFromJson(String raw) {
    final list = json.decode(raw) as List<dynamic>;
    return list.map((e) => ServerProfile.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<ServerProfile> profiles) {
    return json.encode(profiles.map((p) => p.toJson()).toList());
  }

  @override
  bool operator ==(Object other) => other is ServerProfile && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Command snippet stored per server (or global)
class CommandSnippet {
  const CommandSnippet({
    required this.id,
    required this.label,
    required this.command,
    this.serverId,
  });

  final String id;
  final String label;
  final String command;
  final String? serverId; // null = global

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'command': command,
        'serverId': serverId,
      };

  factory CommandSnippet.fromJson(Map<String, dynamic> json) => CommandSnippet(
        id: json['id'] as String,
        label: json['label'] as String,
        command: json['command'] as String,
        serverId: json['serverId'] as String?,
      );
}
