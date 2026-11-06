import 'package:flutter/material.dart';

import '../../themes/themes.dart';

/// Equal-width options in one track, the selected one lifted out in the accent colour.
/// Used for every single choice on the practice screen and its sheet, so they all read alike.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onSelected,
    required this.label,
    this.icon,
    this.height = 44,
  });
  final List<T> options;
  final T? value;
  final ValueChanged<T>? onSelected;
  final String Function(T) label;
  final IconData Function(T)? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final z = context.zeta;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: z.raised, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: o == value,
                label: label(o),
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onSelected == null ? null : () => onSelected!(o),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: height,
                    decoration: BoxDecoration(
                      color: o == value ? z.main.withValues(alpha: .2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: icon == null
                            ? Text(label(o), style: _style(z, o == value))
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon!(o), size: 20, color: o == value ? z.main : z.muted),
                                  const SizedBox(height: 4),
                                  Text(label(o), style: _style(z, o == value).copyWith(fontSize: 13)),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  TextStyle _style(ZetaTheme z, bool selected) => TextStyle(
    fontSize: 15,
    color: selected ? z.main : z.muted,
    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
  );
}
