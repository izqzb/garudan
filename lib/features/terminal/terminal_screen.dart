import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xterm/xterm.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/server_profile.dart';
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

class _State extends ConsumerState<TerminalScreen> with TickerProviderStateMixin {
  late TabController _tabs;
  double _fontSize = AppConstants.defaultFontSize;
  String _themeName = 'amoled';
  bool _toolbarVisible = true;
  double _pinchStart = 0;

  TerminalManager get _mgr => ref.read(terminalManagerProvider);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 0, vsync: this);
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFirst());
  }

  Future<void> _loadPrefs() async {
    final s = ref.read(storageServiceProvider);
    setState(() { _fontSize = s.getTerminalFontSize(); _themeName = s.getTerminalTheme(); });
  }

  TerminalTheme get _theme => GarudanTerminalThemes.fromName(
    TerminalThemeName.values.firstWhere((t) => t.name == _themeName, orElse: () => TerminalThemeName.amoled));

  Future<void> _openFirst() async {
    await _mgr.addSession(widget.profile);
    _rebuild();
  }

  void _rebuild() {
    final len = _mgr.count;
    _tabs.dispose();
    _tabs = TabController(length: len, vsync: this, initialIndex: _mgr.activeIndex.clamp(0, (len - 1).clamp(0, 99)));
    _tabs.addListener(() { if (!_tabs.indexIsChanging) _mgr.setActive(_tabs.index); });
    setState(() {});
  }

  Future<void> _addTab() async { await _mgr.addSession(widget.profile); _rebuild(); _tabs.animateTo(_mgr.count - 1); }

  Future<void> _closeTab(String id) async {
    if (_mgr.count <= 1) { context.pop(); await _mgr.closeAll(); return; }
    await _mgr.closeSession(id); _rebuild();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null) _mgr.active?.sendInput(d!.text!);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final mgr = ref.watch(terminalManagerProvider);
    return PopScope(
      canPop: mgr.count == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mgr.count > 0) {
          if (mgr.count == 1) { context.pop(); mgr.closeAll(); }
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.black),
        child: Scaffold(
          backgroundColor: _theme.background,
          body: SafeArea(
            child: Column(children: [
              _TopBar(
                profile: widget.profile, mgr: mgr, tabs: _tabs,
                toolbarVisible: _toolbarVisible,
                onAdd: _addTab,
                onClose: _closeTab,
                onTheme: _pickTheme,
                onFont: _pickFont,
                onSnippets: _pickSnippet,
                onToggleToolbar: () => setState(() => _toolbarVisible = !_toolbarVisible),
              ),
              Expanded(
                child: mgr.sessions.isEmpty
                    ? _empty()
                    : TabBarView(
                        controller: _tabs,
                        physics: const NeverScrollableScrollPhysics(),
                        children: mgr.sessions.map((s) => _TermPage(
                          session: s, fontSize: _fontSize, theme: _theme,
                          onScaleStart: () => _pinchStart = _fontSize,
                          onScaleUpdate: (scale) async {
                            final v = (_pinchStart * scale).clamp(AppConstants.minFontSize, AppConstants.maxFontSize);
                            setState(() => _fontSize = v);
                            await ref.read(storageServiceProvider).setTerminalFontSize(v);
                          },
                        )).toList(),
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
    );
  }

  Widget _empty() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.terminal, size: 48, color: Colors.white24),
    const SizedBox(height: 12),
    const Text('No sessions', style: TextStyle(color: Colors.white38)),
    const SizedBox(height: 16),
    FilledButton.icon(onPressed: _addTab, icon: const Icon(Icons.add), label: const Text('New Session')),
  ]));

  void _pickTheme() => showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF141414),
    builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(padding: EdgeInsets.all(16), child: Text('Terminal Theme', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16))),
      ...TerminalThemeName.values.map((t) => ListTile(
        title: Text(t.label, style: const TextStyle(color: Colors.white)),
        trailing: _themeName == t.name ? const Icon(Icons.check, color: Color(0xFF7C83FD)) : null,
        onTap: () async {
          setState(() => _themeName = t.name);
          await ref.read(storageServiceProvider).setTerminalTheme(t.name);
          if (mounted) Navigator.pop(context);
        },
      )),
      const SizedBox(height: 16),
    ]),
  );

  void _pickFont() => showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF141414),
    builder: (_) => StatefulBuilder(builder: (_, set) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Font Size', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 16),
        Row(children: [
          IconButton(icon: const Icon(Icons.remove, color: Colors.white), onPressed: () async {
            final v = (_fontSize - 1).clamp(AppConstants.minFontSize, AppConstants.maxFontSize);
            setState(() => _fontSize = v); set(() {}); await ref.read(storageServiceProvider).setTerminalFontSize(v);
          }),
          Expanded(child: Slider(value: _fontSize, min: AppConstants.minFontSize, max: AppConstants.maxFontSize,
            divisions: 20, activeColor: const Color(0xFF7C83FD),
            onChanged: (v) async { setState(() => _fontSize = v); set(() {}); await ref.read(storageServiceProvider).setTerminalFontSize(v); })),
          IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () async {
            final v = (_fontSize + 1).clamp(AppConstants.minFontSize, AppConstants.maxFontSize);
            setState(() => _fontSize = v); set(() {}); await ref.read(storageServiceProvider).setTerminalFontSize(v);
          }),
        ]),
        Text('${_fontSize.toStringAsFixed(1)}px', style: const TextStyle(color: Color(0xFF888888))),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
          child: Text(r'user@server:~$ ls -la', style: TextStyle(fontFamily: 'monospace', fontSize: _fontSize, color: const Color(0xFF64FFDA)))),
        const SizedBox(height: 16),
      ]),
    )),
  );

  void _pickSnippet() {
    const snippets = [
      ('htop', 'htop'), ('docker ps', 'docker ps'), ('df -h', 'df -h'),
      ('free -h', 'free -h'), ('uptime', 'uptime'), ('ss -tlnp', 'ss -tlnp'),
      ('journalctl -f', 'journalctl -f'), ('ip addr', 'ip addr'),
      ('ps aux --sort=-%mem | head -20', 'top memory'), ('clear', 'clear'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.all(16), child: Text('Snippets', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16))),
        SizedBox(height: 260, child: ListView(children: snippets.map((s) => ListTile(
          dense: true,
          leading: const Icon(Icons.terminal, color: Color(0xFF7C83FD), size: 18),
          title: Text(s.$2, style: const TextStyle(color: Colors.white, fontSize: 13)),
          subtitle: Text(s.$1, style: const TextStyle(color: Color(0xFF888888), fontSize: 11, fontFamily: 'monospace')),
          onTap: () { Navigator.pop(context); _mgr.active?.sendInput('${s.$1}\n'); HapticFeedback.mediumImpact(); },
        )).toList())),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.profile, required this.mgr, required this.tabs, required this.toolbarVisible, required this.onAdd, required this.onClose, required this.onTheme, required this.onFont, required this.onSnippets, required this.onToggleToolbar});
  final ServerProfile profile; final TerminalManager mgr; final TabController tabs;
  final bool toolbarVisible;
  final VoidCallback onAdd, onTheme, onFont, onSnippets, onToggleToolbar;
  final void Function(String) onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left, color: Color(0xFF888888)), onPressed: () => context.pop(), padding: const EdgeInsets.all(4)),
            _dot(mgr.active),
            const SizedBox(width: 6),
            Expanded(child: Text(profile.name, style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            _btn(Icons.terminal, onSnippets),
            _btn(Icons.format_size, onFont),
            _btn(Icons.palette_outlined, onTheme),
            _btn(toolbarVisible ? Icons.keyboard_hide : Icons.keyboard, onToggleToolbar),
            _btn(Icons.add, onAdd),
          ]),
        ),
        if (mgr.count > 0) SizedBox(
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
            tabs: mgr.sessions.map((s) => Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              ListenableBuilder(listenable: s, builder: (_, __) => _dot(s)),
              const SizedBox(width: 4),
              Text(s.label),
              const SizedBox(width: 4),
              GestureDetector(onTap: () => onClose(s.id), child: const Icon(Icons.close, size: 14)),
            ]))).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _dot(TerminalSession? s) {
    if (s == null) return const SizedBox(width: 8, height: 8);
    return ListenableBuilder(listenable: s, builder: (_, __) {
      final color = switch (s.connectionState) {
        TerminalConnectionState.connected    => const Color(0xFF64FFDA),
        TerminalConnectionState.reconnecting => const Color(0xFFFFCB6B),
        TerminalConnectionState.connecting   => const Color(0xFF7C83FD),
        _ => const Color(0xFFFF5370),
      };
      return Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
    });
  }

  Widget _btn(IconData icon, VoidCallback onTap) => IconButton(
    icon: Icon(icon, size: 18, color: const Color(0xFF888888)),
    onPressed: onTap,
    padding: const EdgeInsets.all(6),
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
  );
}

