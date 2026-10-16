import 'package:nucleo/nucleo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'erros.dart';

/// Campos do pedido com itens, histórico, central e entregador.
const String _camposPedido =
    '*, itens_pedido(*), historico_status(status, evento, observacao, criado_em), '
    'centrais(nome, whatsapp), entregadores(nome)';

/// Catálogo, agenda e pedidos — do lado do cliente e da central.
class RepositorioPedidos {
  RepositorioPedidos(this._cliente);

  final SupabaseClient _cliente;

  // -------------------------------------------------------------------------
  // Cliente
  // -------------------------------------------------------------------------

  /// Central que atende o endereço (nulo se ninguém atende).
  Future<Atendimento?> atendimento(String enderecoId) async {
    final linhas = await _cliente.rpc(
      'atendimento_para_endereco',
      params: {'p_endereco_id': enderecoId},
    ) as List<dynamic>;
    if (linhas.isEmpty) {
      return null;
    }
    return Atendimento.deJson(Map<String, dynamic>.from(linhas.first as Map));
  }

  /// Produtos à venda na central, já com preço.
  Future<List<ItemCatalogo>> catalogo(String centralId) async {
    final linhas = await _cliente
        .from('precos_central')
        .select('central_id, produto_id, preco_centavos, disponivel, produtos(*)')
        .eq('central_id', centralId)
        .eq('disponivel', true);
    final itens = linhas
        .map(ItemCatalogo.deJson)
        .where((i) => i.produto.ativo && i.produto.id.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final ordem = a.produto.ordem.compareTo(b.produto.ordem);
        return ordem != 0 ? ordem : a.produto.nome.compareTo(b.produto.nome);
      });
    return itens;
  }

  /// Horários com vaga nos próximos dias.
  Future<List<HorarioDisponivel>> agenda(String centralId, {int dias = 7}) async {
    final linhas = await _cliente.rpc(
      'agenda_disponivel',
      params: {'p_central_id': centralId, 'p_dias': dias},
    ) as List<dynamic>;
    return linhas
        .map((l) => HorarioDisponivel.deJson(Map<String, dynamic>.from(l as Map)))
        .toList();
  }

  /// Cria o pedido. A chave evita duplicar se o app precisar reenviar.
  Future<({String id, int numero, bool repetido})> criarPedido({
    required String enderecoId,
    required HorarioDisponivel horario,
    required FormaPagamento formaPagamento,
    required Carrinho carrinho,
    required String chaveIdempotencia,
    Dinheiro? trocoPara,
    String? observacao,
  }) async {
    if (carrinho.vazio) {
      throw const ErroDeNegocio('Seu carrinho está vazio.');
    }
    final resposta = await _cliente.rpc('criar_pedido', params: {
      'p_endereco_id': enderecoId,
      'p_data_entrega': Datas.paraBanco(horario.data),
      'p_janela_id': horario.janelaId,
      'p_forma_pagamento': formaPagamento.valor,
      'p_itens': carrinho.paraPedido(),
      'p_chave_idempotencia': chaveIdempotencia,
      'p_troco_para_centavos':
          formaPagamento == FormaPagamento.dinheiro ? (trocoPara?.centavos ?? 0) : 0,
      'p_observacao': (observacao ?? '').trim().isEmpty ? null : observacao!.trim(),
    });
    final dados = Map<String, dynamic>.from(resposta as Map);
    return (
      id: dados['id'] as String,
      numero: (dados['numero'] as num).toInt(),
      repetido: dados['repetido'] == true,
    );
  }

  Future<List<Pedido>> meusPedidos({int limite = 50}) async {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) {
      return const [];
    }
    final linhas = await _cliente
        .from('pedidos')
        .select(_camposPedido)
        .eq('cliente_id', id)
        .order('criado_em', ascending: false)
        .limit(limite);
    return linhas.map(Pedido.deJson).toList();
  }

  Future<Pedido?> pedido(String id) async {
    final dados = await _cliente
        .from('pedidos')
        .select(_camposPedido)
        .eq('id', id)
        .maybeSingle();
    return dados == null ? null : Pedido.deJson(dados);
  }

  /// Avisa a cada mudança do pedido (status, transferência, entregador).
  Stream<void> mudancasDoPedido(String id) => _cliente
      .from('pedidos')
      .stream(primaryKey: ['id'])
      .eq('id', id)
      .map((_) {});

  Future<void> cancelarComoCliente(String pedidoId) async {
    await _cliente.rpc('mudar_status_pedido', params: {
      'p_pedido_id': pedidoId,
      'p_novo_status': StatusPedido.cancelado.valor,
      'p_motivo': 'Cancelado pelo cliente no aplicativo',
    });
  }

  // -------------------------------------------------------------------------
  // Central
  // -------------------------------------------------------------------------

  /// Pedidos da central: em andamento de qualquer data e encerrados desde
  /// `desde` (padrão: hoje).
  Future<List<Pedido>> pedidosDaCentral(String centralId, {DateTime? desde}) async {
    final inicio = desde ?? Datas.hoje();
    final emAndamento = await _cliente
        .from('pedidos')
        .select(_camposPedido)
        .eq('central_id', centralId)
        .inFilter('status', [
          StatusPedido.novo.valor,
          StatusPedido.confirmado.valor,
          StatusPedido.emRota.valor,
        ])
        .order('data_entrega')
        .order('hora_inicio')
        .limit(500);
    final encerrados = await _cliente
        .from('pedidos')
        .select(_camposPedido)
        .eq('central_id', centralId)
        .inFilter('status', [StatusPedido.entregue.valor, StatusPedido.cancelado.valor])
        .gte('atualizado_em', inicio.subtract(Datas.fuso).toIso8601String())
        .order('atualizado_em', ascending: false)
        .limit(300);
    return [
      ...emAndamento.map(Pedido.deJson),
      ...encerrados.map(Pedido.deJson),
    ];
  }

  /// Avisa quando um pedido da central muda (ou chega um novo).
  Stream<List<Map<String, dynamic>>> mudancasDaCentral(String centralId) => _cliente
      .from('pedidos')
      .stream(primaryKey: ['id'])
      .eq('central_id', centralId);

  Future<void> mudarStatus(String pedidoId, StatusPedido novo, {String? motivo}) async {
    await _cliente.rpc('mudar_status_pedido', params: {
      'p_pedido_id': pedidoId,
      'p_novo_status': novo.valor,
      'p_motivo': motivo,
    });
  }

  Future<void> atribuirEntregador(String pedidoId, String? entregadorId) async {
    await _cliente.rpc('atribuir_entregador', params: {
      'p_pedido_id': pedidoId,
      'p_entregador_id': entregadorId,
    });
  }

  Future<List<OpcaoTransferencia>> opcoesTransferencia(String pedidoId) async {
    final linhas = await _cliente.rpc(
      'opcoes_transferencia',
      params: {'p_pedido_id': pedidoId},
    ) as List<dynamic>;
    return linhas
        .map((l) => OpcaoTransferencia.deJson(Map<String, dynamic>.from(l as Map)))
        .toList();
  }

  Future<void> transferir(String pedidoId, String centralDestinoId, String motivo) async {
    await _cliente.rpc('transferir_pedido', params: {
      'p_pedido_id': pedidoId,
      'p_central_destino_id': centralDestinoId,
      'p_motivo': motivo,
    });
  }
}
