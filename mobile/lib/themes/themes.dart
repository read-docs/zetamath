import 'package:flutter/material.dart';

/// The five web theme colours. `main` is the accent, `sub` the muted text.
class ZetaTheme {
  const ZetaTheme(this.bg, this.main, this.sub, this.text, this.error);
  final Color bg, main, sub, text, error;

  bool get isLight => bg.computeLuminance() > 0.5;
}

/// Same 15 presets as `web/src/themes/index.ts`.
const themes = <String, ZetaTheme>{
  'iceberg': ZetaTheme(Color(0xff161821), Color(0xff84a0c6), Color(0xff6b7089), Color(0xffc6c8d1), Color(0xffe27878)),
  'monochrome': ZetaTheme(
    Color(0xff161616),
    Color(0xffeeeeee),
    Color(0xff818181),
    Color(0xffc5c5c5),
    Color(0xffaaaaaa),
  ),
  'nord': ZetaTheme(Color(0xff2e3440), Color(0xff88c0d0), Color(0xff8b95a6), Color(0xffeceff4), Color(0xffbf616a)),
  'rose': ZetaTheme(Color(0xff211b24), Color(0xffebbcba), Color(0xff9b819b), Color(0xffe0def4), Color(0xffeb6f92)),
  'forest': ZetaTheme(Color(0xff18221e), Color(0xffa7c080), Color(0xff859289), Color(0xffd3c6aa), Color(0xffe67e80)),
  'ocean': ZetaTheme(Color(0xff10252f), Color(0xff6ed6db), Color(0xff7596a3), Color(0xffd4e8ef), Color(0xfff48b8b)),
  'lavender': ZetaTheme(Color(0xff232136), Color(0xffc4a7e7), Color(0xff908caa), Color(0xffe0def4), Color(0xffeb6f92)),
  'amber': ZetaTheme(Color(0xff24201a), Color(0xffe5b567), Color(0xffa09581), Color(0xffe9dfce), Color(0xffe17e76)),
  'terminal': ZetaTheme(Color(0xff101710), Color(0xff80d880), Color(0xff729572), Color(0xffc4dfc4), Color(0xffe28b7a)),
  'midnight': ZetaTheme(Color(0xff0e1525), Color(0xff82aaff), Color(0xff7b8ba9), Color(0xffc8d3f5), Color(0xffff757f)),
  'plum': ZetaTheme(Color(0xff2a1c30), Color(0xffdba6e8), Color(0xffaa88ad), Color(0xffeee0ef), Color(0xffff8f9c)),
  'coffee': ZetaTheme(Color(0xff28221f), Color(0xffd6ae88), Color(0xffa49486), Color(0xffe2d7cb), Color(0xffe28779)),
  'paper': ZetaTheme(Color(0xfff4f1e8), Color(0xff7a5737), Color(0xff81786c), Color(0xff37332d), Color(0xffb43c3c)),
  'snow': ZetaTheme(Color(0xfff0f4f8), Color(0xff396ba5), Color(0xff69788a), Color(0xff273548), Color(0xffbd3a52)),
  'mint': ZetaTheme(Color(0xffe9f1eb), Color(0xff356e52), Color(0xff677d6e), Color(0xff283e30), Color(0xffb63f49)),
};

ZetaTheme themeNamed(String name) => themes[name] ?? themes['iceberg']!;

/// Material theme built from a preset, so stock widgets (switches, sheets, dialogs, text fields) follow it.
ThemeData buildTheme(ZetaTheme t, String font) {
  final scheme = ColorScheme(
    brightness: t.isLight ? Brightness.light : Brightness.dark,
    primary: t.main,
    onPrimary: t.bg,
    secondary: t.sub,
    onSecondary: t.bg,
    error: t.error,
    onError: t.bg,
    surface: t.bg,
    onSurface: t.text,
    onSurfaceVariant: t.sub,
    outline: t.sub,
    outlineVariant: t.sub.withValues(alpha: .3),
    surfaceContainerLowest: t.bg,
    surfaceContainerLow: Color.lerp(t.bg, t.sub, .06),
    surfaceContainer: Color.lerp(t.bg, t.sub, .1),
    surfaceContainerHigh: Color.lerp(t.bg, t.sub, .14),
    surfaceContainerHighest: Color.lerp(t.bg, t.sub, .18),
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: t.bg,
    fontFamily: font,
    extensions: [ZetaColors(t)],
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.bg,
      indicatorColor: t.main.withValues(alpha: .18),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? t.main : t.sub),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(fontFamily: font, fontSize: 12, color: s.contains(WidgetState.selected) ? t.main : t.sub),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: t.main.withValues(alpha: .18),
      side: BorderSide.none,
      labelStyle: TextStyle(fontFamily: font, color: t.sub),
      secondaryLabelStyle: TextStyle(fontFamily: font, color: t.main),
      showCheckmark: false,
    ),
    dividerColor: t.sub.withValues(alpha: .2),
  );
}

/// Gives widgets direct access to the raw preset colours.
class ZetaColors extends ThemeExtension<ZetaColors> {
  const ZetaColors(this.theme);
  final ZetaTheme theme;

  @override
  ZetaColors copyWith({ZetaTheme? theme}) => ZetaColors(theme ?? this.theme);

  @override
  ZetaColors lerp(ZetaColors? other, double t) => t < .5 || other == null ? this : other;
}

extension ZetaContext on BuildContext {
  ZetaTheme get zeta => Theme.of(this).extension<ZetaColors>()!.theme;
}
