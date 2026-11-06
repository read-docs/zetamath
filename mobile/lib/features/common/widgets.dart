import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../themes/themes.dart';

/// A row of single-choice chips, like the web button groups.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.value,
    required this.onSelected,
    this.label,
    this.enabled = true,
  });
  final List<T> options;
  final T? value;
  final ValueChanged<T> onSelected;
  final String Function(T)? label;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (final o in options)
        ChoiceChip(
          label: Text(label?.call(o) ?? '$o'),
          selected: o == value,
          labelStyle: TextStyle(color: o == value ? context.zeta.main : context.zeta.sub),
          onSelected: enabled ? (_) => onSelected(o) : null,
        ),
    ],
  );
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.note});
  final String label, value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final z = context.zeta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: z.sub, fontSize: 13)),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(color: z.main, fontSize: 28, height: 1.2)),
        ),
        if (note != null) Text(note!, style: TextStyle(color: z.sub, fontSize: 11)),
      ],
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.title, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final String? title;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: padding,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(title!, style: TextStyle(color: context.zeta.sub)),
              ),
            child,
          ],
        ),
      ),
    ),
  );
}

/// Asks for a number and checks it the way the web inputs do. Returns null if cancelled.
Future<num?> askNumber(
  BuildContext context, {
  required String title,
  required num initial,
  num min = 1,
  num max = 86400,
  bool whole = true,
  String? Function(num)? check,
}) => showDialog<num>(
  context: context,
  builder: (_) => _NumberDialog(title: title, initial: initial, min: min, max: max, whole: whole, check: check),
);

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.initial,
    required this.min,
    required this.max,
    required this.whole,
    this.check,
  });
  final String title;
  final num initial, min, max;
  final bool whole;
  final String? Function(num)? check;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final _text = TextEditingController(text: '${widget.initial}');
  String? _error;

  void _submit() {
    final n = num.tryParse(_text.text.trim());
    if (n == null || n < widget.min || n > widget.max || (widget.whole && n != n.truncate())) {
      setState(
        () => _error = 'Use ${widget.whole ? 'a whole number' : 'a number'} from ${widget.min} to ${widget.max}.',
      );
      return;
    }
    final value = widget.whole ? n.toInt() : n.toDouble();
    final issue = widget.check?.call(value);
    if (issue != null) return setState(() => _error = issue);
    Navigator.pop(context, value);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _text,
      autofocus: true,
      keyboardType: TextInputType.numberWithOptions(decimal: !widget.whole),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(widget.whole ? r'[0-9]' : r'[0-9.]'))],
      decoration: InputDecoration(errorText: _error, errorMaxLines: 3),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('cancel')),
      TextButton(onPressed: _submit, child: const Text('apply')),
    ],
  );
}

Future<bool> confirm(BuildContext context, String message, {String action = 'delete'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: TextStyle(color: context.zeta.error)),
          ),
        ],
      ),
    ) ??
    false;

/// `−` for subtraction, as web displays it.
String opLabel(String symbol) => symbol == '-' ? '−' : symbol;
