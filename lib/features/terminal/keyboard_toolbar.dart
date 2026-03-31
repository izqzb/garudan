import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

class KeyboardToolbar extends StatefulWidget {
  const KeyboardToolbar({super.key, required this.terminal, required this.onSend, this.onPaste, this.onSearch, this.visible = true});
  final Terminal terminal;
  final void Function(String) onSend;
  final VoidCallback? onPaste, onSearch;
  final bool visible;
  @override
  State<KeyboardToolbar> createState() => _State();
}

class _State extends State<KeyboardToolbar> {
  bool _ctrl = false;

  static const _ctrlKeys = [
    ('C', '\x03'), ('D', '\x04'), ('Z', '\x1a'), ('A', '\x01'),
    ('E', '\x05'), ('L', '\x0c'), ('R', '\x12'), ('W', '\x17'),
    ('U', '\x15'), ('K', '\x0b'), ('\\', '\x1c'),
  ];

  void _tap(String s) { HapticFeedback.selectionClick(); widget.onSend(s); }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return Container(
      height: 44,
      color: const Color(0xFF0D0D0D),
      child: Column(children: [
        Container(height: 0.5, color: const Color(0xFF2A2A2A)),
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: [
              _ModKey('CTRL', _ctrl, () => setState(() => _ctrl = !_ctrl)),
              _K('ESC',  () => _tap('\x1b')),
              _K('TAB',  () => _tap('\t')),
              _K(null, () => _tap('\x1b[A'), icon: Icons.keyboard_arrow_up),
              _K(null, () => _tap('\x1b[B'), icon: Icons.keyboard_arrow_down),
              _K(null, () => _tap('\x1b[D'), icon: Icons.keyboard_arrow_left),
              _K(null, () => _tap('\x1b[C'), icon: Icons.keyboard_arrow_right),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8, color: Color(0xFF2A2A2A)),
              if (_ctrl)
                ..._ctrlKeys.map((p) => _K('C-${p.$1}', () {
                  widget.onSend(p.$2); setState(() => _ctrl = false); HapticFeedback.lightImpact();
                }, accent: true))
              else ...[
                _K('/',  () => _tap('/')),   _K('-', () => _tap('-')),
                _K('_',  () => _tap('_')),   _K('|', () => _tap('|')),
                _K('~',  () => _tap('~')),   _K('&', () => _tap('&')),
                _K(r'\', () => _tap('\\')),
                _K('PgUp', () => _tap('\x1b[5~')),
                _K('PgDn', () => _tap('\x1b[6~')),
                _K('Home', () => _tap('\x1b[H')),
                _K('End',  () => _tap('\x1b[F')),
              ],
              const VerticalDivider(width: 16, indent: 8, endIndent: 8, color: Color(0xFF2A2A2A)),
              _K(null, widget.onPaste ?? () {}, icon: Icons.content_paste_rounded),
              if (widget.onSearch != null)
                _K(null, widget.onSearch!, icon: Icons.search_rounded),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _K(String? label, VoidCallback onTap, {IconData? icon, bool accent = false}) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: accent ? const Color(0xFF7C83FD).withValues(alpha: 0.2) : const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accent ? const Color(0xFF7C83FD) : const Color(0xFF2A2A2A)),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 16, color: const Color(0xFFB0B0B0))
            : Text(label!, style: TextStyle(
                fontSize: 12, fontFamily: 'monospace',
                color: accent ? const Color(0xFF7C83FD) : const Color(0xFFB0B0B0),
                fontWeight: accent ? FontWeight.w600 : FontWeight.w400,
              )),
      ),
    );
  }

  Widget _ModKey(String label, bool active, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF7C83FD) : const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? const Color(0xFF7C83FD) : const Color(0xFF2A2A2A)),
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(
        fontSize: 12, fontFamily: 'monospace',
        color: active ? Colors.black : const Color(0xFFB0B0B0),
        fontWeight: FontWeight.w600,
      )),
    ),
  );
}
