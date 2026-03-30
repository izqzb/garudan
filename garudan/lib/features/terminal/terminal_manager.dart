import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../models/server_profile.dart';
import 'terminal_session.dart';

final terminalManagerProvider = ChangeNotifierProvider<TerminalManager>((ref) {
  return TerminalManager();
});

class TerminalManager with ChangeNotifier {
  final List<TerminalSession> _sessions = [];
  int _activeIndex = 0;

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);
  int get activeIndex => _activeIndex;
  int get count => _sessions.length;

  TerminalSession? get activeSession =>
      _sessions.isEmpty ? null : _sessions[_activeIndex];

  // ── Create new tab ────────────────────────────────────────

  Future<TerminalSession> addSession(ServerProfile profile, {String? label}) async {
    if (_sessions.length >= AppConstants.maxTerminalTabs) {
      throw StateError('Maximum ${AppConstants.maxTerminalTabs} tabs allowed');
    }

    final session = TerminalSession(
      profile: profile,
      label: label ?? 'Tab ${_sessions.length + 1}',
    );

    _sessions.add(session);
    _activeIndex = _sessions.length - 1;
    notifyListeners();

    // Auto-connect
    await session.connect();
    return session;
  }

  // ── Switch tab ─────────────────────────────────────────────

  void setActiveIndex(int index) {
    if (index < 0 || index >= _sessions.length) return;
    _activeIndex = index;
    notifyListeners();
  }

  // ── Close tab ─────────────────────────────────────────────

  Future<void> closeSession(String sessionId) async {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx < 0) return;

    final session = _sessions[idx];
    await session.disconnect();
    session.dispose();

    _sessions.removeAt(idx);

    if (_sessions.isEmpty) {
      _activeIndex = 0;
    } else if (_activeIndex >= _sessions.length) {
      _activeIndex = _sessions.length - 1;
    }

    notifyListeners();
  }

  // ── Reconnect all ─────────────────────────────────────────

  Future<void> reconnectAll() async {
    for (final s in _sessions) {
      if (!s.isConnected) {
        await s.reconnect();
      }
    }
  }

  // ── Close all ─────────────────────────────────────────────

  Future<void> closeAll() async {
    for (final s in List.of(_sessions)) {
      await s.disconnect();
      s.dispose();
    }
    _sessions.clear();
    _activeIndex = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _sessions) {
      s.disconnect();
      s.dispose();
    }
    super.dispose();
  }
}
