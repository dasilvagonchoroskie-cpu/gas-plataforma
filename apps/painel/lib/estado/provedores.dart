import 'dart:async';

import 'package:dados/dados.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../tipo_painel.dart';

final provedorCliente = Provider<SupabaseClient>((ref) => clienteBackend);

final provedorConta = Provider<RepositorioConta>(
    (ref) => RepositorioConta(ref.watch(provedorCliente)));

final provedorPedidos = Provider<RepositorioPedidos>(
    (ref) => RepositorioPedidos(ref.watch(provedorCliente)));

final provedorGestao = Provider<RepositorioGestao>(
    (ref) => RepositorioGestao(ref.watch(provedorCliente)));

final provedorNotificacoesConfig = Provider<RepositorioNotificacoes>(
    (ref) => RepositorioNotificacoes(ref.watch(provedorCliente)));

/// Identificadores dos dois apps no Firebase (vêm do build; vazio = sem push).
const _firebaseAppSuperCentral =
    String.fromEnvironment('FIREBASE_APP_SUPERCENTRAL');
const _firebaseAppCentral = String.fromEnvironment('FIREBASE_APP_CENTRAL');

final provedorNotificacoes = Provider<ServicoNotificacoes>((ref) {
  final tipo = ref.watch(provedorTipoPainel);
  final servico = ServicoNotificacoes(
    ref.watch(provedorCliente),
    ConfiguracaoFirebase.doAmbiente(
      appId: tipo == TipoPainel.superCentral
          ? _firebaseAppSuperCentral
          : _firebaseAppCentral,
    ),
  );
  ref.onDispose(servico.dispose);
  return servico;
});

final provedorEnderecos = Provider<RepositorioEnderecos>(
    (ref) => RepositorioEnderecos(ref.watch(provedorCliente)));

/// Avisa a tela raiz sempre que alguém entra ou sai.
class EstadoDeLogin extends ChangeNotifier {
  EstadoDeLogin(this._conta) : _usuarioId = _conta.usuarioId {
    _assinatura = _conta.mudancasDeLogin.listen((_) {
      // Só avisa quando a pessoa muda (entrou, saiu ou trocou de conta), não a
      // cada renovação automática do login.
      final atual = _conta.usuarioId;
      if (atual != _usuarioId) {
        _usuarioId = atual;
        notifyListeners();
      }
    });
  }

  final RepositorioConta _conta;
  late final StreamSubscription<AuthState> _assinatura;
  String? _usuarioId;

  bool get logado => _usuarioId != null && _conta.logado;
  String? get usuarioId => _usuarioId;

  @override
  void dispose() {
    _assinatura.cancel();
    super.dispose();
  }
}

final provedorEstadoDeLogin = ChangeNotifierProvider<EstadoDeLogin>(
    (ref) => EstadoDeLogin(ref.watch(provedorConta)));

final provedorUsuarioId =
    Provider<String?>((ref) => ref.watch(provedorEstadoDeLogin).usuarioId);

final provedorPerfil = FutureProvider<Perfil?>((ref) async {
  if (ref.watch(provedorUsuarioId) == null) {
    return null;
  }
  return ref.watch(provedorConta).perfilAtual();
});

/// Centrais visíveis para quem está logado (o dono vê todas).
final provedorCentrais = FutureProvider<List<Central>>((ref) async {
  ref.watch(provedorUsuarioId);
  return ref.watch(provedorGestao).centrais();
});

final provedorProdutos = FutureProvider<List<Produto>>((ref) async {
  ref.watch(provedorUsuarioId);
  return ref.watch(provedorGestao).produtos();
});

// ---------------------------------------------------------------------------
// Ficha de cadastro e crediário
// ---------------------------------------------------------------------------

final provedorCredito = Provider<RepositorioCredito>(
    (ref) => RepositorioCredito(ref.watch(provedorCliente)));

/// Configurações da revenda (o dono altera; a central só lê).
final provedorConfiguracoes = FutureProvider<Configuracoes>((ref) async {
  ref.watch(provedorUsuarioId);
  return ref.watch(provedorCredito).configuracoes();
});

/// Quantas fichas esperam análise (aviso no menu). Zero se não puder ver.
final provedorFichasPendentes = FutureProvider<int>((ref) async {
  ref.watch(provedorUsuarioId);
  try {
    final fichas =
        await ref.watch(provedorCredito).fichas(status: StatusFicha.pendente);
    return fichas.length;
  } catch (_) {
    return 0;
  }
});
