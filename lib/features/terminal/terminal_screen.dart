import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xterm/xterm.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/server_profile.dart';
import '../../services/foreground_service.dart';
import '../../services/haptic_service.dart';
import '../../services/storage_service.dart';
import 'terminal_connection.dart';
import 'terminal_manager.dart';
import 'terminal_session.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Terminal Screen — v1.3.0 (best-in-class rewrite)
// ──────────────────────────────────────────────────────────────────────────────

class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key, required this.profile});
  final ServerProfile profile;
  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen>
    with WidgetsBindingObserver {
  final _pageCtrl = PageController();
  int _activeIdx = 0;

  // Prefs
  double _fontSize = AppConstants.defaultFontSize;
  String _themeName = 'amoled';
  String _fontFamily = 'JetBrains Mono';

  // UI state
  bool _selectionMode = false;
  bool _showSnippetBar = true;
  bool _swipeLocked = false;
  bool _toolbarVisible = true;

  TerminalManager get _mgr => ref.read(terminalManagerProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
    TerminalForegroundService.instance.init();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await TerminalForegroundService.instance.requestBatteryExemption();
      FlutterForegroundTask.addTaskDataCallback(_onKeepAlive);
      await _openFirstSession();
    });
    try { WakelockPlus.enable(); } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    final s = ref.read(storageServiceProvider);
    setState(() {
      _fontSize   = s.getTerminalFontSize();
      _themeName  = s.getTerminalTheme();
      _fontFamily = s.getTerminalFontFamily();
    });
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Ensure foreground service is running when backgrounded
      TerminalForegroundService.instance.start(sessionCount: _mgr.count);
    } else if (state == AppLifecycleState.resumed) {
      // Ping all sessions — reconnect truly dead ones
      for (final s in _mgr.sessions) {
        _forceCheck(s);
      }
    }
  }

  /// Ping the SSH session to detect frozen connections (not just WebSocket state)
  Future<void> _forceCheck(TerminalSession session) async {
    if (!session.isConnected) {
      await session.reconnect();
      return;
    }
    // Send a null-byte ping — if WS is truly frozen, this will throw
    try {
      session.connection.sendBytes(
        Uint8List.fromList([0x00]),
      );
    } catch (_) {
      await session.reconnect();
    }
    if (mounted) setState(() {});
  }

  // Foreground task sends 'keepalive' every 20s — ping SSH
  void _onKeepAlive(Object data) {
    if (data != 'keepalive') return;
    for (final s in _mgr.sessions) {
      if (s.isConnected) {
        try {
          s.connection.sendBytes(Uint8List.fromList([0x00]));
        } catch (_) {
          _forceCheck(s);
        }
      }
    }
  }

  // ── Sessions ──────────────────────────────────────────────────────────────

  Future<void> _openFirstSession() async {
    await _addSession();
  }

  Future<void> _addSession() async {
    if (_mgr.count >= AppConstants.maxTerminalTabs) {
      _snack('Maximum ${AppConstants.maxTerminalTabs} tabs', isError: true);
      return;
    }
    final session = await _mgr.addSession(widget.profile);
    setState(() => _activeIdx = _mgr.count - 1);
    _animateTo(_activeIdx);
    await TerminalForegroundService.instance.start(sessionCount: _mgr.count);
    if (session.isConnected) {
      await HapticService.connected();
    } else {
      await HapticService.error();
    }
  }

  Future<void> _closeSession(int idx) async {
    await HapticService.heavy();
    final id = _mgr.sessions[idx].id;
    if (_mgr.count <= 1) {
      await _exitTerminal();
      return;
    }
    await _mgr.closeSession(id);
    setState(() {
      if (_activeIdx >= _mgr.count) _activeIdx = _mgr.count - 1;
    });
    await TerminalForegroundService.instance.updateCount(_mgr.count);
  }

  Future<void> _exitTerminal() async {
    FlutterForegroundTask.removeTaskDataCallback(_onKeepAlive);
    await _mgr.closeAll();
    await TerminalForegroundService.instance.stop();
    try { WakelockPlus.disable(); } catch (_) {}
    if (mounted) context.pop();
  }

  void _animateTo(int idx) {
    if (_swipeLocked || !_pageCtrl.hasClients) return;
    _pageCtrl.animateToPage(idx,
        duration: const Duration(milliseconds: 220), curve: Curves.easeInOut);
  }

  // ── Paste ─────────────────────────────────────────────────────────────────

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) return;
    final text = data.text!;
    final s = _active;
    if (s == null) return;
    await HapticService.medium();
    if (text.contains('\n')) {
      // Bracketed paste — multi-line goes in as one block
      s.sendInput('\x1b[200~$text\x1b[201~');
    } else {
      s.sendInput(text);
    }
  }

  // ── Selection mode ────────────────────────────────────────────────────────

  Future<void> _copySelection() async {
    final s = _active;
    if (s == null) return;
    // Get visible buffer text
    final lines = <String>[];
    final buf = s.terminal.buffer;
    final start = max(0, buf.lines.length - 300);
    for (int i = start; i < buf.lines.length; i++) {
      lines.add(buf.lines[i].toString().trimRight());
    }
    while (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    final text = lines.join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    await HapticService.success();
    _snack('Copied to clipboard');
    setState(() => _selectionMode = false);
  }

  // ── Snackbar ──────────────────────────────────────────────────────────────

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError
          ? const Color(0xFFFF5370).withValues(alpha: 0.9)
          : const Color(0xFF1DB954).withValues(alpha: 0.9),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  TerminalSession? get _active =>
      _mgr.sessions.isNotEmpty ? _mgr.sessions[_activeIdx] : null;

  TerminalTheme get _theme => GarudanTerminalThemes.fromName(
      TerminalThemeName.values.firstWhere((t) => t.name == _themeName,
          orElse: () => TerminalThemeName.amoled));

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onKeepAlive);
    WidgetsBinding.instance.removeObserver(this);
    _pageCtrl.dispose();
    try { WakelockPlus.disable(); } catch (_) {}
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mgr = ref.watch(terminalManagerProvider);
    final fgRunning = TerminalForegroundService.instance.isRunning;

    if (mgr.sessions.isEmpty) {
      return _EmptyState(onNew: _addSession, fgRunning: fgRunning);
    }

    final session = mgr.sessions[_activeIdx];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _exitTerminal(),
      child: WithForegroundTask(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.black,
          ),
          child: Scaffold(
            backgroundColor: _theme.background,
            body: SafeArea(
              child: OrientationBuilder(builder: (context, orientation) {
                return Column(children: [
                  // ── App bar ────────────────────────────────────────────
                  _TerminalAppBar(
                    profile: widget.profile,
                    session: session,
                    fgRunning: fgRunning,
                    onBack: _exitTerminal,
                    onNewTab: _addSession,
                    onTheme: _showThemePicker,
                    onFont: _showFontPicker,
                    onHistory: _showHistory,
                    onSnippetManager: _showSnippetManager,
                  ),

                  // ── Tab bar (only when 2+ sessions) ───────────────────
                  if (mgr.count >= 2)
                    _SessionTabBar(
                      sessions: mgr.sessions,
                      activeIdx: _activeIdx,
                      onTap: (i) {
                        setState(() => _activeIdx = i);
                        _animateTo(i);
                      },
                      onClose: _closeSession,
                    ),

                  // ── Terminal view ──────────────────────────────────────
                  Expanded(
                    child: orientation == Orientation.landscape && mgr.count >= 2
                        ? _SplitView(
                            sessions: mgr.sessions,
                            theme: _theme,
                            fontSize: _fontSize,
                            fontFamily: _fontFamily,
                          )
                        : _selectionMode
                            ? _SelectionTerminal(
                                session: session,
                                theme: _theme,
                                fontSize: _fontSize,
                                fontFamily: _fontFamily,
                                onDone: () =>
                                    setState(() => _selectionMode = false),
                              )
                            : PageView.builder(
                                controller: _pageCtrl,
                                physics: _swipeLocked
                                    ? const NeverScrollableScrollPhysics()
                                    : const BouncingScrollPhysics(),
                                onPageChanged: (i) =>
                                    setState(() => _activeIdx = i),
                                itemCount: mgr.count,
                                itemBuilder: (_, i) => _TerminalPage(
                                  session: mgr.sessions[i],
                                  theme: _theme,
                                  fontSize: _fontSize,
                                  fontFamily: _fontFamily,
                                  isActive: i == _activeIdx,
                                  onScaleStart: () {},
                                  onScaleUpdate: (scale) async {
                                    final base = _fontSize;
                                    final v = (base * scale).clamp(
                                        AppConstants.minFontSize,
                                        AppConstants.maxFontSize);
                                    setState(() => _fontSize = v);
                                    await ref
                                        .read(storageServiceProvider)
                                        .setTerminalFontSize(v);
                                  },
                                  onLongPress: () =>
                                      setState(() => _selectionMode = true),
                                ),
                              ),
                  ),

                  // ── Selection bar ──────────────────────────────────────
                  if (_selectionMode)
                    _SelectionBar(
                      onCopy: _copySelection,
                      onPaste: () async {
                        setState(() => _selectionMode = false);
                        await _paste();
                      },
                      onSelectAll: () {
                        _active?.sendInput('\x01');
                        HapticService.light();
                      },
                      onClear: () {
                        _active?.sendInput('clear\n');
                        setState(() => _selectionMode = false);
                      },
                      onDone: () =>
                          setState(() => _selectionMode = false),
                    ),

                  // ── Keyboard toolbar ───────────────────────────────────
                  if (!_selectionMode && _toolbarVisible)
                    _KeyboardToolbar(
                      session: session,
                      showSnippetBar: _showSnippetBar,
                      swipeLocked: _swipeLocked,
                      onPaste: _paste,
                      onToggleSnippets: () {
                        HapticService.light();
                        setState(() => _showSnippetBar = !_showSnippetBar);
                      },
                      onToggleSwipeLock: () {
                        HapticService.medium();
                        setState(() => _swipeLocked = !_swipeLocked);
                      },
                      onSelectMode: () {
                        HapticService.medium();
                        setState(() => _selectionMode = true);
                      },
                      onToggleToolbar: () =>
                          setState(() => _toolbarVisible = !_toolbarVisible),
                    ),

                  // Show toolbar toggle when hidden
                  if (!_toolbarVisible)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _toolbarVisible = true),
                      child: Container(
                        width: double.infinity,
                        height: 20,
                        color: Colors.black,
                        child: const Icon(Icons.keyboard_arrow_up,
                            size: 16, color: Color(0xFF444444)),
                      ),
                    ),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sheets ────────────────────────────────────────────────────────────────

  void _showThemePicker() {
    HapticService.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        _sheetHandle(),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Terminal Theme',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
        ),
        ...TerminalThemeName.values.map((t) {
          final th = GarudanTerminalThemes.fromName(t);
          return ListTile(
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              _swatch(th.background),
              const SizedBox(width: 2),
              _swatch(th.green),
              const SizedBox(width: 2),
              _swatch(th.blue),
            ]),
            title: Text(t.label,
                style: const TextStyle(color: Colors.white)),
            trailing: _themeName == t.name
                ? const Icon(Icons.check, color: Color(0xFF7C83FD))
                : null,
            onTap: () async {
              await HapticService.light();
              setState(() => _themeName = t.name);
              await ref
                  .read(storageServiceProvider)
                  .setTerminalTheme(t.name);
              if (mounted) Navigator.pop(context);
            },
          );
        }),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _swatch(Color c) => Container(width: 14, height: 14, color: c);

  void _showFontPicker() {
    HapticService.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _FontPicker(
        currentFont: _fontFamily,
        currentSize: _fontSize,
        onFontChanged: (f) async {
          setState(() => _fontFamily = f);
          await ref.read(storageServiceProvider).setTerminalFontFamily(f);
        },
        onSizeChanged: (s) async {
          setState(() => _fontSize = s);
          await ref.read(storageServiceProvider).setTerminalFontSize(s);
        },
      ),
    );
  }

  void _showHistory() {
    final s = _active;
    if (s == null) return;
    HapticService.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _HistorySheet(
        session: s,
        onRun: (cmd) {
          s.sendInput('$cmd\n');
          HapticService.medium();
        },
      ),
    );
  }

  void _showSnippetManager() {
    HapticService.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SnippetManager(
        onRun: (cmd) {
          _active?.sendInput(cmd);
          HapticService.medium();
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Empty State
// ──────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew, required this.fgRunning});
  final VoidCallback onNew;
  final bool fgRunning;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Terminal'),
        ),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.terminal,
                color: Color(0xFF444444), size: 64),
            const SizedBox(height: 16),
            const Text('No sessions',
                style: TextStyle(
                    color: Color(0xFF888888), fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              fgRunning
                  ? 'SSH stays alive via foreground service'
                  : 'SSH foreground service ready',
              style: const TextStyle(
                  color: Color(0xFF555555), fontSize: 12),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add),
              label: const Text('New Session'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C83FD),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
              ),
            ),
          ]),
        ),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// App Bar
