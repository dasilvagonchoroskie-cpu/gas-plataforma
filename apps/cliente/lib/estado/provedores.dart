import 'dart:async';

import 'package:dados/dados.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Repositórios
// ---------------------------------------------------------------------------

final provedorCliente = Provider<SupabaseClient>((ref) => clienteBackend);

final provedorConta =
    Provider<RepositorioConta>((ref) => RepositorioConta(ref.watch(provedorCliente)));

final provedorRepositorioEnderecos = Provider<RepositorioEnderecos>(
  (ref) => RepositorioEnderecos(ref.watch(provedorCliente)),
);

final provedorRepositorioPedidos = Provider<RepositorioPedidos>(
  (ref) => RepositorioPedidos(ref.watch(provedorCliente)),
);

final provedorRepositorioCredito = Provider<RepositorioCredito>(
  (ref) => RepositorioCredito(ref.watch(provedorCliente)),
);

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

/// Avisa o roteador sempre que a pessoa entra ou sai.
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
  (ref) => EstadoDeLogin(ref.watch(provedorConta)),
);

/// Id do usuário logado; muda quando a pessoa entra, sai ou troca de conta.
final provedorUsuarioId = Provider<String?>((ref) => ref.watch(provedorEstadoDeLogin).usuarioId);

final provedorPerfil = FutureProvider<Perfil?>((ref) async {
  if (ref.watch(provedorUsuarioId) == null) {
    return null;
  }
  return ref.watch(provedorConta).perfilAtual();
});

// ---------------------------------------------------------------------------
// Endereços e central que atende
// ---------------------------------------------------------------------------

final provedorEnderecos = FutureProvider<List<Endereco>>((ref) async {
  if (ref.watch(provedorUsuarioId) == null) {
    return const [];
  }
  return ref.watch(provedorRepositorioEnderecos).listar();
});

const _chaveEnderecoEscolhido = 'endereco_escolhido';

/// Endereço escolhido para entrega (lembrado entre aberturas do app).
class EnderecoEscolhido extends Notifier<String?> {
  @override
  String? build() {
    unawaited(_carregar());
    return null;
  }

  Future<void> _carregar() async {
    final preferencias = await SharedPreferences.getInstance();
    final salvo = preferencias.getString(_chaveEnderecoEscolhido);
    if (salvo != null && state == null) {
      state = salvo;
    }
  }

  Future<void> escolher(String? id) async {
    state = id;
    final preferencias = await SharedPreferences.getInstance();
    if (id == null) {
      await preferencias.remove(_chaveEnderecoEscolhido);
    } else {
      await preferencias.setString(_chaveEnderecoEscolhido, id);
    }
  }
}

final provedorIdEnderecoEscolhido =
    NotifierProvider<EnderecoEscolhido, String?>(EnderecoEscolhido.new);

/// Endereço de entrega atual: o escolhido ou, se não houver, o primeiro.
final provedorEnderecoAtual = FutureProvider<Endereco?>((ref) async {
  final lista = await ref.watch(provedorEnderecos.future);
  final escolhido = ref.watch(provedorIdEnderecoEscolhido);
  if (lista.isEmpty) {
    return null;
  }
  for (final endereco in lista) {
    if (endereco.id == escolhido) {
      return endereco;
    }
  }
  return lista.first;
});

/// Central mais próxima que atende o endereço atual (nulo: não atende).
final provedorAtendimento = FutureProvider<Atendimento?>((ref) async {
  final endereco = await ref.watch(provedorEnderecoAtual.future);
  final id = endereco?.id;
  if (id == null) {
    return null;
  }
  return ref.watch(provedorRepositorioPedidos).atendimento(id);
});

final provedorCatalogo = FutureProvider<List<ItemCatalogo>>((ref) async {
  final atendimento = await ref.watch(provedorAtendimento.future);
  if (atendimento == null) {
    return const [];
  }
  return ref.watch(provedorRepositorioPedidos).catalogo(atendimento.centralId);
});

// ---------------------------------------------------------------------------
// Carrinho e finalização
// ---------------------------------------------------------------------------

class EstadoCarrinho extends Notifier<Carrinho> {
  @override
  Carrinho build() => const Carrinho.vazio();

  void adicionar(ItemCatalogo item) => state = state.adicionar(item);

  void remover(ItemCatalogo item) => state = state.remover(item);

