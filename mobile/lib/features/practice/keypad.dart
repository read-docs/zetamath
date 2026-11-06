import 'package:flutter/material.dart';

import '../../store/settings.dart';
import '../../themes/themes.dart';
import 'practice_controller.dart';

/// 4 × 3 numeric keypad. Presses fire on pointer down, so a solve time ends when the finger
/// lands, not when it lifts, and two thumbs can overlap without dropping a tap.
class Keypad extends StatelessWidget {
  const Keypad({super.key, required this.layout, required this.onKey, this.enabled = true});
  final KeypadLayout layout;
  final ValueChanged<KeypadKey> onKey;
  final bool enabled;

  static const _gap = 8.0;

  @override
  Widget build(BuildContext context) {
    final digits = layout == KeypadLayout.phone
        ? const [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
          ]
        : const [
            [7, 8, 9],
            [4, 5, 6],
            [1, 2, 3],
          ];
    final rows = <List<Widget>>[
      for (final row in digits)
        [
          for (final d in row)
            _Key(
              key: ValueKey('keypad-$d'),
              label: '$d',
              semantics: '$d',
              onPress: () => onKey(KeypadKey.digit(d)),
              enabled: enabled,
            ),
        ],
      [
        _Key(
          icon: Icons.clear,
          semantics: 'clear answer',
          onPress: () => onKey(KeypadKey.clear),
          enabled: enabled,
          muted: true,
        ),
        _Key(
          key: const ValueKey('keypad-0'),
          label: '0',
          semantics: '0',
          onPress: () => onKey(const KeypadKey.digit(0)),
          enabled: enabled,
        ),
        _Key(
          icon: Icons.backspace_outlined,
          semantics: 'delete digit',
          onPress: () => onKey(KeypadKey.backspace),
          enabled: enabled,
          muted: true,
        ),
      ],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const SizedBox(height: _gap),
            Expanded(
              child: Row(
                children: [
                  for (final (j, key) in row.indexed) ...[if (j > 0) const SizedBox(width: _gap), Expanded(child: key)],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Key extends StatefulWidget {
  const _Key({
    super.key,
    this.label,
    this.icon,
    required this.semantics,
    required this.onPress,
    required this.enabled,
    this.muted = false,
  });
  final String? label;
  final IconData? icon;
  final String semantics;
  final VoidCallback onPress;
  final bool enabled, muted;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  var _down = 0;

  @override
  Widget build(BuildContext context) {
    final z = context.zeta;
    final color = widget.muted ? z.sub : z.text;
    return Semantics(
      button: true,
      label: widget.semantics,
      enabled: widget.enabled,
      excludeSemantics: true,
      onTap: widget.enabled ? widget.onPress : null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          if (!widget.enabled) return;
          widget.onPress();
          setState(() => _down++);
        },
        onPointerUp: (_) => setState(() => _down = (_down - 1).clamp(0, 10)),
        onPointerCancel: (_) => setState(() => _down = (_down - 1).clamp(0, 10)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          decoration: BoxDecoration(
            color: _down > 0 ? z.main.withValues(alpha: .25) : Color.lerp(z.bg, z.sub, .1),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: widget.icon != null
              ? Icon(widget.icon, color: color, size: 26)
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(widget.label!, style: TextStyle(fontSize: 30, color: widget.enabled ? color : z.sub)),
                ),
        ),
      ),
    );
  }
}