// ──────────────────────────────────────────────────────────────────────────────

class _TerminalAppBar extends StatelessWidget {
  const _TerminalAppBar({
    required this.profile,
    required this.session,
    required this.fgRunning,
    required this.onBack,
    required this.onNewTab,
    required this.onTheme,
    required this.onFont,
    required this.onHistory,
    required this.onSnippetManager,
  });

  final ServerProfile profile;
  final TerminalSession session;
  final bool fgRunning;
  final VoidCallback onBack, onNewTab, onTheme, onFont, onHistory,
      onSnippetManager;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.chevron_left,
              color: Color(0xFF888888)),
          onPressed: () {
            HapticService.light();
            onBack();
          },
          padding: const EdgeInsets.all(4),
          constraints:
              const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        // Connection dot
        ListenableBuilder(
          listenable: session,
          builder: (_, __) {
            final color =
                switch (session.connectionState) {
              TerminalConnectionState.connected =>
                const Color(0xFF1DB954),
              TerminalConnectionState.connecting =>
                const Color(0xFFFFB74D),
              TerminalConnectionState.reconnecting =>
                const Color(0xFFFFB74D),
              _ => const Color(0xFFEF5350),
            };
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color),
            );
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            profile.name,
            style: const TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 15,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // LIVE badge
        if (fgRunning)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1DB954).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('LIVE',
                style: TextStyle(
                    color: Color(0xFF1DB954),
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        _btn(Icons.history, onHistory, 'History'),
        _btn(Icons.palette_outlined, onTheme, 'Theme'),
        _btn(Icons.format_size, onFont, 'Font'),
        _btn(Icons.bolt, onSnippetManager, 'Snippets'),
        _btn(Icons.add, onNewTab, 'New tab'),
      ]),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap, String tooltip) =>
      IconButton(
        icon: Icon(icon, size: 18, color: const Color(0xFF888888)),
        onPressed: () {
          HapticService.light();
          onTap();
        },
        tooltip: tooltip,
        padding: const EdgeInsets.all(6),
        constraints:
            const BoxConstraints(minWidth: 32, minHeight: 32),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Session Tab Bar
// ──────────────────────────────────────────────────────────────────────────────

class _SessionTabBar extends StatelessWidget {
  const _SessionTabBar({
    required this.sessions,
    required this.activeIdx,
    required this.onTap,
    required this.onClose,
  });

  final List<TerminalSession> sessions;
  final int activeIdx;
  final void Function(int) onTap, onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: const Color(0xFF0D0D0D),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sessions.length,
        itemBuilder: (_, i) {
          final s = sessions[i];
          final active = i == activeIdx;
          return GestureDetector(
            onTap: () {
              HapticService.light();
              onTap(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF1A1A1A)
                    : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: active
                        ? const Color(0xFF7C83FD)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(children: [
                ListenableBuilder(
                  listenable: s,
                  builder: (_, __) {
                    final color =
                        switch (s.connectionState) {
                      TerminalConnectionState.connected =>
                        const Color(0xFF1DB954),
                      TerminalConnectionState.connecting =>
                        const Color(0xFFFFB74D),
                      TerminalConnectionState.reconnecting =>
                        const Color(0xFFFFB74D),
                      _ => const Color(0xFFEF5350),
                    };
                    return Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: color),
                    );
                  },
                ),
                const SizedBox(width: 7),
                Text(
                  s.label,
                  style: TextStyle(
                    color: active
                        ? const Color(0xFFE0E0E0)
                        : const Color(0xFF888888),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onClose(i),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: active
                        ? const Color(0xFF888888)
                        : const Color(0xFF555555),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Terminal Page (single tab)
// ──────────────────────────────────────────────────────────────────────────────

class _TerminalPage extends StatefulWidget {
  const _TerminalPage({
    required this.session,
    required this.theme,
    required this.fontSize,
    required this.fontFamily,
    required this.isActive,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onLongPress,
  });

  final TerminalSession session;
  final TerminalTheme theme;
  final double fontSize;
  final String fontFamily;
  final bool isActive;
  final VoidCallback onScaleStart, onLongPress;
  final void Function(double) onScaleUpdate;

  @override
  State<_TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<_TerminalPage> {
  final _scrollCtrl = ScrollController();
  bool _showScrollBtn = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final atBottom = _scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 80;
    if (_showScrollBtn == atBottom) {
      setState(() => _showScrollBtn = !atBottom);
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (_, __) => Stack(children: [
        // Terminal
        GestureDetector(
          onScaleStart: (_) => widget.onScaleStart(),
          onScaleUpdate: (d) {
            if (d.pointerCount >= 2) widget.onScaleUpdate(d.scale);
          },
          onLongPress: () {
            HapticService.medium();
            widget.onLongPress();
          },
          child: TerminalView(
            widget.session.terminal,
            theme: widget.theme,
            textStyle: TerminalStyle(
              fontSize: widget.fontSize,
              fontFamily: widget.fontFamily,
              fontFamilyFallback: const [
                'JetBrains Mono',
                'Fira Code',
                'Courier New',
                'monospace',
              ],
            ),
            padding: const EdgeInsets.all(6),
            autofocus: widget.isActive,
            backgroundOpacity: 1.0,
            scrollController: _scrollCtrl,
          ),
        ),

        // Scroll to bottom
        if (_showScrollBtn)
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                HapticService.light();
                _scrollToBottom();
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C83FD),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 8)
                  ],
                ),
                child: const Icon(Icons.keyboard_arrow_down,
                    color: Colors.black, size: 22),
              ),
            ),
          ),

        // Reconnect banner
        if (widget.session.hasError ||
            widget.session.connectionState ==
                TerminalConnectionState.disconnected)
          Positioned(
            bottom: 12,
            left: 12,
            right: 56,
            child: _ReconnectBanner(
              session: widget.session,
              onRetry: () => widget.session.reconnect(),
            ),
          ),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Selection Terminal (read-only for copy mode)
// ──────────────────────────────────────────────────────────────────────────────

class _SelectionTerminal extends StatelessWidget {
  const _SelectionTerminal({
    required this.session,
    required this.theme,
    required this.fontSize,
    required this.fontFamily,
    required this.onDone,
  });

  final TerminalSession session;
  final TerminalTheme theme;
  final double fontSize;
  final String fontFamily;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onDone,
        child: TerminalView(
          session.terminal,
          theme: theme,
          textStyle: TerminalStyle(
            fontSize: fontSize,
            fontFamily: fontFamily as String,
          ),
          readOnly: true,
          autofocus: false,
          backgroundOpacity: 1.0,
        ),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Selection Bar
// ──────────────────────────────────────────────────────────────────────────────

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.onCopy,
    required this.onPaste,
    required this.onSelectAll,
    required this.onClear,
    required this.onDone,
  });

  final VoidCallback onCopy, onPaste, onSelectAll, onClear, onDone;

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF0D0D0D),
        padding:
            const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(children: [
          _SBtn('Copy', Icons.copy, const Color(0xFF4FC3F7), onCopy),
          _SBtn('Paste', Icons.paste, const Color(0xFF1DB954), onPaste),
          _SBtn('All', Icons.select_all, const Color(0xFFCE93D8),
              onSelectAll),
          _SBtn('Clear', Icons.clear_all, const Color(0xFFFFB74D),
              onClear),
          const Spacer(),
          TextButton(
            onPressed: () {
              HapticService.light();
              onDone();
            },
            child: const Text('Done',
                style: TextStyle(
                    color: Color(0xFF7C83FD),
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      );
}

class _SBtn extends StatelessWidget {
  const _SBtn(this.label, this.icon, this.color, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () {
          HapticService.light();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10)),
          ]),
        ),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Keyboard Toolbar — the best mobile terminal toolbar
// ──────────────────────────────────────────────────────────────────────────────

class _KeyboardToolbar extends StatelessWidget {
  const _KeyboardToolbar({
    required this.session,
    required this.showSnippetBar,
    required this.swipeLocked,
    required this.onPaste,
    required this.onToggleSnippets,
    required this.onToggleSwipeLock,
    required this.onSelectMode,
    required this.onToggleToolbar,
  });

  final TerminalSession session;
  final bool showSnippetBar, swipeLocked;
  final Future<void> Function() onPaste;
  final VoidCallback onToggleSnippets, onToggleSwipeLock, onSelectMode,
      onToggleToolbar;

  void _send(String s) {
    HapticService.keyClick();
    session.sendInput(s);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D0D),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: 0.5, color: const Color(0xFF2A2A2A)),

        // ── Snippet bar ────────────────────────────────────────────────
        if (showSnippetBar)
          SizedBox(
            height: 36,
            child: Row(children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: _kSnippets
                      .map((s) => GestureDetector(
                            onTap: () {
                              HapticService.light();
                              session.sendInput('${s.$1}\n');
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 3, vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFF2A2A2A)),
                              ),
                              child: Text(s.$2,
                                  style: const TextStyle(
                                      color: Color(0xFFB0B0B0),
                                      fontSize: 12)),
                            ),
                          ))
                      .toList(),
                ),
              ),
              GestureDetector(
                onTap: onToggleSnippets,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: const Icon(Icons.bolt,
                      color: Color(0xFFFFB74D), size: 18),
                ),
              ),
            ]),
          ),

        // ── Key row ────────────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(children: [
            _TK('ESC', () => _send('\x1b')),
            _TK('TAB', () => _send('\t')),
            _CtrlKey(session: session),
            _SymKey(session: session),
            _TK('↑', () => _send('\x1b[A')),
            _TK('↓', () => _send('\x1b[B')),
            _TK('←', () => _send('\x1b[D')),
            _TK('→', () => _send('\x1b[C')),
            _TK('PgUp', () => _send('\x1b[5~')),
            _TK('PgDn', () => _send('\x1b[6~')),
            _TK('Home', () => _send('\x1b[H')),
            _TK('End', () => _send('\x1b[F')),
            _TK('DEL', () => _send('\x1b[3~')),
            _TK('|', () => _send('|')),
            _TK('~', () => _send('~')),
            _TK('/', () => _send('/')),
            _TK('-', () => _send('-')),
            // Paste key
            GestureDetector(
              onTap: () {
                HapticService.medium();
                onPaste();
              },
              child: _keyBox(
                child: const Text('PASTE',
                    style: TextStyle(
                        color: Color(0xFF1DB954),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                accent: const Color(0xFF1DB954),
              ),
            ),
            // Select mode
            GestureDetector(
              onTap: onSelectMode,
              child: _keyBox(
                child: const Icon(Icons.select_all,
                    color: Color(0xFFCE93D8), size: 16),
                accent: const Color(0xFFCE93D8),
              ),
            ),
            // Swipe lock
            GestureDetector(
              onTap: onToggleSwipeLock,
              child: _keyBox(
                child: Icon(
                    swipeLocked ? Icons.lock : Icons.swipe,
                    color: swipeLocked
                        ? const Color(0xFFEF5350)
                        : const Color(0xFF888888),
                    size: 16),
                accent: swipeLocked
                    ? const Color(0xFFEF5350)
                    : null,
              ),
            ),
            // Hide toolbar
            GestureDetector(
              onTap: onToggleToolbar,
              child: _keyBox(
                child: const Icon(Icons.keyboard_hide,
                    color: Color(0xFF666666), size: 16),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 2),
      ]),
    );
  }

  Widget _TK(String label, VoidCallback onTap) => GestureDetector(
        onTap: () {
          HapticService.keyClick();
          onTap();
        },
        child: _keyBox(
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFFD0D0D0), fontSize: 12)),
        ),
      );

  Widget _keyBox({required Widget child, Color? accent}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: accent != null
              ? accent.withValues(alpha: 0.12)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: accent != null
                ? accent.withValues(alpha: 0.35)
                : const Color(0xFF2A2A2A),
          ),
        ),
        child: child,
      );
}

