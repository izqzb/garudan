import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xterm/xterm.dart';
import '../../core/constants.dart';
import '../../models/server_profile.dart';

enum TerminalConnectionState { idle, connecting, connected, reconnecting, disconnected, error }

class TerminalConnection {
  TerminalConnection({required this.id, required this.profile, required this.terminal, this.label, this.onStateChange, this.onError});

  final String id;
  final ServerProfile profile;
  final Terminal terminal;
  String? label;
  final void Function(TerminalConnectionState)? onStateChange;
  final void Function(String)? onError;

  TerminalConnectionState _state = TerminalConnectionState.idle;
  TerminalConnectionState get state => _state;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeat, _reconnectTimer;
  int _attempts = 0;
  bool _disposed = false, _intentionalClose = false, _usingFallback = false;
  final List<Uint8List> _buffer = [];
  DateTime? _connectedAt;
  Duration get uptime => _connectedAt != null ? DateTime.now().difference(_connectedAt!) : Duration.zero;

  String get _primaryUrl => profile.wsTerminalUrl;
  String? get _fallbackUrl => profile.wsFallbackUrl;

  Future<void> connect() async {
    if (_disposed) return;
    _intentionalClose = false;
    _setState(TerminalConnectionState.connecting);
    _writeStatus('Connecting to ${profile.name}...');
    await _attempt(primary: true);
  }

  Future<void> _attempt({required bool primary}) async {
    _usingFallback = !primary;
    final url = primary ? _primaryUrl : (_fallbackUrl ?? _primaryUrl);
    _writeStatus('Trying $url');
    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(url),
        connectTimeout: AppConstants.connectTimeout,
        pingInterval: AppConstants.heartbeatInterval,
      );
      final ready = Completer<void>();
      var first = false;
      _sub = _channel!.stream.listen(
        (data) { if (!first) { first = true; if (!ready.isCompleted) ready.complete(); } _onData(data); },
        onError: (e) { if (!ready.isCompleted) ready.completeError(e); else _handleDrop(e.toString()); },
        onDone: () { if (!ready.isCompleted) ready.completeError(Exception('closed')); else _handleDrop(null); },
        cancelOnError: false,
      );
      await Future.any([ready.future, Future.delayed(AppConstants.connectTimeout, () => throw TimeoutException('timeout'))]);
      _onConnected();
    } catch (e) {
      await _sub?.cancel(); _sub = null;
      try { _channel?.sink.close(); } catch (_) {}
      _channel = null;
      if (primary && _fallbackUrl != null) {
        _writeStatus('Primary failed. Trying fallback...');
        await _attempt(primary: false);
      } else {
        _writeStatus('Failed: $e');
        _setState(TerminalConnectionState.error);
        onError?.call(e.toString());
      }
    }
  }

  void _onConnected() {
    if (_disposed) return;
    _attempts = 0; _connectedAt = DateTime.now();
    _setState(TerminalConnectionState.connected);
    _writeStatus('Connected via ${_usingFallback ? "fallback" : "primary"} ✓\r\n');
    _startHeartbeat(); _flushBuffer();
  }

  void _onData(dynamic data) {
    if (_disposed) return;
    if (data is String) terminal.write(data);
    else if (data is List<int>) terminal.write(utf8.decode(data, allowMalformed: true));
  }

  void _handleDrop(String? reason) {
    if (_disposed || _intentionalClose) return;
    _stopHeartbeat();
    if (reason != null) _writeStatus('Dropped: $reason');
    _setState(TerminalConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeat = Timer.periodic(AppConstants.heartbeatInterval, (_) {
      if (_state == TerminalConnectionState.connected && _channel != null) {
        try { _channel!.sink.add(Uint8List.fromList([0x00])); } catch (_) {}
      }
    });
  }

  void _stopHeartbeat() { _heartbeat?.cancel(); _heartbeat = null; }

  void _scheduleReconnect() {
    if (_disposed || _intentionalClose) return;
    if (_attempts >= AppConstants.maxReconnectAttempts) {
      _writeStatus('Max reconnect attempts. Tap reconnect.\r\n');
      _setState(TerminalConnectionState.disconnected); return;
    }
    final delay = (2 << _attempts.clamp(0, 5)).clamp(2, 60);
    _writeStatus('Reconnecting in ${delay}s (attempt ${_attempts + 1})...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), () async {
      if (_disposed || _intentionalClose) return;
      _attempts++;
      await _sub?.cancel(); _sub = null;
      try { _channel?.sink.close(); } catch (_) {}
      _channel = null;
      await _attempt(primary: true);
    });
  }

  void sendInput(String data) => _sendBytes(Uint8List.fromList(utf8.encode(data)));
  void sendBytes(Uint8List b) => _sendBytes(b);

  void _sendBytes(Uint8List b) {
    if (_state == TerminalConnectionState.connected && _channel != null) {
      try { _channel!.sink.add(b); } catch (_) {}
    } else if (_state == TerminalConnectionState.connecting || _state == TerminalConnectionState.reconnecting) {
      _buffer.add(b);
      if (_buffer.length > 1000) _buffer.removeAt(0);
    }
  }

  void _flushBuffer() {
    for (final b in List.of(_buffer)) { _sendBytes(b); }
    _buffer.clear();
  }

  void resize(int cols, int rows) {
    if (_state != TerminalConnectionState.connected) return;
    try { _channel!.sink.add(json.encode({'type': 'resize', 'cols': cols, 'rows': rows})); } catch (_) {}
  }

  Future<void> reconnect() async {
    if (_disposed) return;
    _attempts = 0; _reconnectTimer?.cancel();
    await _sub?.cancel(); _sub = null;
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
    _setState(TerminalConnectionState.connecting);
    await _attempt(primary: true);
  }

  Future<void> disconnect() async {
    _intentionalClose = true; _stopHeartbeat(); _reconnectTimer?.cancel();
    await _sub?.cancel();
    try { _channel?.sink.close(); } catch (_) {}
    _channel = null;
    _setState(TerminalConnectionState.disconnected);
    _writeStatus('\r\n[Disconnected]\r\n');
  }

  Future<void> dispose() async { _disposed = true; await disconnect(); }

  void _setState(TerminalConnectionState s) {
    if (_state == s) return; _state = s; onStateChange?.call(s);
  }

  void _writeStatus(String msg) => terminal.write('\r\x1b[2m› $msg\x1b[0m\r\n');
}
