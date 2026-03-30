import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';
import 'package:uuid/uuid.dart';

import '../../models/server_profile.dart';
import 'terminal_connection.dart';

/// Represents one terminal tab — a session ID, xterm Terminal, and its
/// WebSocket connection, plus search state.
class TerminalSession with ChangeNotifier {
  TerminalSession({
    required this.profile,
    String? id,
    String? label,
    int cols = 80,
    int rows = 24,
  })  : id = id ?? const Uuid().v4(),
        terminal = Terminal(maxLines: 50000),
        label = label ?? 'Terminal' {
    _connection = TerminalConnection(
      id: this.id,
      profile: profile,
      terminal: terminal,
      label: this.label,
      onStateChange: (s) {
        connectionState = s;
        notifyListeners();
      },
      onError: (e) {
        lastError = e;
        notifyListeners();
      },
    );

    // Wire terminal input -> WebSocket
    terminal.onOutput = (data) {
      _connection.sendInput(data);
    };

    terminal.onResize = (w, h, pw, ph) {
      _connection.resize(w, h);
    };
  }

  final String id;
  final ServerProfile profile;
  final Terminal terminal;
  String label;

  late final TerminalConnection _connection;
  TerminalConnection get connection => _connection;

  TerminalConnectionState connectionState = TerminalConnectionState.idle;
  String? lastError;

  // Search state
  bool searchVisible = false;
  String searchQuery = '';
  int searchMatchCount = 0;
  int searchCurrentMatch = 0;

  bool get isConnected => connectionState == TerminalConnectionState.connected;
  bool get isReconnecting => connectionState == TerminalConnectionState.reconnecting;
  bool get hasError => connectionState == TerminalConnectionState.error;

  Future<void> connect() => _connection.connect();
  Future<void> reconnect() => _connection.reconnect();
  Future<void> disconnect() => _connection.disconnect();

  void sendInput(String data) => _connection.sendInput(data);

  void rename(String newLabel) {
    label = newLabel;
    _connection.label = newLabel;
    notifyListeners();
  }

  void toggleSearch() {
    searchVisible = !searchVisible;
    if (!searchVisible) searchQuery = '';
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _connection.dispose();
    super.dispose();
  }
}