// ── CTRL key with full popup grid ─────────────────────────────────────────────

class _CtrlKey extends StatelessWidget {
  const _CtrlKey({required this.session});
  final TerminalSession session;

  static const _keys = [
    ('C', '\x03', 'Interrupt'),
    ('D', '\x04', 'Logout'),
    ('Z', '\x1a', 'Suspend'),
    ('L', '\x0c', 'Clear'),
    ('A', '\x01', 'Line start'),
    ('E', '\x05', 'Line end'),
    ('U', '\x15', 'Kill line'),
    ('W', '\x17', 'Kill word'),
    ('R', '\x12', 'Rev search'),
    ('K', '\x0b', 'Kill to end'),
    ('P', '\x10', 'Prev cmd'),
    ('N', '\x0e', 'Next cmd'),
    ('B', '\x02', 'Back char'),
    ('F', '\x06', 'Fwd char'),
    ('T', '\x14', 'Swap chars'),
    ('G', '\x07', 'Cancel'),
    ('H', '\x08', 'Backspace'),
    ('Q', '\x11', 'Resume'),
    ('S', '\x13', 'Pause'),
    ('V', '\x16', 'Literal'),
    ('X', '\x18', 'Exit emacs'),
    ('Y', '\x19', 'Yank'),
    ('\\', '\x1c', 'Quit'),
    ('[', '\x1b', 'ESC'),
  ];

