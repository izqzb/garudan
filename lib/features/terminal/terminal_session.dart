import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:xterm/xterm.dart';
import '../../models/server_profile.dart';
import 'terminal_connection.dart';

class TerminalSession with ChangeNotifier {
  TerminalSession({required this.profile, String? id, String? label})
      : id = id ?? const Uuid().v4(),
        terminal = Terminal(maxLines: 50000),
        label = label ?? 'Terminal' {
    _conn = TerminalConnection(
      id: this.id, profile: profile, terminal: terminal,
      label: this.label,
      onStateChange: (s) { connectionState = s; notifyListeners(); },
      onError: (e) { lastError = e; notifyListeners(); },
    );
    terminal.onOutput = (data) => _conn.sendInput(data);
    terminal.onResize = (w, h, _, __) => _conn.resize(w, h);
  }

  final String id;
  final ServerProfile profile;
  final Terminal terminal;
  String label;
  late final TerminalConnection _conn;
  TerminalConnection get connection => _conn;

  TerminalConnectionState connectionState = TerminalConnectionState.idle;
  String? lastError;
  bool searchVisible = false;

  bool get isConnected    => connectionState == TerminalConnectionState.connected;
  bool get isReconnecting => connectionState == TerminalConnectionState.reconnecting;
  bool get hasError       => connectionState == TerminalConnectionState.error;

  Future<void> connect()    => _conn.connect();
  Future<void> reconnect()  => _conn.reconnect();
  Future<void> disconnect() => _conn.disconnect();
  void sendInput(String d)  => _conn.sendInput(d);

  void toggleSearch() { searchVisible = !searchVisible; notifyListeners(); }

  @override
  Future<void> dispose() async { await _conn.dispose(); super.dispose(); }
}
