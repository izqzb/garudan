import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xterm/xterm.dart';

import '../../core/constants.dart';
import '../../models/server_profile.dart';

enum TerminalConnectionState {
  idle,
  connecting,
  connected,
  reconnecting,
  disconnected,
  error,
}

class TerminalConnection {
  TerminalConnection({
    required this.id,
    required this.profile,
    required this.terminal,
    this.label,
    this.onStateChange,
    this.onError,
  });

  final String id;
  final ServerProfile profile;
  final Terminal terminal;
  String? label;
  final void Function(TerminalConnectionState)? onStateChange;
  final void Function(String)? onError;

  TerminalConnectionState _state = TerminalConnectionState.idle;
  TerminalConnectionState get state => _state;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  int _reconnectAttempts = 0;
  bool _disposed = false;
  bool _intentionalClose = false;
  bool _usingFallback = false;

  final List<Uint8List> _inputBuffer = [];
  DateTime? _connectedAt;
  Duration? _lastLatency;
  Duration? get latency => _lastLatency;

  Duration get uptime =>
      _connectedAt != null ? DateTime.now().difference(_connectedAt!) : Duration.zero;

  String get activeUrl =>
      _usingFallback ? profile.wsFallbackUrl : profile.wsTerminalUrl;

  // ────────────────────────────────────────────────────────────
  // Connect
  // ────────────────────────────────────────────────────────────

  Future<void> connect() async {
    if (_disposed) return;
    _intentionalClose = false;
    _setState(TerminalConnectionState.connecting);
    _writeStatus('Connecting to ${profile.name}...');
    await _attemptConnect(primary: true);
  }

  Future<void> _attemptConnect({required bool primary}) async {
    _usingFallback = !primary;
    final url = activeUrl;
    _writeStatus('Trying $url');

    try {
      final headers = <String, dynamic>{
        'User-Agent': 'Garudan/1.0',
        if (profile.apiToken != null && profile.apiToken!.isNotEmpty)
          'Authorization': 'Bearer ${profile.apiToken}',
      };

      _channel = IOWebSocketChannel.connect(
        Uri.parse(url),
        headers: headers,
        connectTimeout: AppConstants.connectTimeout,
        pingInterval: AppConstants.heartbeatInterval,
      );

      final ready = Completer<void>();
      var firstEvent = false;

      _subscription = _channel!.stream.listen(
        (data) {
          if (!firstEvent) {
            firstEvent = true;
            if (!ready.isCompleted) ready.complete();
          }
          _onData(data);
        },
        onError: (Object err) {
          if (!ready.isCompleted) {
            ready.completeError(err);
          } else {
            _handleDisconnect(err.toString());
          }
        },
        onDone: () {
          if (!ready.isCompleted) {
            ready.completeError(Exception('WS closed before handshake'));
          } else {
            _handleDisconnect(null);
          }
        },
        cancelOnError: false,
      );

      await Future.any([
        ready.future,
        Future.delayed(
          AppConstants.connectTimeout,
          () => throw TimeoutException('Timed out', AppConstants.connectTimeout),
        ),
      ]);

      _onConnected();
    } catch (e) {
      await _subscription?.cancel();
      _subscription = null;
      try {
        _channel?.sink.close();
      } catch (_) {}
      _channel = null;

      // If primary failed and fallback exists, try fallback
      if (primary && profile.tailscaleUrl != null && profile.tailscaleUrl!.isNotEmpty) {
        _writeStatus('Primary failed. Trying Tailscale fallback...');
        await _attemptConnect(primary: false);
      } else {
        _writeStatus('Connection failed: $e');
        _setState(TerminalConnectionState.error);
        onError?.call(e.toString());
      }
    }
  }

  void _onConnected() {
    if (_disposed) return;
    _reconnectAttempts = 0;
    _connectedAt = DateTime.now();
    _setState(TerminalConnectionState.connected);
    _writeStatus(
      'Connected via ${_usingFallback ? "Tailscale" : "primary"} \u2713\r\n',
    );
    _startHeartbeat();
    _flushInputBuffer();
  }