  // Highlight dangerous keys in red
  static const _danger = {'C', 'D', 'Z', '\\'};
  static const _warn   = {'U', 'W', 'K'};

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticService.medium();
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF141414),
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16))),
            builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
              _sheetHandle(),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('CTRL',
                    style: TextStyle(
                        color: Color(0xFF9FA8DA),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2)),
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _keys
                      .map((k) => GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              if (k.$1 == 'C') {
                                HapticService.heavy();
                              } else {
                                HapticService.light();
                              }
                              session.sendInput(k.$2);
                            },
                            child: Container(
                              width: 72,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius:
                                    BorderRadius.circular(8),
                                border: Border.all(
                                  color: _danger.contains(k.$1)
                                      ? const Color(0xFFEF5350)
                                          .withValues(alpha: 0.6)
                                      : _warn.contains(k.$1)
                                          ? const Color(0xFFFFB74D)
                                              .withValues(alpha: 0.5)
                                          : const Color(0xFF2A2A2A),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '^${k.$1}',
                                    style: TextStyle(
                                      color: _danger.contains(k.$1)
                                          ? const Color(0xFFEF5350)
                                          : _warn.contains(k.$1)
                                              ? const Color(0xFFFFB74D)
                                              : const Color(0xFF4FC3F7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  Text(
                                    k.$3,
                                    style: const TextStyle(
                                        color: Color(0xFF666666),
                                        fontSize: 8),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ]),
          );
        },
        child: Container(
          margin:
              const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF4FC3F7).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: const Color(0xFF4FC3F7).withValues(alpha: 0.35)),
          ),
          child: const Text('CTRL ▼',
              style: TextStyle(
                  color: Color(0xFF4FC3F7),
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      );
}

