import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../engine/generator.dart';
import '../../store/difficulty.dart';
import '../../store/history.dart';
import '../../store/history_store.dart';
import '../../store/settings.dart';
import '../../themes/themes.dart';
import '../common/widgets.dart';
import 'quick_settings_sheet.dart';

const _opNames = {
  Operation.add: ('addition', 'a + b'),
  Operation.subtract: ('subtraction', 'shown as (a + b) − b, so the answer is never negative'),
  Operation.multiply: ('multiplication', 'a × b'),
  Operation.divide: ('division', 'shown as (a × b) ÷ b, so the answer is always whole'),
};

/// Every setting from the web settings page, plus haptics, keypad layout and seed.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final update = notifier.update;
    final history = ref.watch(historyProvider);
    final z = context.zeta;
    final difficulty = difficultyOf(s.ranges);

    void message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

    /// Applies a range edit if the result is valid, otherwise returns the web error message.
    String? saveRange(Operation op, OperationRange range) {
      final ranges = s.ranges.withRange(op, range);
      final issue = validateRanges(ranges);
      if (issue == null) update((s) => s.copyWith(ranges: ranges));
      return issue;
    }

    Future<void> editNumber(
      String title,
      num value,
      void Function(num) apply, {
      num min = 1,
      num max = 86400,
      bool whole = true,
      String? Function(num)? check,
    }) async {
      final n = await askNumber(context, title: title, initial: value, min: min, max: max, whole: whole, check: check);
      if (n != null) apply(n);
    }

    Future<void> exportHistory() async {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/zetamath-history.json');
      await file.writeAsString(ref.read(historyProvider.notifier).exportJson());
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Zetamath history',
        ),
      );
    }

    Future<void> importHistory() async {
      try {
        final files = await FilePicker.pickFiles(type: FileType.any);
        if (files.isEmpty) return;
        final count = await ref.read(historyProvider.notifier).importJson(await files.first.xFile.readAsString());
        message('Imported $count results.');
      } catch (e) {
        message('$e');
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Section('test', [
          _Row(
            icon: Icons.schedule,
            title: 'mode',
            description: 'Time runs for a set number of seconds. Count ends after a set number of problems. Zen runs until you stop it. Custom lets you pick any goal.',
            child: ChoiceChips(
              options: TestMode.values,
              value: s.mode,
              label: (m) => m.name,
              onSelected: (m) => update((s) => s.copyWith(mode: m)),
            ),
          ),
          _Row(
            icon: Icons.timer_outlined,
            title: 'time limit',
            description: 'Length of time and custom-time tests, in seconds.',
            child: _ChipsWithCustom(
              options: timeOptions,
              value: s.duration,
              onSelected: (n) => update((s) => s.copyWith(duration: n)),
              onCustom: () => editNumber(
                'time limit in seconds',
                s.duration,
                (n) => update((s) => s.copyWith(duration: n.toInt())),
              ),
            ),
          ),
          _Row(
            icon: Icons.tag,
            title: 'problem count',
            description: 'How many problems a count or custom-count test asks.',
            child: _ChipsWithCustom(
              options: countOptions,
              value: s.count,
              onSelected: (n) => update((s) => s.copyWith(count: n)),
              onCustom: () => editNumber('problem count', s.count, (n) => update((s) => s.copyWith(count: n.toInt()))),
            ),
          ),
          _Row(
            icon: Icons.build_outlined,
            title: 'custom goal',
            description: 'Whether custom mode ends on the time limit or the problem count.',
            child: ChoiceChips(
              options: CustomKind.values,
              value: s.customKind,
              label: (k) => k.name,
              onSelected: (k) => update((s) => s.copyWith(customKind: k)),
            ),
          ),
          _Row(
            icon: Icons.bar_chart,
            title: 'difficulty',
            description: 'Presets for every operation\'s number range. Editing a range by hand makes this custom. Personal bests are tracked per range setup.',
            child: ChoiceChips<Difficulty?>(
              options: [...Difficulty.values, null],
              value: difficulty,
              label: (d) => d?.name ?? 'custom',
              onSelected: (d) {
                if (d != null) {
                  update((s) => s.copyWith(ranges: difficultyRanges(d, s.ranges)));
                }
              },
            ),
          ),
          _Row(
            icon: Icons.shuffle,
            title: 'seed',
            description: 'Use the same seed for every test to replay one problem sequence. The web app gives the same problems for the same seed and ranges. Leave empty for a new sequence each time.',
            child: _TextSetting(
              value: s.seed,
              hint: 'random',
              label: 'Seed',
              onChanged: (v) => update((s) => s.copyWith(seed: v)),
            ),
          ),
        ]),
        _Section('operations', [
          for (final op in Operation.values)
            _OperationRow(
              op: op,
              range: s.ranges[op],
              save: (r) => saveRange(op, r),
              check: (r) => validateRanges(s.ranges.withRange(op, r)),
              editNumber: editNumber,
            ),
        ]),
        _Section('input', [
          _Row(
            icon: Icons.keyboard_return,
            title: 'answer style',
            description:
                'Inline puts the answer right after the equals sign. Stacked puts it on a line under the problem.',
            child: ChoiceChips(
              options: AnswerStyle.values,
              value: s.answerStyle,
              label: (a) => a.name,
              onSelected: (a) => update((s) => s.copyWith(answerStyle: a)),
            ),
          ),
          _Row(
            icon: Icons.dialpad,
            title: 'keypad layout',
            description: 'Phone puts 1 2 3 on the top row, like the dialer. Calculator puts 7 8 9 there.',
            child: ChoiceChips(
              options: KeypadLayout.values,
              value: s.keypadLayout,
              label: (k) => k.name,
              onSelected: (k) => update((s) => s.copyWith(keypadLayout: k)),
            ),
          ),
          _Toggle(
            'haptics',
            'A light tap on every correct answer.',
            Icons.vibration,
            s.haptics,
            (v) => update((s) => s.copyWith(haptics: v)),
          ),
        ]),
        _Section('appearance', [
          _Row(
            icon: Icons.format_size,
            title: 'problem size',
            description: 'Size of the problem text. Long problems shrink to fit on one line.',
            child: _ChipsWithCustom<double>(
              options: const [3, 4, 5, 6],
              value: s.size,
              label: (n) => n == n.truncate() ? '${n.toInt()}' : '$n',
              onSelected: (n) => update((s) => s.copyWith(size: n)),
              onCustom: () => editNumber(
                'problem size (2 to 8)',
                s.size,
                (n) => update((s) => s.copyWith(size: n.toDouble())),
                min: 2,
                max: 8,
                whole: false,
              ),
            ),
          ),
          _Row(
            icon: Icons.text_fields,
            title: 'font family',
            description: 'Typeface for the whole app.',
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final f in fonts)
                  ChoiceChip(
                    label: Text(
                      f,
                      style: TextStyle(fontFamily: f, color: s.font == f ? z.main : z.sub),
                    ),
                    selected: s.font == f,
                    onSelected: (_) => update((s) => s.copyWith(font: f)),
                  ),
              ],
            ),
          ),
          _Toggle(
            'live timer',
            'Show the countdown and progress bar during a test.',
            Icons.visibility_outlined,
            s.showTimer,
            (v) => update((s) => s.copyWith(showTimer: v)),
          ),
          _Toggle(
            'live score',
            'Show how many problems you have solved during a test.',
            Icons.visibility_outlined,
            s.showScore,
            (v) => update((s) => s.copyWith(showScore: v)),
          ),
          _Toggle(
            'live pace',
            'Show problems per minute during a test.',
            Icons.visibility_outlined,
            s.showPace,
            (v) => update((s) => s.copyWith(showPace: v)),
          ),
          _Toggle(
            'focus mode',
            'Hide the mode bar and navigation while a test runs.',
            Icons.center_focus_strong_outlined,
            s.focusMode,
            (v) => update((s) => s.copyWith(focusMode: v)),
          ),
        ]),
        _Section('theme', [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, c) => Wrap(
                runSpacing: 8,
                children: [
                  for (final e in themes.entries)
                    ThemeSwatch(
                      name: e.key,
                      theme: e.value,
                      selected: s.theme == e.key,
                      width: (c.maxWidth - 16) / 2,
                      onTap: () => update((s) => s.copyWith(theme: e.key)),
                    ),
                ],
              ),
            ),
          ),
        ]),
        _Section('data', [
          _Row(
            icon: Icons.person_outline,
            title: 'profile name',
            description: 'Shown on your profile.',
            child: _TextSetting(
              value: s.name,
              hint: 'guest',
              label: 'Profile name',
              maxLength: 24,
              onChanged: (v) => update((s) => s.copyWith(name: v)),
            ),
          ),
          _Row(
            icon: Icons.ios_share,
            title: 'export history',
            description:
                'Share all ${history.results.length} results as a JSON file. It is your backup, and the web app can import it.',
            child: OutlinedButton(
              onPressed: history.results.isEmpty ? null : exportHistory,
              child: const Text('export'),
            ),
          ),
          _Row(
            icon: Icons.file_download_outlined,
            title: 'import history',
            description:
                'Merge a Zetamath JSON export from this app or the web app. Results you already have are kept.',
            child: OutlinedButton(onPressed: importHistory, child: const Text('import')),
          ),
          if (history.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(history.error!, style: TextStyle(color: z.error)),
            ),
        ]),
        _Section('danger zone', [
          _Row(
            icon: Icons.delete_outline,
            title: 'clear history',
            description: 'Delete every saved result from this phone. This cannot be undone, so export first.',
            child: OutlinedButton(
              onPressed: history.results.isEmpty
                  ? null
                  : () async {
                      if (await confirm(context, 'Delete all ${history.results.length} results?')) {
                        try {
                          await ref.read(historyProvider.notifier).clear();
                        } catch (e) {
                          message('$e');
                        }
                      }
                    },
              child: Text('clear history', style: TextStyle(color: history.results.isEmpty ? null : z.error)),
            ),
          ),
          _Row(
            icon: Icons.restart_alt,
            title: 'reset settings',
            description: 'Put every setting back to its default. Your history is not touched.',
            child: OutlinedButton(
              onPressed: () async {
                if (await confirm(context, 'Reset all settings?', action: 'reset')) {
                  notifier.reset();
                }
              },
              child: Text('reset settings', style: TextStyle(color: z.error)),
            ),
          ),
        ]),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      initiallyExpanded: true,
      title: Text(title, style: TextStyle(color: context.zeta.main, fontSize: 18)),
      iconColor: context.zeta.main,
      collapsedIconColor: context.zeta.sub,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: children,
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.description, required this.child});
  final IconData icon;
  final String title, description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final z = context.zeta;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: z.sub),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: TextStyle(color: z.text, fontSize: 16)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(description, style: TextStyle(color: z.sub, fontSize: 13)),
          ),
          child,
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle(this.title, this.description, this.icon, this.value, this.onChanged);
  final String title, description;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final z = context.zeta;
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, size: 18, color: z.sub),
      title: Text(title, style: TextStyle(color: z.text, fontSize: 16)),
      subtitle: Text(description, style: TextStyle(color: z.sub, fontSize: 13)),
    );
  }
}

