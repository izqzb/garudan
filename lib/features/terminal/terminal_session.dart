import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:xterm/xterm.dart';
import '../../models/server_profile.dart';
import 'terminal_connection.dart';

class TerminalSession with ChangeNotifier {
  TerminalSession({
    required this.profile,
    String? id,
    String? label,
  })  : id = id ?? const Uuid().v4(),
        terminal = Terminal(maxLines: 50000),
        label = label ?? 'Terminal' {
    _conn = TerminalConnection(
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

    terminal.onOutput = (data) {
      _conn.sendInput(data);
      _trackInput(data);
    };

    terminal.onResize = (w, h, _, __) => _conn.resize(w, h);
  }

  final String id;
  final ServerProfile profile;
  final Terminal terminal;
  String label;
  late final TerminalConnection _conn;
  TerminalConnection get connection => _conn;

  TerminalConnectionState connectionState =
      TerminalConnectionState.idle;
  String? lastError;
  bool searchVisible = false;

  // ── Command history ───────────────────────────────────────────────
  final List<String> commandHistory = [];
  static const _maxHistory = 200;
  final StringBuffer _inputBuf = StringBuffer();

  void _trackInput(String data) {
    if (data == '\r' || data == '\n') {
      final cmd = _inputBuf.toString().trim();
      if (cmd.isNotEmpty &&
          (commandHistory.isEmpty || commandHistory.last != cmd)) {
        commandHistory.add(cmd);
        if (commandHistory.length > _maxHistory) {
          commandHistory.removeAt(0);
        }
      }
      _inputBuf.clear();
    } else if (data == '\x7f' || data == '\b') {
      // Backspace
      final s = _inputBuf.toString();
      if (s.isNotEmpty) {
        _inputBuf.clear();
        _inputBuf.write(s.substring(0, s.length - 1));
      }
    } else if (data.codeUnits.every((c) => c >= 32)) {
      // Printable chars only
      _inputBuf.write(data);
    }
  }

  // ── State helpers ─────────────────────────────────────────────────
  bool get isConnected =>
      connectionState == TerminalConnectionState.connected;
  bool get isReconnecting =>
      connectionState == TerminalConnectionState.reconnecting;
  bool get hasError =>
      connectionState == TerminalConnectionState.error;

  Future<void> connect() => _conn.connect();
  Future<void> reconnect() => _conn.reconnect();
  Future<void> disconnect() => _conn.disconnect();
  void sendInput(String d) => _conn.sendInput(d);
  void toggleSearch() {
    searchVisible = !searchVisible;
    notifyListeners();
  }

  void rename(String newLabel) {
    label = newLabel;
    _conn.label = newLabel;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _conn.dispose();
    super.dispose();
  }
}