// ── SYM key — symbols + F-keys ────────────────────────────────────────────────

class _SymKey extends StatelessWidget {
  const _SymKey({required this.session});
  final TerminalSession session;

  static const _syms = [
    ('!', '!'), ('@', '@'), ('#', '#'), (r'$', r'$'),
    ('%', '%'), ('^', '^'), ('&', '&'), ('*', '*'),
    ('(', '('), (')', ')'), ('_', '_'), ('+', '+'),
    ('{', '{'), ('}', '}'), ('|', '|'), (r'\', r'\'),
    (':', ':'), ('"', '"'), ('<', '<'), ('>', '>'),
    ('?', '?'), ('`', '`'), ("'", "'"), (' ', ' '),
    ('F1', '\x1bOP'), ('F2', '\x1bOQ'), ('F3', '\x1bOR'),
    ('F4', '\x1bOS'), ('F5', '\x1b[15~'), ('F6', '\x1b[17~'),
    ('F7', '\x1b[18~'), ('F8', '\x1b[19~'), ('F9', '\x1b[20~'),
    ('F10', '\x1b[21~'), ('F11', '\x1b[23~'), ('F12', '\x1b[24~'),
  ];

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticService.medium();
          showModalBottomSheet(
            context: context,
            backgroundColor: const Color(0xFF141414),
            shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16))),
            builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
              _sheetHandle(),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('SYMBOLS / F-KEYS',
                    style: TextStyle(
                        color: Color(0xFF9FA8DA),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ),
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _syms
                      .map((s) => GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              HapticService.light();
                              session.sendInput(s.$2);
                            },
                            child: Container(
                              width: 48,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                borderRadius:
                                    BorderRadius.circular(8),
                                border: Border.all(
                                    color: s.$1.startsWith('F')
                                        ? const Color(0xFFCE93D8)
                                            .withValues(alpha: 0.4)
                                        : const Color(0xFF2A2A2A)),
                              ),
                              child: Center(
                                child: Text(
                                  s.$1,
                                  style: TextStyle(
                                    color: s.$1.startsWith('F')
                                        ? const Color(0xFFCE93D8)
                                        : const Color(0xFFE0E0E0),
                                    fontSize:
                                        s.$1.length > 2 ? 11 : 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ]),
          );
        },
        child: Container(
          margin:
              const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color:
                const Color(0xFFCE93D8).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: const Color(0xFFCE93D8).withValues(alpha: 0.35)),
          ),
          child: const Text('SYM ▼',
              style: TextStyle(
                  color: Color(0xFFCE93D8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Split View (landscape with 2+ sessions)
// ──────────────────────────────────────────────────────────────────────────────

class _SplitView extends StatelessWidget {
  const _SplitView({
    required this.sessions,
    required this.theme,
    required this.fontSize,
    required this.fontFamily,
  });

  final List<TerminalSession> sessions;
  final TerminalTheme theme;
  final double fontSize;
  final String fontFamily;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: TerminalView(
            sessions[0].terminal,
            theme: theme,
            textStyle: TerminalStyle(
                fontSize: fontSize, fontFamily: fontFamily),
          ),
        ),
        Container(width: 1, color: const Color(0xFF2A2A2A)),
        Expanded(
          child: TerminalView(
            sessions[min(1, sessions.length - 1)].terminal,
            theme: theme,
            textStyle: TerminalStyle(
                fontSize: fontSize, fontFamily: fontFamily),
          ),
        ),
      ]);
}

