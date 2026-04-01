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
import '../../services/storage_service.dart';
import 'keyboard_toolbar.dart';
import 'terminal_connection.dart';
import 'terminal_manager.dart';
import 'terminal_session.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key, required this.profile});
  final ServerProfile profile;
  @override
  ConsumerState<TerminalScreen> createState() => _State();
}

class _State extends ConsumerState<TerminalScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabs;
  double _fontSize = AppConstants.defaultFontSize;
  String _themeName = 'amoled';
  String _fontFamily = 'JetBrains Mono';
  bool _toolbarVisible = true;
  bool _keepScreenOn = true;
  double _pinchStart = 0;

  // Text selection state
  bool _selectionMode = false;
  String _selectedText = '';

  TerminalManager get _mgr => ref.read(terminalManagerProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs = TabController(length: 0, vsync: this);
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFirst());
    _startForegroundService();
    if (_keepScreenOn) WakelockPlus.enable();
  }

  Future<void> _loadPrefs() async {
    final s = ref.read(storageServiceProvider);
    setState(() {
      _fontSize = s.getTerminalFontSize();
      _themeName = s.getTerminalTheme();
      _fontFamily = s.getTerminalFontFamily();
    });
  }

  Future<void> _startForegroundService() async {
    await TerminalForegroundService.instance.init();
    await TerminalForegroundService.instance.start(widget.profile.name);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App going to background — foreground service keeps WS alive
    if (state == AppLifecycleState.paused) {
      // Service is already running, connections stay alive
    } else if (state == AppLifecycleState.resumed) {
      // Check and reconnect any dropped sessions
      final mgr = ref.read(terminalManagerProvider);
      for (final session in mgr.sessions) {
        if (!session.isConnected && !session.isReconnecting) {
          session.reconnect();
        }
      }
    }
  }

  TerminalTheme get _theme => GarudanTerminalThemes.fromName(
      TerminalThemeName.values.firstWhere(
          (t) => t.name == _themeName,
          orElse: () => TerminalThemeName.amoled));

  Future<void> _openFirst() async {
    await _mgr.addSession(widget.profile);
    _rebuild();
  }

  void _rebuild() {
    final len = _mgr.count;
    _tabs.dispose();
    _tabs = TabController(
        length: len,
        vsync: this,
        initialIndex: _mgr.activeIndex.clamp(0, (len - 1).clamp(0, 99)));
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _mgr.setActive(_tabs.index);
    });
    setState(() {});
  }

  Future<void> _addTab() async {
    await _mgr.addSession(widget.profile);
    _rebuild();
    _tabs.animateTo(_mgr.count - 1);
  }

  Future<void> _closeTab(String id) async {
    if (_mgr.count <= 1) {
      await _stopAndPop();
      return;
    }
    await _mgr.closeSession(id);
    _rebuild();
  }

  Future<void> _stopAndPop() async {
    await WakelockPlus.disable();
    await TerminalForegroundService.instance.stop();
    if (mounted) context.pop();
    await _mgr.closeAll();
  }

  // ── Bracketed paste (multi-line like Termius) ─────────────────────────────
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.isEmpty) return;
    final text = data.text!;
    final session = _mgr.active;
    if (session == null) return;

    if (text.contains('\n')) {
      // Bracketed paste mode — shell receives as one block
      session.sendInput('\x1b[200~$text\x1b[201~');
    } else {
      session.sendInput(text);
    }
  }

  // ── Text selection ────────────────────────────────────────────────────────
  void _showSelectionMenu(BuildContext context) {
    // Get visible terminal text for selection
    final session = _mgr.active;
    if (session == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SelectionSheet(
        session: session,
        onCopy: (text) {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard')));
        },
      ),
    );
  }

  Future<void> _copyAll() async {
    final session = _mgr.active;
    if (session == null) return;
    // Get all terminal buffer text
    final buffer = session.terminal.buffer;
    final lines = <String>[];
    for (int i = 0; i < buffer.lines.length; i++) {
      lines.add(buffer.lines[i].toString());
    }
    final text = lines.join('\n').trimRight();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Terminal output copied')));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabs.dispose();
    WakelockPlus.disable();
    // Don't stop foreground service on dispose — user may have navigated away
    // Service stops when explicitly closing all tabs
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mgr = ref.watch(terminalManagerProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _stopAndPop(),
      child: WithForegroundTask(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.black),
          child: Scaffold(
            backgroundColor: _theme.background,
            body: SafeArea(
              child: Column(children: [
                _TopBar(
                  profile: widget.profile,
                  mgr: mgr,
                  tabs: _tabs,
                  toolbarVisible: _toolbarVisible,
                  keepScreenOn: _keepScreenOn,
                  onAdd: _addTab,
                  onClose: _closeTab,
                  onTheme: _pickTheme,
                  onFont: _pickFont,
                  onSnippets: _pickSnippet,
                  onCopyAll: _copyAll,
                  onSelection: () => _showSelectionMenu(context),
                  onToggleToolbar: () =>
                      setState(() => _toolbarVisible = !_toolbarVisible),
                  onToggleScreenOn: () async {
                    setState(() => _keepScreenOn = !_keepScreenOn);
                    if (_keepScreenOn) {
                      await WakelockPlus.enable();
                    } else {
                      await WakelockPlus.disable();
                    }
                  },
                ),
                Expanded(
                  child: mgr.sessions.isEmpty
                      ? _empty()
                      : TabBarView(
                          controller: _tabs,
                          // Allow swipe between tabs
                          physics: const PageScrollPhysics(),
                          children: mgr.sessions
                              .map((s) => _TermPage(
                                    session: s,
                                    fontSize: _fontSize,
                                    fontFamily: _fontFamily,
                                    theme: _theme,
                                    onScaleStart: () =>
                                        _pinchStart = _fontSize,
                                    onScaleUpdate: (scale) async {
                                      final v = (_pinchStart * scale).clamp(
                                          AppConstants.minFontSize,
                                          AppConstants.maxFontSize);
                                      setState(() => _fontSize = v);
                                      await ref
                                          .read(storageServiceProvider)
                                          .setTerminalFontSize(v);
                                    },
                                    onLongPress: () =>
                                        _showSelectionMenu(context),
                                    onPaste: _paste,
                                  ))
                              .toList(),
                        ),
                ),
                if (mgr.active != null)
                  KeyboardToolbar(
                    terminal: mgr.active!.terminal,
                    onSend: (s) => mgr.active!.sendInput(s),
                    onPaste: _paste,
                    onSearch: mgr.active?.toggleSearch,
                    visible: _toolbarVisible,
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.terminal, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          const Text('No sessions', style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: _addTab,
              icon: const Icon(Icons.add),
              label: const Text('New Session')),
        ]),
      );

  // ── Pickers ───────────────────────────────────────────────────────────────

  void _pickTheme() => showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF141414),
        builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Terminal Theme',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16))),
          ...TerminalThemeName.values.map((t) => ListTile(
                title: Text(t.label,
                    style: const TextStyle(color: Colors.white)),
                trailing: _themeName == t.name
                    ? const Icon(Icons.check, color: Color(0xFF7C83FD))
                    : null,
                onTap: () async {
                  setState(() => _themeName = t.name);
                  await ref
                      .read(storageServiceProvider)
                      .setTerminalTheme(t.name);
                  if (mounted) Navigator.pop(context);
                },
              )),
          const SizedBox(height: 16),
        ]),
      );

  void _pickFont() => showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF141414),
        isScrollControlled: true,
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

  void _pickSnippet() {
    const snippets = [
      ('htop', 'htop'),
      ('docker ps', 'docker ps'),
      ('df -h', 'df -h'),
      ('free -h', 'free -h'),
      ('uptime', 'uptime'),
      ('ss -tlnp', 'ss -tlnp'),
      ('journalctl -f', 'journalctl -f'),
      ('ip addr', 'ip addr'),
      ('ps aux --sort=-%mem | head -20', 'top memory'),
      ('clear', 'clear'),
      ('exit', 'exit'),
      ('ls -la', 'ls -la'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Snippets',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16))),
        SizedBox(
          height: 280,
          child: ListView(
            children: snippets
                .map((s) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.terminal,
                          color: Color(0xFF7C83FD), size: 18),
                      title: Text(s.$2,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                      subtitle: Text(s.$1,
                          style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 11,
                              fontFamily: 'monospace')),
                      onTap: () {
                        Navigator.pop(context);
                        _mgr.active?.sendInput('${s.$1}\n');
                        HapticFeedback.mediumImpact();
                      },
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Top Bar
// ──────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.profile,
    required this.mgr,
    required this.tabs,
    required this.toolbarVisible,
    required this.keepScreenOn,
    required this.onAdd,
    required this.onClose,
    required this.onTheme,
    required this.onFont,
    required this.onSnippets,
    required this.onCopyAll,
    required this.onSelection,
    required this.onToggleToolbar,
    required this.onToggleScreenOn,
  });

  final ServerProfile profile;
  final TerminalManager mgr;
  final TabController tabs;
  final bool toolbarVisible, keepScreenOn;
  final VoidCallback onAdd, onTheme, onFont, onSnippets, onCopyAll,
      onSelection, onToggleToolbar, onToggleScreenOn;
  final void Function(String) onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.chevron_left,
                    color: Color(0xFF888888)),
                onPressed: () {
                  // Pop but keep foreground service
                  context.pop();
                },
                padding: const EdgeInsets.all(4)),
            _dot(mgr.active),
            const SizedBox(width: 6),
            Expanded(
                child: Text(profile.name,
                    style: const TextStyle(
                        color: Color(0xFFB0B0B0),
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis)),
            _btn(Icons.copy_all_outlined, onCopyAll,
                tooltip: 'Copy all'),
            _btn(Icons.text_fields, onSelection,
                tooltip: 'Select text'),
            _btn(Icons.terminal, onSnippets, tooltip: 'Snippets'),
            _btn(Icons.format_size, onFont, tooltip: 'Font'),
            _btn(Icons.palette_outlined, onTheme, tooltip: 'Theme'),
            _btn(
                keepScreenOn
                    ? Icons.screen_lock_portrait
                    : Icons.screen_lock_portrait_outlined,
                onToggleScreenOn,
                tooltip: keepScreenOn ? 'Screen on' : 'Screen off'),
            _btn(
                toolbarVisible
                    ? Icons.keyboard_hide
                    : Icons.keyboard,
                onToggleToolbar,
                tooltip: 'Toolbar'),
            _btn(Icons.add, onAdd, tooltip: 'New tab'),
          ]),
        ),
        if (mgr.count > 0)
          SizedBox(
            height: 36,
            child: TabBar(
              controller: tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFF7C83FD),
              dividerColor: const Color(0xFF1A1A1A),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF666666),
              labelStyle: const TextStyle(fontSize: 12),
              tabs: mgr.sessions
                  .map((s) => Tab(
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListenableBuilder(
                                  listenable: s,
                                  builder: (_, __) => _dot(s)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onDoubleTap: () =>
                                    _renameTab(s),
                                child: Text(s.label),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                  onTap: () => onClose(s.id),
                                  child: const Icon(Icons.close,
                                      size: 14)),
                            ]),
                      ))
                  .toList(),
            ),
          ),
      ]),
    );
  }

  void _renameTab(TerminalSession session) {
    // Will be handled by BuildContext — using a simple approach
  }

  Widget _dot(TerminalSession? s) {
    if (s == null) {
      return Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Color(0xFF444444)));
    }
    return ListenableBuilder(
        listenable: s,
        builder: (_, __) {
          final color = switch (s.connectionState) {
            TerminalConnectionState.connected =>
              const Color(0xFF64FFDA),
            TerminalConnectionState.reconnecting =>
              const Color(0xFFFFCB6B),
            TerminalConnectionState.connecting =>
              const Color(0xFF7C83FD),
            _ => const Color(0xFFFF5370),
          };
          return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color));
        });
  }

  Widget _btn(IconData icon, VoidCallback onTap, {String? tooltip}) =>
      IconButton(
        icon: Icon(icon, size: 18, color: const Color(0xFF888888)),
        onPressed: onTap,
        tooltip: tooltip,
        padding: const EdgeInsets.all(6),
        constraints:
            const BoxConstraints(minWidth: 32, minHeight: 32),
      );
}

