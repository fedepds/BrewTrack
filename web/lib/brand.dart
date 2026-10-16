import 'package:flutter/material.dart';

import 'models.dart';
import 'util.dart';

/// Etapas de tueste: solo una escala de color (spec 005). No cambian con el tema.
const roastStages = [
  ('Verde', Color(0xFF9FA57A)),
  ('Secado', Color(0xFFD6BE6E)),
  ('Canela', Color(0xFFB5793F)),
  ('Medio', Color(0xFF7A4A2A)),
  ('Oscuro', Color(0xFF3A2318)),
];

/// Color del encabezado con avance [p] (0..1), interpolado entre etapas.
Color stageColor(double p) {
  final x = p.clamp(0.0, 1.0) * (roastStages.length - 1);
  final i = x.floor().clamp(0, roastStages.length - 2);
  return Color.lerp(roastStages[i].$2, roastStages[i + 1].$2, x - i)!;
}

/// Nombre de la etapa más cercana a [p].
String stageName(double p) =>
    roastStages[(p.clamp(0.0, 1.0) * (roastStages.length - 1)).round()].$1;

/// Negro o blanco puro: el que da más contraste WCAG con [bg].
Color onColor(Color bg) {
  final l = bg.computeLuminance();
  return (l + 0.05) / 0.05 >= 1.05 / (l + 0.05) ? Colors.black : Colors.white;
}

/// Contraste WCAG entre dos colores.
double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
}

/// Color de cada nivel de tueste (claro Canela, medio Medio, oscuro Oscuro).
Color levelColor(String? level) => switch (level) {
  'light' => roastStages[2].$2,
  'medium' => roastStages[3].$2,
  'dark' => roastStages[4].$2,
  _ => roastStages[3].$2,
};

const stencil = TextStyle(
  fontFamily: 'BigShouldersStencil',
  fontWeight: FontWeight.w700,
  letterSpacing: 0.5,
);
const mono = TextStyle(
  fontFamily: 'IBMPlexMono',
  fontFeatures: [FontFeature.tabularFigures()],
);

Widget m(String s) => Text(s, style: mono);

/// Título con el código de lote en letra stencil.
Widget codeTitle(String code, [String rest = '']) => Text.rich(
  TextSpan(
    children: [
      TextSpan(text: code, style: stencil),
      TextSpan(text: rest),
    ],
  ),
);

ThemeData brandTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final bg = dark ? const Color(0xFF1A1511) : const Color(0xFFEEF0E6);
  final surface = dark ? const Color(0xFF241D17) : const Color(0xFFF8F9F3);
  final text = dark ? const Color(0xFFEDE6DA) : const Color(0xFF2B1D14);
  final accent = dark ? const Color(0xFFD19256) : const Color(0xFFA86A33);
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: b)
      .copyWith(
        primary: accent,
        onPrimary: onColor(accent),
        surface: surface,
        onSurface: text,
        onSurfaceVariant: text,
        surfaceTint: Colors.transparent,
      );
  // Indicador de foco visible (3:1) en botones y campos.
  final focusSide = WidgetStateProperty.resolveWith<BorderSide?>(
    (s) => s.contains(WidgetState.focused)
        ? BorderSide(color: text, width: 3)
        : null,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    fontFamily: 'PublicSans',
    dialogTheme: DialogThemeData(backgroundColor: surface),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(side: focusSide),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(side: focusSide),
    ),
    textButtonTheme: TextButtonThemeData(style: ButtonStyle(side: focusSide)),
    iconButtonTheme: IconButtonThemeData(style: ButtonStyle(side: focusSide)),
    inputDecorationTheme: InputDecorationTheme(
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: accent, width: 3),
      ),
    ),
  );
}

/// Anillo de foco de 3 px (color del texto) cuando el InkWell que lo contiene tiene el foco.
/// Material solo pinta un resaltado tenue en NavigationRail, NavigationBar y filas de tabla.
class FocusRing extends StatelessWidget {
  const FocusRing({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final f = Focus.maybeOf(context);
    final on = f != null && f is! FocusScopeNode && f.hasFocus;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(
          color: on
              ? Theme.of(context).colorScheme.onSurface
              : Colors.transparent,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: const EdgeInsets.all(4), child: child),
    );
  }
}

/// Barra de proporción: [ratio] de 0 a 1. Con [outline] el relleno lleva borde.
class RatioBar extends StatelessWidget {
  const RatioBar({
    super.key,
    required this.ratio,
    required this.color,
    this.outline = false,
    this.fillKey,
  });
  final double ratio;
  final Color color;
  final bool outline;
  final Key? fillKey;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: s.outlineVariant,
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: ratio.clamp(0.0, 1.0),
        child: Container(
          key: fillKey,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
            border: outline ? Border.all(color: s.onSurface, width: 1.5) : null,
          ),
        ),
      ),
    );
  }
}

/// Barra de stock con su cifra. Usa el stock y lo recibido que da la API.
class StockBar extends StatelessWidget {
  const StockBar(this.lot, {super.key});
  final Lot lot;

  @override
  Widget build(BuildContext context) {
    final ratio = lot.receivedKg > 0 ? lot.stockKg / lot.receivedKg : 0.0;
    final low = lot.stockKg * 100 < lot.receivedKg * 15;
    return Semantics(
      label: 'Quedan ${(ratio * 100).round()} % de lo recibido',
      child: SizedBox(
        width: 190,
        child: ExcludeSemantics(
          child: Row(
            children: [
              Expanded(
                child: RatioBar(
                  ratio: ratio,
                  color: low
                      ? roastStages[1].$2
                      : Theme.of(context).colorScheme.primary,
                  outline: low,
                  fillKey: const Key('stock-fill'),
                ),
              ),
              const SizedBox(width: 8),
              m(fmtKg(lot.stockKg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip con punto de color y el nombre del nivel.
class LevelChip extends StatelessWidget {
  const LevelChip(this.level, {super.key});
  final String level;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: s.outline),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('level-dot'),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: levelColor(level),
              shape: BoxShape.circle,
              border: Border.all(color: s.onSurface, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(roastLevels[level] ?? level),
        ],
      ),
    );
  }
}