// ──────────────────────────────────────────────────────────────────────────────
// Reconnect Banner
// ──────────────────────────────────────────────────────────────────────────────

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner(
      {required this.session, required this.onRetry});
  final TerminalSession session;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEF5350)),
        ),
        child: Row(children: [
          const Icon(Icons.wifi_off,
              color: Color(0xFFEF5350), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              session.lastError ?? 'Connection lost',
              style: const TextStyle(
                  color: Color(0xFFE0E0E0), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticService.medium();
              onRetry();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF7C83FD),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Retry',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Font Picker
// ──────────────────────────────────────────────────────────────────────────────

class _FontPicker extends StatefulWidget {
  const _FontPicker({
    required this.currentFont,
    required this.currentSize,
    required this.onFontChanged,
    required this.onSizeChanged,
  });

  final String currentFont;
  final double currentSize;
  final void Function(String) onFontChanged;
  final void Function(double) onSizeChanged;

  @override
  State<_FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<_FontPicker> {
  late String _font;
  late double _size;

  static const _fonts = [
    'JetBrains Mono',
    'Fira Code',
    'Hack',
    'Cascadia Code',
    'Source Code Pro',
    'Courier New',
    'monospace',
  ];

  @override
  void initState() {
    super.initState();
    _font = widget.currentFont;
    _size = widget.currentSize;
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _sheetHandle(),
      const Text('Font',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16)),
      const SizedBox(height: 12),
      SizedBox(
        height: 210,
        child: ListView(
          children: _fonts
              .map((f) => ListTile(
                    title: Text(f,
                        style: TextStyle(
                            fontFamily: f,
                            color: Colors.white,
                            fontSize: 14)),
                    subtitle: Text('AaBb 0O1lI \$ # @',
                        style: TextStyle(
                            fontFamily: f,
                            color: const Color(0xFF888888),
                            fontSize: 11)),
                    trailing: _font == f
                        ? const Icon(Icons.check,
                            color: Color(0xFF7C83FD))
                        : null,
                    onTap: () {
                      HapticService.light();
                      setState(() => _font = f);
                      widget.onFontChanged(f);
                    },
                  ))
              .toList(),
        ),
      ),
      const Divider(color: Color(0xFF2A2A2A)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          Text('Size: ${_size.toInt()}px',
              style: const TextStyle(
                  color: Color(0xFF7C83FD),
                  fontWeight: FontWeight.w600)),
          Expanded(
            child: Slider(
              value: _size,
              min: AppConstants.minFontSize,
              max: AppConstants.maxFontSize,
              divisions: 20,
              activeColor: const Color(0xFF7C83FD),
              onChanged: (v) {
                setState(() => _size = v);
                widget.onSizeChanged(v);
              },
            ),
          ),
        ]),
      ),
      // Preview
      Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'lazyraion@garuda:~\$ ls -la\ndrwxr-xr-x 2 user user 4096',
          style: TextStyle(
            fontFamily: _font,
            fontSize: _size,
            color: const Color(0xFF1DB954),
            height: 1.5,
          ),
        ),
      ),
    ]);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// History Sheet