  void _onData(dynamic data) {
    if (_disposed) return;
    if (data is String) {
      terminal.write(data);
    } else if (data is List<int>) {
      terminal.write(utf8.decode(data, allowMalformed: true));
    }
  }

  void _handleDisconnect(String? reason) {
    if (_disposed || _intentionalClose) return;
    _stopHeartbeat();
    if (reason != null) _writeStatus('Error: $reason');
    _setState(TerminalConnectionState.reconnecting);
    _scheduleReconnect();
  }

  // ────────────────────────────────────────────────────────────
  // Heartbeat
  // ────────────────────────────────────────────────────────────

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(AppConstants.heartbeatInterval, (_) {
      if (_state == TerminalConnectionState.connected && _channel != null) {
        try {
          // Null byte ping — server filters it, never forwarded to SSH
          _channel!.sink.add(Uint8List.fromList([0x00]));
        } catch (_) {}
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  // ────────────────────────────────────────────────────────────
  // Auto-Reconnect with Exponential Backoff
  // ────────────────────────────────────────────────────────────

  void _scheduleReconnect() {
    if (_disposed || _intentionalClose) return;
    if (_reconnectAttempts >= AppConstants.maxReconnectAttempts) {
      _writeStatus('Max reconnect attempts reached. Tap Reconnect to retry.\r\n');
      _setState(TerminalConnectionState.disconnected);
      return;
    }

    // 2s, 4s, 8s, 16s, 32s, 60s (capped)
    final delaySecs = min(
      AppConstants.reconnectBaseDelay.inSeconds * (1 << _reconnectAttempts),
      60,
    );

    _writeStatus('Reconnecting in ${delaySecs}s (attempt ${_reconnectAttempts + 1})...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySecs), () async {
      if (_disposed || _intentionalClose) return;
      _reconnectAttempts++;
      await _subscription?.cancel();
      _subscription = null;
      try {
        _channel?.sink.close();
      } catch (_) {}
      _channel = null;
      await _attemptConnect(primary: true);
    });
  }

  // ────────────────────────────────────────────────────────────
  // Send Input
  // ────────────────────────────────────────────────────────────

  void sendInput(String data) {
    _sendBytes(Uint8List.fromList(utf8.encode(data)));
  }

  void sendBytes(Uint8List bytes) {
    _sendBytes(bytes);
  }

  void _sendBytes(Uint8List bytes) {
    if (_state == TerminalConnectionState.connected && _channel != null) {
      try {
        _channel!.sink.add(bytes);
      } catch (_) {}
    } else if (_state == TerminalConnectionState.connecting ||
        _state == TerminalConnectionState.reconnecting) {
      _inputBuffer.add(bytes);
      if (_inputBuffer.length > 1000) _inputBuffer.removeAt(0);
    }
  }

  void _flushInputBuffer() {
    for (final b in List.of(_inputBuffer)) {
      _sendBytes(b);
    }
    _inputBuffer.clear();
  }

  // ────────────────────────────────────────────────────────────
  // Terminal Resize
  // ────────────────────────────────────────────────────────────

  void resize(int cols, int rows) {
    if (_state != TerminalConnectionState.connected || _channel == null) return;
    try {
      _channel!.sink.add(json.encode({'type': 'resize', 'cols': cols, 'rows': rows}));
    } catch (_) {}
  }

  // ────────────────────────────────────────────────────────────
  // Public controls
  // ────────────────────────────────────────────────────────────

  Future<void> reconnect() async {
    if (_disposed) return;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _setState(TerminalConnectionState.connecting);
    await _attemptConnect(primary: true);
  }

  Future<void> disconnect() async {
    _intentionalClose = true;
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _setState(TerminalConnectionState.disconnected);
    _writeStatus('\r\n[Disconnected]\r\n');
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
  }

  // ────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────

  void _setState(TerminalConnectionState s) {
    if (_state == s) return;
    _state = s;
    onStateChange?.call(s);
  }

  void _writeStatus(String msg) {
    // Dim gray system messages, doesn't interfere with shell output
    terminal.write('\r\x1b[2m\u276f $msg\x1b[0m\r\n');
  }
}
