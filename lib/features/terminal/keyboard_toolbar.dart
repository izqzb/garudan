import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

class KeyboardToolbar extends StatefulWidget {
  const KeyboardToolbar({
    super.key,
    required this.terminal,
    required this.onSend,
    this.onPaste,
    this.onSearch,
    this.visible = true,
  });
  final Terminal terminal;
  final void Function(String) onSend;
  final Future<void> Function()? onPaste;
  final VoidCallback? onSearch;
  final bool visible;

  @override
  State<KeyboardToolbar> createState() => _State();
}

class _State extends State<KeyboardToolbar> {
  bool _ctrl = false;

  // All ctrl shortcuts with labels
  static const _ctrlShortcuts = [
    ('C', '\x03', 'Interrupt'),
    ('D', '\x04', 'EOF/Logout'),
    ('Z', '\x1a', 'Suspend'),
    ('A', '\x01', 'Line start'),
    ('E', '\x05', 'Line end'),
    ('L', '\x0c', 'Clear'),
    ('R', '\x12', 'History search'),
    ('W', '\x17', 'Delete word'),
    ('U', '\x15', 'Delete line'),
    ('K', '\x0b', 'Kill to end'),
    ('\\', '\x1c', 'Quit'),
    ('P', '\x10', 'Prev history'),
    ('N', '\x0e', 'Next history'),
    ('B', '\x02', 'Back char'),
    ('F', '\x06', 'Forward char'),
    ('T', '\x14', 'Swap chars'),
    ('H', '\x08', 'Backspace'),
    ('J', '\x0a', 'Newline'),
  ];

  void _send(String s) {
    HapticFeedback.selectionClick();
    widget.onSend(s);
  }

  void _showCtrlGrid(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(2)),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Ctrl Shortcuts',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: _ctrlShortcuts.map((s) => GestureDetector(
              onTap: () {
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
                widget.onSend(s.$2);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1C),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('^${s.$1}',
                        style: const TextStyle(
                            color: Color(0xFF7C83FD),
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    Text(s.$3,
                        style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 9),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            )).toList(),
          ),
        ),
      ]),
    );
  }

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
              // CTRL — opens grid popup
              _CtrlBtn(
                active: _ctrl,
                onTap: () => _showCtrlGrid(context),
              ),
              _K('ESC', () => _send('\x1b')),
              _K('TAB', () => _send('\t')),
              _K(null, () => _send('\x1b[A'), icon: Icons.keyboard_arrow_up),
              _K(null, () => _send('\x1b[B'), icon: Icons.keyboard_arrow_down),
              _K(null, () => _send('\x1b[D'), icon: Icons.keyboard_arrow_left),
              _K(null, () => _send('\x1b[C'), icon: Icons.keyboard_arrow_right),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8, color: Color(0xFF2A2A2A)),
              _K('/', () => _send('/')),
              _K('-', () => _send('-')),
              _K('_', () => _send('_')),
              _K('|', () => _send('|')),
              _K('~', () => _send('~')),
              _K('&', () => _send('&')),
              _K(r'\', () => _send('\\')),
              _K('PgUp', () => _send('\x1b[5~')),
              _K('PgDn', () => _send('\x1b[6~')),
              _K('Home', () => _send('\x1b[H')),
              _K('End', () => _send('\x1b[F')),
              const VerticalDivider(width: 16, indent: 8, endIndent: 8, color: Color(0xFF2A2A2A)),
              if (widget.onPaste != null)
                _K(null, () async {
                  HapticFeedback.selectionClick();
                  await widget.onPaste!();
                }, icon: Icons.content_paste_rounded),
              if (widget.onSearch != null)
                _K(null, widget.onSearch!, icon: Icons.search_rounded),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _K(String? label, VoidCallback onTap, {IconData? icon}) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 16, color: const Color(0xFFB0B0B0))
            : Text(label!,
                style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Color(0xFFB0B0B0))),
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  const _CtrlBtn({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF7C83FD).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF7C83FD).withValues(alpha: 0.5)),
        ),
        alignment: Alignment.center,
        child: const Text('CTRL',
            style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Color(0xFF7C83FD),
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}
