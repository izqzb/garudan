import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../models/server_profile.dart';
import 'terminal_session.dart';

final terminalManagerProvider = ChangeNotifierProvider<TerminalManager>((ref) => TerminalManager());

class TerminalManager with ChangeNotifier {
  final List<TerminalSession> _sessions = [];
  int _activeIndex = 0;

  List<TerminalSession> get sessions => List.unmodifiable(_sessions);
  int get activeIndex => _activeIndex;
  int get count => _sessions.length;
  TerminalSession? get active => _sessions.isEmpty ? null : _sessions[_activeIndex];

  Future<TerminalSession> addSession(ServerProfile profile, {String? label}) async {
    if (_sessions.length >= AppConstants.maxTerminalTabs) throw StateError('Max tabs reached');
    final s = TerminalSession(profile: profile, label: label ?? 'Tab ${_sessions.length + 1}');
    _sessions.add(s); _activeIndex = _sessions.length - 1;
    notifyListeners();
    await s.connect();
    return s;
  }

  void setActive(int i) { if (i >= 0 && i < _sessions.length) { _activeIndex = i; notifyListeners(); } }

  Future<void> closeSession(String id) async {
    final i = _sessions.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final s = _sessions[i];
    await s.disconnect(); s.dispose(); _sessions.removeAt(i);
    if (_sessions.isEmpty) _activeIndex = 0;
    else if (_activeIndex >= _sessions.length) _activeIndex = _sessions.length - 1;
    notifyListeners();
  }

  Future<void> closeAll() async {
    for (final s in List.of(_sessions)) { await s.disconnect(); s.dispose(); }
    _sessions.clear(); _activeIndex = 0; notifyListeners();
  }

  @override
  void dispose() { for (final s in _sessions) { s.disconnect(); s.dispose(); } super.dispose(); }
}