// ──────────────────────────────────────────────────────────────────────────────

class _HistorySheet extends StatefulWidget {
  const _HistorySheet({required this.session, required this.onRun});
  final TerminalSession session;
  final void Function(String) onRun;

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  @override
  Widget build(BuildContext context) {
    final history = widget.session.commandHistory;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, ctrl) => Column(children: [
        _sheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
          child: Row(children: [
            const Text('Command History',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            if (history.isNotEmpty)
              TextButton(
                onPressed: () {
                  widget.session.commandHistory.clear();
                  setState(() {});
                },
                child: const Text('Clear',
                    style: TextStyle(color: Color(0xFFEF5350))),
              ),
          ]),
        ),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('No history yet',
                style: TextStyle(color: Color(0xFF666666))),
          )
        else
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: history.length,
              itemBuilder: (_, i) {
                final cmd =
                    history[history.length - 1 - i];
                return ListTile(
                  leading: const Icon(Icons.chevron_right,
                      color: Color(0xFF7C83FD), size: 18),
                  title: Text(cmd,
                      style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 13)),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onRun('$cmd\n');
                  },
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.copy,
                          size: 16, color: Color(0xFF888888)),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: cmd));
                        Navigator.pop(context);
                        HapticService.success();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.send,
                          size: 16, color: Color(0xFF7C83FD)),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onRun('$cmd\n');
                      },
                    ),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Snippet Manager