class _TermPage extends StatefulWidget {
  const _TermPage({required this.session, required this.fontSize, required this.theme, required this.onScaleStart, required this.onScaleUpdate});
  final TerminalSession session;
  final double fontSize;
  final TerminalTheme theme;
  final VoidCallback onScaleStart;
  final void Function(double) onScaleUpdate;
  @override
  State<_TermPage> createState() => _TermPageState();
}

class _TermPageState extends State<_TermPage> {
  final _search = TextEditingController();
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (_, __) => Stack(children: [
        GestureDetector(
          onScaleStart: (_) => widget.onScaleStart(),
          onScaleUpdate: (d) { if (d.pointerCount >= 2) widget.onScaleUpdate(d.scale); },
          onSecondaryTapDown: (d) => _menu(context, d),
          child: TerminalView(
            widget.session.terminal,
            theme: widget.theme,
            textStyle: TerminalStyle(fontSize: widget.fontSize, fontFamily: 'JetBrains Mono', fontFamilyFallback: const ['Courier New', 'monospace']),
            padding: const EdgeInsets.all(4),
            autofocus: true,
            backgroundOpacity: 1.0,
          ),
        ),
        if (widget.session.hasError || widget.session.connectionState == TerminalConnectionState.disconnected)
          Positioned(bottom: 16, left: 16, right: 16, child: _ReconnectBanner(
            session: widget.session,
            onReconnect: () => widget.session.reconnect(),
          )),
        if (widget.session.searchVisible)
          Positioned(top: 0, left: 0, right: 0, child: _SearchBar(ctrl: _search, onClose: widget.session.toggleSearch)),
      ]),
    );
  }

  void _menu(BuildContext ctx, TapDownDetails d) {
    showMenu(context: ctx,
      position: RelativeRect.fromLTRB(d.globalPosition.dx, d.globalPosition.dy, d.globalPosition.dx + 1, d.globalPosition.dy + 1),
      color: const Color(0xFF1C1C1C),
      items: [
        PopupMenuItem(onTap: () async { final d = await Clipboard.getData(Clipboard.kTextPlain); if (d?.text != null) widget.session.sendInput(d!.text!); },
          child: const Row(children: [Icon(Icons.content_paste, size: 18, color: Color(0xFFB0B0B0)), SizedBox(width: 8), Text('Paste', style: TextStyle(color: Colors.white))])),
        PopupMenuItem(onTap: widget.session.toggleSearch,
          child: const Row(children: [Icon(Icons.search, size: 18, color: Color(0xFFB0B0B0)), SizedBox(width: 8), Text('Find', style: TextStyle(color: Colors.white))])),
        PopupMenuItem(onTap: () => widget.session.terminal.buffer.clear(),
          child: const Row(children: [Icon(Icons.cleaning_services, size: 18, color: Color(0xFFB0B0B0)), SizedBox(width: 8), Text('Clear', style: TextStyle(color: Colors.white))])),
      ],
    );
  }
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner({required this.session, required this.onReconnect});
  final TerminalSession session;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFF5370))),
    child: Row(children: [
      const Icon(Icons.wifi_off, color: Color(0xFFFF5370), size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(session.lastError ?? 'Connection lost', style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13))),
      GestureDetector(onTap: onReconnect, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: const Color(0xFF7C83FD), borderRadius: BorderRadius.circular(8)),
        child: const Text('Reconnect', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w600)),
      )),
    ]),
  );
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.ctrl, required this.onClose});
  final TextEditingController ctrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF1C1C1C),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(children: [
      const Icon(Icons.search, color: Color(0xFF888888), size: 18),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: const InputDecoration(hintText: 'Search...', hintStyle: TextStyle(color: Color(0xFF555555)), border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero))),
      GestureDetector(onTap: onClose, child: const Icon(Icons.close, color: Color(0xFF888888), size: 18)),
    ]),
  );
}