  void definir(ItemCatalogo item, int quantidade) =>
      state = state.definir(item, quantidade);

  void substituir(Carrinho carrinho) => state = carrinho;

  void limpar() => state = const Carrinho.vazio();
}

final provedorCarrinho =
    NotifierProvider<EstadoCarrinho, Carrinho>(EstadoCarrinho.new);

/// Escolhas da finalização: horário, pagamento, troco e observação.
@immutable
class DadosFinalizacao {
  const DadosFinalizacao({
    required this.chaveIdempotencia,
    this.horario,
    this.formaPagamento = FormaPagamento.dinheiro,
    this.trocoPara,
    this.observacao = '',
  });

  /// Uma chave por tentativa de pedido: reenviar não duplica.
  final String chaveIdempotencia;
  final HorarioDisponivel? horario;
  final FormaPagamento formaPagamento;
  final Dinheiro? trocoPara;
  final String observacao;

  DadosFinalizacao copiar({
    HorarioDisponivel? horario,
    FormaPagamento? formaPagamento,
    Dinheiro? trocoPara,
    bool limparTroco = false,
    String? observacao,
  }) =>
      DadosFinalizacao(
        chaveIdempotencia: chaveIdempotencia,
        horario: horario ?? this.horario,
        formaPagamento: formaPagamento ?? this.formaPagamento,
        trocoPara: limparTroco ? null : (trocoPara ?? this.trocoPara),
        observacao: observacao ?? this.observacao,
      );
}

class EstadoFinalizacao extends Notifier<DadosFinalizacao> {
  @override
  DadosFinalizacao build() =>
      DadosFinalizacao(chaveIdempotencia: gerarIdentificadorUnico());

  void escolherHorario(HorarioDisponivel horario) =>
      state = state.copiar(horario: horario);

  void escolherPagamento(FormaPagamento forma) => state = state.copiar(
        formaPagamento: forma,
        limparTroco: forma != FormaPagamento.dinheiro,
      );

  void definirTroco(Dinheiro? valor) =>
      state = valor == null ? state.copiar(limparTroco: true) : state.copiar(trocoPara: valor);

  void definirObservacao(String texto) => state = state.copiar(observacao: texto);

  /// Depois de um pedido feito, a próxima compra recebe uma chave nova.
  void recomecar() =>
      state = DadosFinalizacao(chaveIdempotencia: gerarIdentificadorUnico());
}

final provedorFinalizacao =
    NotifierProvider<EstadoFinalizacao, DadosFinalizacao>(EstadoFinalizacao.new);

// ---------------------------------------------------------------------------
// Pedidos
// ---------------------------------------------------------------------------

final provedorMeusPedidos = FutureProvider<List<Pedido>>((ref) async {
  if (ref.watch(provedorUsuarioId) == null) {
    return const [];
  }
  return ref.watch(provedorRepositorioPedidos).meusPedidos();
});

/// Pedido acompanhado ao vivo: recarrega a cada mudança enviada pelo servidor.
final provedorPedidoAoVivo =
    StreamProvider.autoDispose.family<Pedido?, String>((ref, id) async* {
  final repositorio = ref.watch(provedorRepositorioPedidos);
  yield await repositorio.pedido(id);
  await for (final _ in repositorio.mudancasDoPedido(id)) {
    yield await repositorio.pedido(id);
  }
});

// ---------------------------------------------------------------------------
// Ficha de cadastro e crediário
// ---------------------------------------------------------------------------

/// Ficha do cliente logado (nula enquanto não enviar).
final provedorMinhaFicha = FutureProvider<FichaCliente?>((ref) async {
  if (ref.watch(provedorUsuarioId) == null) {
    return null;
  }
  return ref.watch(provedorRepositorioCredito).minhaFicha();
});

/// Situação do crediário do cliente logado.
final provedorMeuCredito = FutureProvider<ResumoCredito?>((ref) async {
  if (ref.watch(provedorUsuarioId) == null) {
    return null;
  }
  // Recarrega junto com a ficha (aprovação, envio).
  await ref.watch(provedorMinhaFicha.future);
  return ref.watch(provedorRepositorioCredito).resumo();
});

final provedorMeuExtrato = FutureProvider.autoDispose<List<LancamentoCredito>>((ref) async {
  final id = ref.watch(provedorUsuarioId);
  if (id == null) {
    return const [];
  }
  return ref.watch(provedorRepositorioCredito).extrato(id);
});