// ──────────────────────────────────────────────────────────────────────────────

class _SnippetManager extends StatefulWidget {
  const _SnippetManager({required this.onRun});
  final void Function(String) onRun;

  @override
  State<_SnippetManager> createState() => _SnippetManagerState();
}

class _SnippetManagerState extends State<_SnippetManager> {
  final _snippets = [..._kSnippets.map((s) => (s.$1, s.$2))];
  final _labelCtrl = TextEditingController();
  final _cmdCtrl = TextEditingController();

  @override
  void dispose() {
    _labelCtrl.dispose();
    _cmdCtrl.dispose();
    super.dispose();
  }

  void _add() {
    if (_labelCtrl.text.isEmpty || _cmdCtrl.text.isEmpty) return;
    final cmd = _cmdCtrl.text.trim();
    setState(() {
      _snippets.add((cmd, _labelCtrl.text.trim()));
      _labelCtrl.clear();
      _cmdCtrl.clear();
    });
    HapticService.success();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _sheetHandle(),
            const Text('Snippets',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: _snippets.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(_snippets[i].$2,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(_snippets[i].$1,
                      style: const TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 11,
                          fontFamily: 'monospace'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.play_arrow,
                          color: Color(0xFF7C83FD)),
                      onPressed: () {
                        widget.onRun(
                            '${_snippets[i].$1}\n');
                        Navigator.pop(context);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Color(0xFFEF5350)),
                      onPressed: () {
                        HapticService.medium();
                        setState(
                            () => _snippets.removeAt(i));
                      },
                    ),
                  ]),
                ),
              ),
            ),
            const Divider(color: Color(0xFF2A2A2A)),
            TextField(
              controller: _labelCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                  labelText: 'Label', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cmdCtrl,
              style: const TextStyle(
                  color: Colors.white, fontFamily: 'monospace'),
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Command', isDense: true),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: _add,
                  child: const Text('Add Snippet')),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ──────────────────────────────────────────────────────────────────────────────

Widget _sheetHandle() => Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: const Color(0xFF444444),
          borderRadius: BorderRadius.circular(2)),
    );

// Default snippet bar items: (command, display label)
const _kSnippets = [
  ('htop', 'htop'),
  ('docker ps', 'docker ps'),
  ('df -h', 'df -h'),
  ('free -h', 'free -h'),
  ('uptime', 'uptime'),
  ('ss -tlnp', 'ports'),
  ('journalctl -f', 'logs'),
  ('ls -la', 'ls'),
  ('clear', 'clear'),
  ('exit', 'exit'),
];
