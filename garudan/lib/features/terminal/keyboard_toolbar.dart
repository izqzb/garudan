import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

/// The special keyboard toolbar row shown above the soft keyboard.
/// Provides Ctrl, Esc, Tab, arrow keys, and quick-paste.
class KeyboardToolbar extends StatefulWidget {
  const KeyboardToolbar({
    super.key,
    required this.terminal,
    required this.onSendString,
    required this.onCtrlKey,
    this.onPaste,
    this.onSearch,
    this.visible = true,
  });

  final Terminal terminal;
  final void Function(String) onSendString;
  final void Function(String key) onCtrlKey;
  final VoidCallback? onPaste;
  final VoidCallback? onSearch;
  final bool visible;

  @override
  State<KeyboardToolbar> createState() => _KeyboardToolbarState();
}

class _KeyboardToolbarState extends State<KeyboardToolbar> {
  bool _ctrlActive = false;
  bool _altActive = false;

  static const _ctrlKeys = [
    ('C', '\x03'),
    ('D', '\x04'),
    ('Z', '\x1a'),
    ('A', '\x01'),
    ('E', '\x05'),
    ('L', '\x0c'),
    ('R', '\x12'),
    ('W', '\x17'),
    ('U', '\x15'),
    ('K', '\x0b'),
    ('\\', '\x1c'),
  ];

  void _handleCtrlKey(String key, String ctrlCode) {
    if (_ctrlActive) {
      widget.onSendString(ctrlCode);
      setState(() => _ctrlActive = false);
      HapticFeedback.lightImpact();
    } else {
      widget.onSendString(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return Container(
      height: 44,
      color: const Color(0xFF0D0D0D),
      child: Column(
        children: [
          Container(height: 0.5, color: const Color(0xFF2A2A2A)),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                // CTRL toggle
                _ModKey(
                  label: 'CTRL',
                  active: _ctrlActive,
                  onTap: () {
                    setState(() => _ctrlActive = !_ctrlActive);
                    HapticFeedback.selectionClick();
                  },
                ),
                // ESC
                _KeyBtn(
                  label: 'ESC',
                  onTap: () => widget.onSendString('\x1b'),
                ),
                // TAB
                _KeyBtn(
                  label: 'TAB',
                  onTap: () => widget.onSendString('\t'),
                ),
                // Arrow keys
                _KeyBtn(
                  icon: Icons.keyboard_arrow_up,
                  onTap: () => widget.onSendString('\x1b[A'),
                ),
                _KeyBtn(
                  icon: Icons.keyboard_arrow_down,
                  onTap: () => widget.onSendString('\x1b[B'),
                ),
                _KeyBtn(
                  icon: Icons.keyboard_arrow_left,
                  onTap: () => widget.onSendString('\x1b[D'),
                ),
                _KeyBtn(
                  icon: Icons.keyboard_arrow_right,
                  onTap: () => widget.onSendString('\x1b[C'),
                ),

                // Divider
                const VerticalDivider(
                  width: 16,
                  indent: 8,
                  endIndent: 8,
                  color: Color(0xFF2A2A2A),
                ),

                // When CTRL active, show ctrl combos; else show common keys
                if (_ctrlActive)
                  ..._ctrlKeys.map(
                    (pair) => _KeyBtn(
                      label: 'C-${pair.$1}',
                      accent: true,
                      onTap: () {
                        widget.onSendString(pair.$2);
                        setState(() => _ctrlActive = false);
                        HapticFeedback.lightImpact();
                      },
                    ),
                  )
                else ...[
                  _KeyBtn(label: '/', onTap: () => widget.onSendString('/')),
                  _KeyBtn(label: '-', onTap: () => widget.onSendString('-')),
                  _KeyBtn(label: '_', onTap: () => widget.onSendString('_')),
                  _KeyBtn(label: '|', onTap: () => widget.onSendString('|')),
                  _KeyBtn(label: '~', onTap: () => widget.onSendString('~')),
                  _KeyBtn(label: '&', onTap: () => widget.onSendString('&')),
                  _KeyBtn(label: "\\", onTap: () => widget.onSendString('\\')),
                  // Page up/down
                  _KeyBtn(
                    label: 'PgUp',
                    onTap: () => widget.onSendString('\x1b[5~'),
                  ),
                  _KeyBtn(
                    label: 'PgDn',
                    onTap: () => widget.onSendString('\x1b[6~'),
                  ),
                  // Home / End
                  _KeyBtn(
                    label: 'Home',
                    onTap: () => widget.onSendString('\x1b[H'),
                  ),
                  _KeyBtn(
                    label: 'End',
                    onTap: () => widget.onSendString('\x1b[F'),
                  ),
                ],

                const VerticalDivider(
                  width: 16,
                  indent: 8,
                  endIndent: 8,
                  color: Color(0xFF2A2A2A),
                ),

                // Paste
                _KeyBtn(
                  icon: Icons.content_paste_rounded,
                  onTap: widget.onPaste ?? () {},
                ),
                // Search
                if (widget.onSearch != null)
                  _KeyBtn(
                    icon: Icons.search_rounded,
                    onTap: widget.onSearch!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyBtn extends StatelessWidget {
  const _KeyBtn({
    this.label,
    this.icon,
    required this.onTap,
    this.accent = false,
  });

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: accent ? const Color(0xFF7C83FD).withOpacity(0.2) : const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: accent ? const Color(0xFF7C83FD) : const Color(0xFF2A2A2A),
          ),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 16, color: const Color(0xFFB0B0B0))
            : Text(
                label!,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: accent ? const Color(0xFF7C83FD) : const Color(0xFFB0B0B0),
                  fontWeight: accent ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
      ),
    );
  }
}

class _ModKey extends StatelessWidget {
  const _ModKey({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7C83FD) : const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? const Color(0xFF7C83FD) : const Color(0xFF2A2A2A),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: active ? Colors.black : const Color(0xFFB0B0B0),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