class _ChipsWithCustom<T extends num> extends StatelessWidget {
  const _ChipsWithCustom({
    required this.options,
    required this.value,
    required this.onSelected,
    required this.onCustom,
    this.label,
  });
  final List<T> options;
  final T value;
  final ValueChanged<T> onSelected;
  final VoidCallback onCustom;
  final String Function(T)? label;

  @override
  Widget build(BuildContext context) {
    final preset = options.contains(value);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ChoiceChips(options: options, value: value, onSelected: onSelected, label: label),
        ActionChip(
          avatar: Icon(Icons.edit, size: 16, color: preset ? context.zeta.sub : context.zeta.main),
          label: Text(
            preset ? 'custom' : label?.call(value) ?? '$value',
            style: TextStyle(color: preset ? context.zeta.sub : context.zeta.main),
          ),
          onPressed: onCustom,
        ),
      ],
    );
  }
}

/// A text field that saves as you type, without fighting the cursor on rebuilds.
class _TextSetting extends StatefulWidget {
  const _TextSetting({
    required this.value,
    required this.hint,
    required this.label,
    required this.onChanged,
    this.maxLength,
  });
  final String value, hint, label;
  final ValueChanged<String> onChanged;
  final int? maxLength;

  @override
  State<_TextSetting> createState() => _TextSettingState();
}