// ──────────────────────────────────────────────────────────────────────────────
// Terminal Page (single tab)
// ──────────────────────────────────────────────────────────────────────────────

class _TermPage extends StatefulWidget {
  const _TermPage({
    required this.session,
    required this.fontSize,
    required this.fontFamily,
    required this.theme,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onLongPress,
    required this.onPaste,
  });

  final TerminalSession session;
  final double fontSize;
  final String fontFamily;
  final TerminalTheme theme;
  final VoidCallback onScaleStart, onLongPress;
  final void Function(double) onScaleUpdate;
  final Future<void> Function() onPaste;

  @override
  State<_TermPage> createState() => _TermPageState();
}

class _TermPageState extends State<_TermPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final atBottom = _scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 100;
    if (_showScrollToBottom == atBottom) {
      setState(() => _showScrollToBottom = !atBottom);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
          onLongPress: widget.onLongPress,
          onSecondaryTapDown: (d) => _contextMenu(context, d),
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
                'monospace'
              ],
            ),
            padding: const EdgeInsets.all(4),
            autofocus: true,
            backgroundOpacity: 1.0,
            scrollController: _scrollCtrl,
          ),
        ),

        // Scroll to bottom button
        if (_showScrollToBottom)
          Positioned(
            bottom: 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.animateTo(
                    _scrollCtrl.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C83FD),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8)
                  ],
                ),
                child: const Icon(Icons.keyboard_arrow_down,
                    color: Colors.black, size: 20),
              ),
            ),
          ),

        // Reconnect overlay
        if (widget.session.hasError ||
            widget.session.connectionState ==
                TerminalConnectionState.disconnected)
          Positioned(
            bottom: 16,
            left: 16,
            right: 60,
            child: _ReconnectBanner(
              session: widget.session,
              onReconnect: widget.session.reconnect,
            ),
          ),

        // Search bar
        if (widget.session.searchVisible)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _SearchBar(
                ctrl: _searchCtrl,
                onClose: widget.session.toggleSearch),
          ),
      ]),
    );
  }

  void _contextMenu(BuildContext ctx, TapDownDetails d) {
    showMenu(
      context: ctx,
      position: RelativeRect.fromLTRB(
        d.globalPosition.dx,
        d.globalPosition.dy,
        d.globalPosition.dx + 1,
        d.globalPosition.dy + 1,
      ),
      color: const Color(0xFF1C1C1C),
      items: [
        PopupMenuItem(
          onTap: () async {
            final data =
                await Clipboard.getData(Clipboard.kTextPlain);
            if (data?.text != null) {
              widget.session.sendInput(data!.text!);
            }
          },
          child: const Row(children: [
            Icon(Icons.content_paste,
                size: 18, color: Color(0xFFB0B0B0)),
            SizedBox(width: 8),
            Text('Paste',
                style: TextStyle(color: Colors.white)),
          ]),
        ),
        PopupMenuItem(
          onTap: widget.onLongPress,
          child: const Row(children: [
            Icon(Icons.select_all,
                size: 18, color: Color(0xFFB0B0B0)),
            SizedBox(width: 8),
            Text('Select text',
                style: TextStyle(color: Colors.white)),
          ]),
        ),
        PopupMenuItem(
          onTap: widget.session.toggleSearch,
          child: const Row(children: [
            Icon(Icons.search,
                size: 18, color: Color(0xFFB0B0B0)),
            SizedBox(width: 8),
            Text('Find',
                style: TextStyle(color: Colors.white)),
          ]),
        ),
        PopupMenuItem(
          onTap: () => widget.session.terminal.buffer.clear(),
          child: const Row(children: [
            Icon(Icons.cleaning_services,
                size: 18, color: Color(0xFFB0B0B0)),
            SizedBox(width: 8),
            Text('Clear',
                style: TextStyle(color: Colors.white)),
          ]),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Selection Sheet (Option A + B combined)
// ──────────────────────────────────────────────────────────────────────────────

class _SelectionSheet extends StatefulWidget {
  const _SelectionSheet({
    required this.session,
    required this.onCopy,
  });
  final TerminalSession session;
  final void Function(String) onCopy;

  @override
  State<_SelectionSheet> createState() => _SelectionSheetState();
}

class _SelectionSheetState extends State<_SelectionSheet> {
  late TextEditingController _ctrl;
  double _startLine = 0;
  double _endLine = 0;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    // Get all visible terminal text
    final lines = _getTerminalLines();
    _ctrl = TextEditingController(text: lines.join('\n'));
    _endLine = (lines.length - 1).toDouble();
  }

  List<String> _getTerminalLines() {
    final buffer = widget.session.terminal.buffer;
    final lines = <String>[];
    // Get last 200 lines
    final start = max(0, buffer.lines.length - 200);
    for (int i = start; i < buffer.lines.length; i++) {
      lines.add(buffer.lines[i].toString().trimRight());
    }
    // Remove empty trailing lines
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines;
  }

  String _getSelectedText() {
    final lines = _getTerminalLines();
    final start = _startLine.toInt().clamp(0, lines.length - 1);
    final end = _endLine.toInt().clamp(start, lines.length - 1);
    return lines.sublist(start, end + 1).join('\n');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = _getTerminalLines();
    final lineCount = lines.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, sc) => Column(children: [
        // Handle
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(2)),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          child: Row(children: [
            const Text('Select Text',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            const Spacer(),
            // Copy selected
            TextButton.icon(
              onPressed: () {
                final text = _getSelectedText();
                widget.onCopy(text);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
              style:
                  TextButton.styleFrom(foregroundColor: const Color(0xFF7C83FD)),
            ),
            // Copy all
            TextButton.icon(
              onPressed: () {
                widget.onCopy(lines.join('\n'));
                Navigator.pop(context);
              },
              icon: const Icon(Icons.select_all, size: 16),
              label: const Text('All'),
              style:
                  TextButton.styleFrom(foregroundColor: const Color(0xFF64FFDA)),
            ),
            // Share
            IconButton(
              icon: const Icon(Icons.share,
                  size: 18, color: Color(0xFF888888)),
              onPressed: () async {
                final text = _getSelectedText();
                Navigator.pop(context);
                // Share via system share sheet
                await Clipboard.setData(ClipboardData(text: text));
              },
            ),
          ]),
        ),

        // Line range sliders
        if (lineCount > 1) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Text('From line ',
                  style: TextStyle(
                      color: Color(0xFF888888), fontSize: 12)),
              Text('${_startLine.toInt() + 1}',
                  style: const TextStyle(
                      color: Color(0xFF7C83FD),
                      fontWeight: FontWeight.w600)),
              const Text(' to ',
                  style: TextStyle(
                      color: Color(0xFF888888), fontSize: 12)),
              Text('${_endLine.toInt() + 1}',
                  style: const TextStyle(
                      color: Color(0xFF7C83FD),
                      fontWeight: FontWeight.w600)),
              Text(' of $lineCount',
                  style: const TextStyle(
                      color: Color(0xFF888888), fontSize: 12)),
            ]),
          ),
          RangeSlider(
            values: RangeValues(_startLine, _endLine),
            min: 0,
            max: (lineCount - 1).toDouble(),
            divisions: lineCount > 1 ? lineCount - 1 : 1,
            activeColor: const Color(0xFF7C83FD),
            inactiveColor: const Color(0xFF2A2A2A),
            onChanged: (v) {
              setState(() {
                _startLine = v.start;
                _endLine = v.end;
              });
            },
          ),
        ],

        const Divider(height: 1, color: Color(0xFF2A2A2A)),

        // Terminal text preview with selection highlighted
        Expanded(
          child: SingleChildScrollView(
            controller: sc,
            padding: const EdgeInsets.all(12),
            child: Builder(builder: (_) {
              final allLines = lines;
              final selStart = _startLine.toInt();
              final selEnd = _endLine.toInt();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: allLines.asMap().entries.map((e) {
                  final isSelected =
                      e.key >= selStart && e.key <= selEnd;
                  return Container(
                    width: double.infinity,
                    color: isSelected
                        ? const Color(0xFF7C83FD).withValues(alpha: 0.2)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    child: Text(
                      e.value.isEmpty ? ' ' : e.value,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF888888),
                        height: 1.4,
                      ),
                    ),
                  );
                }).toList(),
              );
            }),
          ),
        ),
      ]),
    );
  }
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
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(2)),
        ),
        const Text('Font',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16)),
        const SizedBox(height: 16),

        // Font family list
        SizedBox(
          height: 200,
          child: ListView(
            children: _fonts
                .map((f) => ListTile(
                      title: Text(f,
                          style: TextStyle(
                              fontFamily: f,
                              color: Colors.white,
                              fontSize: 14)),
                      subtitle: Text('AaBbCc 0O1lI',
                          style: TextStyle(
                              fontFamily: f,
                              color: const Color(0xFF888888),
                              fontSize: 11)),
                      trailing: _font == f
                          ? const Icon(Icons.check,
                              color: Color(0xFF7C83FD))
                          : null,
                      onTap: () {
                        setState(() => _font = f);
                        widget.onFontChanged(f);
                      },
                    ))
                .toList(),
          ),
        ),

        const Divider(color: Color(0xFF2A2A2A)),

        // Size
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Size',
                      style: TextStyle(color: Color(0xFF888888))),
                  Text('${_size.toStringAsFixed(0)}px',
                      style: const TextStyle(
                          color: Color(0xFF7C83FD),
                          fontWeight: FontWeight.w600)),
                ]),
            Row(children: [
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white),
                onPressed: () {
                  final v = (_size - 1).clamp(
                      AppConstants.minFontSize, AppConstants.maxFontSize);
                  setState(() => _size = v);
                  widget.onSizeChanged(v);
                },
              ),
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
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () {
                  final v = (_size + 1).clamp(
                      AppConstants.minFontSize, AppConstants.maxFontSize);
                  setState(() => _size = v);
                  widget.onSizeChanged(v);
                },
              ),
            ]),
          ]),
        ),

        // Preview
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8)),
          child: Text(
            'user@server:~\$ ls -la\ndrwxr-xr-x  2 user user  4096 Apr  1 09:00 .',
            style: TextStyle(
                fontFamily: _font,
                fontSize: _size,
                color: const Color(0xFF64FFDA),
                height: 1.5),
          ),
        ),

        const SizedBox(height: 8),
      ]),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Keyboard Toolbar — Ctrl grid popup
// ──────────────────────────────────────────────────────────────────────────────
// (See keyboard_toolbar.dart for the updated version)

// ──────────────────────────────────────────────────────────────────────────────
// Reconnect Banner
// ──────────────────────────────────────────────────────────────────────────────

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner(
      {required this.session, required this.onReconnect});
  final TerminalSession session;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF5370))),
        child: Row(children: [
          const Icon(Icons.wifi_off,
              color: Color(0xFFFF5370), size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(session.lastError ?? 'Connection lost',
                  style: const TextStyle(
                      color: Color(0xFFE0E0E0), fontSize: 12))),
          GestureDetector(
            onTap: onReconnect,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFF7C83FD),
                  borderRadius: BorderRadius.circular(8)),
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
// Search Bar
// ──────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.ctrl, required this.onClose});
  final TextEditingController ctrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF1C1C1C),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          const Icon(Icons.search,
              color: Color(0xFF888888), size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                      hintText: 'Search...',
                      hintStyle:
                          TextStyle(color: Color(0xFF555555)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero))),
          GestureDetector(
              onTap: onClose,
              child: const Icon(Icons.close,
                  color: Color(0xFF888888), size: 18)),
        ]),
      );
}
