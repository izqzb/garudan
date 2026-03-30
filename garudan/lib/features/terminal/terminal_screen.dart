import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  TerminalManager get _manager => ref.read(terminalManagerProvider);

  double _fontSize = AppConstants.defaultFontSize;
  String _termThemeName = 'amoled';
  TerminalColors get _termTheme =>
      TerminalThemes.fromName(TerminalThemeName.values.firstWhere(
        (t) => t.name == _termThemeName,
        orElse: () => TerminalThemeName.amoled,
      ));

  bool _toolbarVisible = true;
  double _pinchStartFontSize = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 0, vsync: this);
    _loadPrefs();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFirstTab());
  }

  Future<void> _loadPrefs() async {
    final storage = ref.read(storageServiceProvider);
    setState(() {
      _fontSize = storage.getTerminalFontSize();
      _termThemeName = storage.getTerminalTheme();
    });
  }

  Future<void> _openFirstTab() async {
    await _manager.addSession(widget.profile);
    _rebuildTabController();
  }

  void _rebuildTabController() {
    final manager = ref.read(terminalManagerProvider);
    final len = manager.count;
    _tabController.dispose();
    _tabController = TabController(
      length: len,
      vsync: this,
      initialIndex: manager.activeIndex.clamp(0, (len - 1).clamp(0, 999)),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        manager.setActiveIndex(_tabController.index);
      }
    });
    setState(() {});
  }

  Future<void> _addTab() async {
    await _manager.addSession(widget.profile);
    _rebuildTabController();
    _tabController.animateTo(_manager.count - 1);
  }

  Future<void> _closeTab(String sessionId) async {
    if (_manager.count <= 1) {
      Navigator.of(context).pop();
      await _manager.closeAll();
      return;
    }
    await _manager.closeSession(sessionId);
    _rebuildTabController();
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ThemePicker(
        current: _termThemeName,
        onSelect: (t) async {
          setState(() => _termThemeName = t);
          await ref.read(storageServiceProvider).setTerminalTheme(t);
        },
      ),
    );
  }

  void _showFontSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FontSettings(
        fontSize: _fontSize,
        onChange: (size) async {
          setState(() => _fontSize = size);
          await ref.read(storageServiceProvider).setTerminalFontSize(size);
        },
      ),
    );
  }

  void _showSnippets() {
    final session = _manager.activeSession;
    if (session == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _SnippetsSheet(
        onSnippet: (cmd) {
          session.sendInput('$cmd\n');
          HapticFeedback.mediumImpact();
        },
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      _manager.activeSession?.sendInput(data.text!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(terminalManagerProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: _termTheme.background,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top bar ────────────────────────────────────
              _TopBar(
                profile: widget.profile,
                manager: manager,
                tabController: _tabController,
                termThemeName: _termThemeName,
                onAddTab: _addTab,
                onCloseTab: _closeTab,
                onTheme: _showThemePicker,
                onFont: _showFontSettings,
                onSnippets: _showSnippets,
                onToggleToolbar: () => setState(() => _toolbarVisible = !_toolbarVisible),
                toolbarVisible: _toolbarVisible,
              ),

              // ── Terminal area ───────────────────────────────
              Expanded(
                child: manager.sessions.isEmpty
                    ? _buildEmpty()
                    : _buildTabPages(manager),
              ),

              // ── Keyboard toolbar ────────────────────────────
              if (manager.activeSession != null)
                KeyboardToolbar(
                  terminal: manager.activeSession!.terminal,
                  onSendString: (s) => manager.activeSession!.sendInput(s),
                  onCtrlKey: (k) {},
                  onPaste: _pasteFromClipboard,
                  onSearch: manager.activeSession?.toggleSearch,
                  visible: _toolbarVisible,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.terminal, size: 48, color: Colors.white24),
          const SizedBox(height: 12),
          Text('No sessions', style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _addTab,
            icon: const Icon(Icons.add),
            label: const Text('New Session'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPages(TerminalManager manager) {
    return TabBarView(
      controller: _tabController,
      physics: const NeverScrollableScrollPhysics(), // swipe via tabs only
      children: manager.sessions.map((session) {
        return _TerminalPage(
          session: session,
          fontSize: _fontSize,
          theme: _termTheme,
          onFontScaleStart: () => _pinchStartFontSize = _fontSize,
          onFontScaleUpdate: (scale) async {
            final newSize = (_pinchStartFontSize * scale)
                .clamp(AppConstants.minFontSize, AppConstants.maxFontSize);
            setState(() => _fontSize = newSize);
            await ref.read(storageServiceProvider).setTerminalFontSize(newSize);
          },
        );
      }).toList(),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Top Bar
// ──────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.profile,
    required this.manager,
    required this.tabController,
    required this.termThemeName,
    required this.onAddTab,
    required this.onCloseTab,
    required this.onTheme,
    required this.onFont,
    required this.onSnippets,
    required this.onToggleToolbar,
    required this.toolbarVisible,
  });

  final ServerProfile profile;
  final TerminalManager manager;
  final TabController tabController;
  final String termThemeName;
  final VoidCallback onAddTab;
  final void Function(String) onCloseTab;
  final VoidCallback onTheme;
  final VoidCallback onFont;
  final VoidCallback onSnippets;
  final VoidCallback onToggleToolbar;
  final bool toolbarVisible;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Server info row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.chevron_left, color: Color(0xFF888888)),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: manager.activeSession?.isConnected == true
                        ? const Color(0xFF64FFDA)
                        : manager.activeSession?.isReconnecting == true
                            ? const Color(0xFFFFCB6B)
                            : const Color(0xFFFF5370),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    profile.name,
                    style: const TextStyle(
                      color: Color(0xFFB0B0B0),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Action buttons
                _iconBtn(Icons.terminal, onSnippets),
                _iconBtn(Icons.format_size, onFont),
                _iconBtn(Icons.palette_outlined, onTheme),
                _iconBtn(
                  toolbarVisible ? Icons.keyboard_hide : Icons.keyboard,
                  onToggleToolbar,
                ),
                _iconBtn(Icons.add, onAddTab),
              ],
            ),
          ),
          // Tab bar
          if (manager.count > 0)
            SizedBox(
              height: 36,
              child: TabBar(
                controller: tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: const Color(0xFF7C83FD),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: const Color(0xFF1A1A1A),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF666666),
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                tabs: manager.sessions.asMap().entries.map((entry) {
                  final session = entry.value;
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ConnectionDot(session: session),
                        const SizedBox(width: 4),
                        Text(session.label),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => onCloseTab(session.id),
                          child: const Icon(Icons.close, size: 14),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 18, color: const Color(0xFF888888)),
      onPressed: onTap,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}

class _ConnectionDot extends StatelessWidget {
  const _ConnectionDot({required this.session});
  final TerminalSession session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (_, __) {
        final color = switch (session.connectionState) {
          TerminalConnectionState.connected => const Color(0xFF64FFDA),
          TerminalConnectionState.reconnecting => const Color(0xFFFFCB6B),
          TerminalConnectionState.connecting => const Color(0xFF7C83FD),
          _ => const Color(0xFFFF5370),
        };
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Terminal Page (single tab content)
// ──────────────────────────────────────────────────────────────────────────────

class _TerminalPage extends StatefulWidget {
  const _TerminalPage({
    required this.session,
    required this.fontSize,
    required this.theme,
    required this.onFontScaleStart,
    required this.onFontScaleUpdate,
  });

  final TerminalSession session;
  final double fontSize;
  final TerminalColors theme;
  final VoidCallback onFontScaleStart;
  final void Function(double scale) onFontScaleUpdate;

  @override
  State<_TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<_TerminalPage> {
  final _terminalKey = GlobalKey<TerminalViewState>();
  bool _searchVisible = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        return Stack(
          children: [
            // ── Main terminal ───────────────────────────────
            GestureDetector(
              onScaleStart: (_) => widget.onFontScaleStart(),
              onScaleUpdate: (d) {
                if (d.pointerCount >= 2) widget.onFontScaleUpdate(d.scale);
              },
              child: TerminalView(
                key: _terminalKey,
                widget.session.terminal,
                theme: widget.theme,
                textStyle: TerminalStyle(
                  fontSize: widget.fontSize,
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: const ['Courier New', 'monospace'],
                ),
                padding: const EdgeInsets.all(4),
                scrollController: ScrollController(),
                autofocus: true,
                backgroundOpacity: 1.0,
                onSecondaryTapDown: (details, offset) => _showContextMenu(context, details),
              ),
            ),

            // ── Reconnect overlay ───────────────────────────
            if (widget.session.hasError ||
                widget.session.connectionState == TerminalConnectionState.disconnected)
              _ReconnectOverlay(
                session: widget.session,
                onReconnect: () => widget.session.reconnect(),
              ),

            // ── Search bar ───────────────────────────────────
            if (widget.session.searchVisible)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _SearchBar(
                  controller: _searchController,
                  onClose: () => widget.session.toggleSearch(),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showContextMenu(BuildContext ctx, TapDownDetails details) {
    showMenu(
      context: ctx,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx + 1,
        details.globalPosition.dy + 1,
      ),
      color: const Color(0xFF1C1C1C),
      items: [
        PopupMenuItem(
          onTap: () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (data?.text != null) widget.session.sendInput(data!.text!);
          },
          child: const Row(children: [
            Icon(Icons.content_paste, size: 18, color: Color(0xFFB0B0B0)),
            SizedBox(width: 8),
            Text('Paste', style: TextStyle(color: Color(0xFFE0E0E0))),
          ]),
        ),
        PopupMenuItem(
          onTap: () => widget.session.toggleSearch(),
          child: const Row(children: [
            Icon(Icons.search, size: 18, color: Color(0xFFB0B0B0)),
            SizedBox(width: 8),
            Text('Find', style: TextStyle(color: Color(0xFFE0E0E0))),
          ]),
        ),
        PopupMenuItem(
          onTap: () => widget.session.terminal.buffer.clear(),
          child: const Row(children: [
            Icon(Icons.cleaning_services, size: 18, color: Color(0xFFB0B0B0)),
            SizedBox(width: 8),
            Text('Clear', style: TextStyle(color: Color(0xFFE0E0E0))),
          ]),
        ),
        PopupMenuItem(
          onTap: () => widget.session.sendInput('\x0c'), // Ctrl+L
          child: const Row(children: [
            Icon(Icons.refresh, size: 18, color: Color(0xFFB0B0B0)),
            SizedBox(width: 8),
            Text('Reset scroll', style: TextStyle(color: Color(0xFFE0E0E0))),
          ]),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Reconnect overlay
// ──────────────────────────────────────────────────────────────────────────────

class _ReconnectOverlay extends StatelessWidget {
  const _ReconnectOverlay({required this.session, required this.onReconnect});
  final TerminalSession session;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF5370)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: Color(0xFFFF5370), size: 18),
              const SizedBox(width: 8),
              Text(
                session.lastError ?? 'Connection lost',
                style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onReconnect,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C83FD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Reconnect',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Search bar
// ──────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onClose});
  final TextEditingController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1C1C),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF888888), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search terminal...',
                hintStyle: TextStyle(color: Color(0xFF555555)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, color: Color(0xFF888888), size: 18),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Theme picker bottom sheet
// ──────────────────────────────────────────────────────────────────────────────

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.current, required this.onSelect});
  final String current;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Terminal Theme',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...TerminalThemeName.values.map(
          (t) => ListTile(
            title: Text(t.label, style: const TextStyle(color: Colors.white)),
            leading: _ThemeSwatch(theme: TerminalThemes.fromName(t)),
            trailing: current == t.name
                ? const Icon(Icons.check, color: Color(0xFF7C83FD))
                : null,
            onTap: () {
              onSelect(t.name);
              Navigator.of(context).pop();
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.theme});
  final TerminalColors theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Row(
        children: [
          Expanded(child: Container(color: theme.red)),
          Expanded(child: Container(color: theme.green)),
          Expanded(child: Container(color: theme.blue)),
          Expanded(child: Container(color: theme.yellow)),
        ].map((w) => ClipRRect(borderRadius: BorderRadius.circular(6), child: w)).toList(),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Font settings
// ──────────────────────────────────────────────────────────────────────────────

class _FontSettings extends StatefulWidget {
  const _FontSettings({required this.fontSize, required this.onChange});
  final double fontSize;
  final void Function(double) onChange;

  @override
  State<_FontSettings> createState() => _FontSettingsState();
}

class _FontSettingsState extends State<_FontSettings> {
  late double _size;

  @override
  void initState() {
    super.initState();
    _size = widget.fontSize;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Font Size',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, color: Colors.white),
                onPressed: () {
                  final v = (_size - 1).clamp(AppConstants.minFontSize, AppConstants.maxFontSize);
                  setState(() => _size = v);
                  widget.onChange(v);
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
                    widget.onChange(v);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white),
                onPressed: () {
                  final v = (_size + 1).clamp(AppConstants.minFontSize, AppConstants.maxFontSize);
                  setState(() => _size = v);
                  widget.onChange(v);
                },
              ),
            ],
          ),
          Text(
            '${_size.toStringAsFixed(1)}px',
            style: const TextStyle(color: Color(0xFF888888)),
          ),
          const SizedBox(height: 16),
          // Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              r'user@server:~$ ls -la',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: _size,
                color: const Color(0xFF64FFDA),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Snippets bottom sheet
// ──────────────────────────────────────────────────────────────────────────────

class _SnippetsSheet extends StatelessWidget {
  const _SnippetsSheet({required this.onSnippet});
  final void Function(String) onSnippet;

  static const _snippets = [
    ('htop', 'htop'),
    ('docker ps', 'docker ps'),
    ('docker stats', 'docker stats --no-stream'),
    ('disk usage', 'df -h'),
    ('memory', 'free -h'),
    ('uptime', 'uptime'),
    ('open ports', 'ss -tlnp'),
    ('last logins', 'last -n 10'),
    ('top processes', 'ps aux --sort=-%mem | head -20'),
    ('journalctl', 'journalctl -f'),
    ('dmesg', 'dmesg | tail -30'),
    ('ip addr', 'ip addr'),
    ('docker logs', 'docker logs --tail 50 -f '),
    ('clear', 'clear'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Command Snippets',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            itemCount: _snippets.length,
            itemBuilder: (ctx, i) {
              final (label, cmd) = _snippets[i];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.terminal, color: Color(0xFF7C83FD), size: 18),
                title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(
                  cmd,
                  style: const TextStyle(
                    color: Color(0xFF888888),
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onSnippet(cmd);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