class _TextSettingState extends State<_TextSetting> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_TextSetting old) {
    super.didUpdateWidget(old);
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    maxLength: widget.maxLength,
    decoration: InputDecoration(hintText: widget.hint, isDense: true, counterText: '', labelText: widget.label),
    onChanged: widget.onChanged,
  );
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.op,
    required this.range,
    required this.save,
    required this.check,
    required this.editNumber,
  });
  final Operation op;
  final OperationRange range;

  /// Applies the range, or returns why it can't be applied.
  final String? Function(OperationRange) save;

  /// Why the range would be invalid, without applying it, so the dialog can stay open.
  final String? Function(OperationRange) check;
  final Future<void> Function(
    String,
    num,
    void Function(num), {
    num min,
    num max,
    bool whole,
    String? Function(num)? check,
  })
  editNumber;

  @override
  Widget build(BuildContext context) {
    final z = context.zeta;
    final (name, form) = _opNames[op]!;
    Widget field(
      String label,
      num value,
      OperationRange Function(num) patch, {
      num min = 1,
      num max = 1000000,
      bool whole = true,
    }) => ActionChip(
      label: Text(
        '$label ${value is double && value == value.truncate() ? value.toInt() : value}',
        style: TextStyle(color: z.text),
      ),
      onPressed: () => editNumber(
        '$name $label',
        value,
        (n) => save(patch(n)),
        min: min,
        max: max,
        whole: whole,
        check: (n) => check(patch(n)),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('$name ${opLabel(op.symbol)}', style: TextStyle(color: z.text, fontSize: 16)),
              ),
              Switch(
                value: range.enabled,
                onChanged: (v) {
                  final issue = save(range.copyWith(enabled: v));
                  if (issue != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(issue)));
                  }
                },
              ),
            ],
          ),
          Text(
            '$form. Weight sets how often it appears compared with the others.',
            style: TextStyle(color: z.sub, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              field(
                'weight',
                range.weight,
                (n) => range.copyWith(weight: n.toDouble()),
                min: 0,
                max: 1000,
                whole: false,
              ),
              field('a from', range.minA, (n) => range.copyWith(minA: n.toInt())),
              field('a to', range.maxA, (n) => range.copyWith(maxA: n.toInt())),
              field('b from', range.minB, (n) => range.copyWith(minB: n.toInt())),
              field('b to', range.maxB, (n) => range.copyWith(maxB: n.toInt())),
            ],
          ),
        ],
      ),
    );
  }
}
