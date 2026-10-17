import 'package:flutter/material.dart';

import 'marca.dart';

/// Cor principal padrão (azul petróleo). A cor da revenda vem de
/// `marca/marca.json` (Marca.corPrincipal); o parâmetro `corPrimaria` troca
/// só para um caso específico.
const Color corPadraoPlataforma = Color(0xFF0B5C7A);

/// Tema comum aos apps: textos e botões grandes (muitos clientes são idosos),
/// bom contraste e campos fáceis de tocar.
ThemeData criarTemaPlataforma({
  Color? corPrimaria,
  Brightness brilho = Brightness.light,
}) {
  final cores = ColorScheme.fromSeed(
      seedColor: corPrimaria ?? Marca.corPrincipal, brightness: brilho);
  final base = ThemeData(colorScheme: cores, useMaterial3: true);
  final textos = base.textTheme.copyWith(
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.35),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 16, height: 1.35),
    titleMedium: base.textTheme.titleMedium
        ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
    titleLarge: base.textTheme.titleLarge
        ?.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
    labelLarge: base.textTheme.labelLarge
        ?.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
  );

  const formato = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );

  return base.copyWith(
    textTheme: textos,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: cores.surface,
      foregroundColor: cores.onSurface,
      titleTextStyle: textos.titleLarge?.copyWith(color: cores.onSurface),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        shape: formato,
        textStyle: textos.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: formato,
        textStyle: textos.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        textStyle: textos.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cores.surfaceContainerHighest.withValues(alpha: 0.45),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(fontSize: 17),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: cores.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 12,
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: const TextStyle(fontSize: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  );
}
