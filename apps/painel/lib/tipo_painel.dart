import 'package:flutter/services.dart' show appFlavor;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

/// Os dois aplicativos que saem deste mesmo código.
///
/// - **Super Central:** só o dono entra; mostra todas as lojas.
/// - **Central:** só o funcionário da loja entra; mostra a loja dele.
///
/// O tipo vem do build: `--flavor` no Android e `--dart-define=PAINEL=...` no
/// web. Sem nenhum dos dois, vale o Central (o que tem menos acesso). Isto só
/// escolhe a tela: quem garante o que cada conta pode ver é o banco (RLS).
enum TipoPainel {
  superCentral(
    valor: 'supercentral',
    nome: 'Super Central',
    descricao: 'Acesso do dono: todas as lojas',
  ),
  central(
    valor: 'central',
    nome: 'Central',
    descricao: 'Acesso da loja: pedidos e entregas',
  );

  const TipoPainel(
      {required this.valor, required this.nome, required this.descricao});

  final String valor;
  final String nome;
  final String descricao;

  static TipoPainel deValor(String? valor) =>
      valor?.trim().toLowerCase() == superCentral.valor
          ? superCentral
          : central;

  /// O tipo escolhido no build deste aplicativo.
  static TipoPainel get doBuild {
    const definido = String.fromEnvironment('PAINEL');
    return deValor(definido.isNotEmpty ? definido : appFlavor);
  }

  /// Por que esta conta não pode usar este aplicativo (nulo quando pode).
  String? motivoSemAcesso(Perfil perfil) {
    if (perfil.papel == PapelPerfil.cliente) {
      return 'Esta conta é de cliente. Para pedir, use o aplicativo de '
          'pedidos.';
    }
    if (!perfil.ativo) {
      return 'Sua conta foi desativada. Fale com o dono da revenda.';
    }
    switch (this) {
      case TipoPainel.superCentral:
        if (perfil.papel == PapelPerfil.dono) {
          return null;
        }
        return 'Este aplicativo é só do dono da revenda. Para atender a sua '
            'loja, use o aplicativo Central.';
      case TipoPainel.central:
        if (perfil.papel == PapelPerfil.dono) {
          return 'Esta conta é do dono. Use o aplicativo Super Central, que '
              'mostra todas as lojas.';
        }
        if (perfil.papel == PapelPerfil.operadorCentral &&
            perfil.centralId != null) {
          return null;
        }
        return 'Sua conta ainda não está ligada a uma loja. Fale com o dono '
            'da revenda.';
    }
  }
}

/// Tipo deste aplicativo (os testes podem trocar).
final provedorTipoPainel = Provider<TipoPainel>((ref) => TipoPainel.doBuild);
