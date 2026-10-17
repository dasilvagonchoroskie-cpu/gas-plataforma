import 'package:flutter/material.dart';

import 'tema_plataforma.dart';

/// Marca da revenda: nomes, frase e cor. Vem do build, a partir de
/// `marca/marca.json` (--dart-define-from-file). Para trocar a marca, troque só
/// os arquivos da pasta `marca/` e gere os apps de novo.
abstract final class Marca {
  /// Nome do app do cliente (e da revenda nas telas).
  static const String nome =
      String.fromEnvironment('NOME_APP', defaultValue: 'Gás e Água');

  /// Frase da tela de entrada do cliente.
  static const String slogan = String.fromEnvironment('SLOGAN',
      defaultValue: 'Peça gás e água sem sair de casa.');

  /// Nome do aplicativo do dono.
  static const String nomeSuperCentral =
      String.fromEnvironment('NOME_SUPER_CENTRAL', defaultValue: 'Super Central');

  /// Nome do aplicativo das lojas.
  static const String nomeCentral =
      String.fromEnvironment('NOME_CENTRAL', defaultValue: 'Central');

  static const String _corPrincipal = String.fromEnvironment('COR_PRINCIPAL');

  /// Cor principal dos apps (botões, destaques).
  static Color get corPrincipal => lerCor(_corPrincipal) ?? corPadraoPlataforma;

  /// Lê uma cor escrita como "#0B5C7A" (nulo se estiver errada ou vazia).
  static Color? lerCor(String texto) {
    final limpo = texto.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(limpo)) {
      return null;
    }
    return Color(int.parse('FF$limpo', radix: 16));
  }
}

/// Logo da revenda (arquivo `marca/logo.png`, copiado para os apps pelo
/// script `scripts/aplicar_marca.py`). Sem o arquivo, mostra um ícone.
class LogoMarca extends StatelessWidget {
  const LogoMarca({this.tamanho = 72, super.key});

  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/marca/logo.png',
      package: 'design_system',
      height: tamanho,
      width: tamanho,
      semanticLabel: Marca.nome,
      errorBuilder: (context, erro, pilha) => Icon(
        Icons.local_fire_department_rounded,
        size: tamanho,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
