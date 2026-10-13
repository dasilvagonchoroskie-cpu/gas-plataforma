import 'package:flutter/material.dart';

/// Cria o tema Material 3 comum às interfaces da plataforma.
ThemeData criarTemaPlataforma({
  Color corPrimaria = const Color(0xFF176B5B),
}) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: corPrimaria),
    useMaterial3: true,
  );
}
