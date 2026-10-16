import 'dart:typed_data';

import 'package:nucleo/nucleo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'erros.dart';

/// Ficha de cadastro e crediário (fiado). Usado pelo app do cliente e pelos
/// painéis. Quem pode ver ou alterar cada coisa é decidido pelo banco.
class RepositorioCredito {
  RepositorioCredito(this._cliente);

  final SupabaseClient _cliente;

  static const _bucket = 'fichas';

  String get _usuarioId {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) {
      throw const ErroDeNegocio('Entre de novo para continuar.');
    }
    return id;
  }

  // -------------------------------------------------------------------------
  // Cliente
  // -------------------------------------------------------------------------

  /// A ficha do cliente logado (nulo se ainda não enviou).
  Future<FichaCliente?> minhaFicha() async {
    final dados = await _cliente
        .from('fichas_cliente')
        .select()
        .eq('cliente_id', _usuarioId)
        .maybeSingle();
    return dados == null ? null : FichaCliente.deJson(dados);
  }

  /// Envia a foto (documento ou comprovante) para a pasta privada do cliente e
  /// devolve o caminho guardado na ficha.
  Future<String> enviarFoto(Uint8List bytes, String tipoArquivo, {required String nome}) async {
    final extensao = switch (tipoArquivo) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final caminho = '$_usuarioId/$nome-${gerarIdentificadorUnico()}.$extensao';
    await _cliente.storage.from(_bucket).uploadBinary(
          caminho,
          bytes,
          fileOptions: FileOptions(contentType: tipoArquivo, upsert: false),
        );
    return caminho;
  }

  Future<void> enviarFicha(DadosFicha dados) async {
    await _cliente.rpc('enviar_ficha', params: {'p_ficha': dados.paraBanco()});
  }

  // -------------------------------------------------------------------------
  // Consultas (cliente e painéis)
  // -------------------------------------------------------------------------

  /// Resumo do crediário. Sem [clienteId]: o do cliente logado.
  Future<ResumoCredito> resumo([String? clienteId]) async {
    final dados = await _cliente.rpc('resumo_credito', params: {'p_cliente_id': clienteId});
    return ResumoCredito.deJson(Map<String, dynamic>.from(dados as Map));
  }

  Future<List<LancamentoCredito>> extrato(String clienteId, {int limite = 200}) async {
    final linhas = await _cliente
        .from('lancamentos_credito')
        .select()
        .eq('cliente_id', clienteId)
        .order('criado_em', ascending: false)
        .limit(limite);
    return linhas.map(LancamentoCredito.deJson).toList();
  }

  /// Link temporário (1 hora) para ver uma foto da ficha.
  Future<String> linkDaFoto(String caminho) =>
      _cliente.storage.from(_bucket).createSignedUrl(caminho, 3600);

  // -------------------------------------------------------------------------
  // Painéis (dono e centrais)
  // -------------------------------------------------------------------------

  Future<List<ItemFicha>> fichas({StatusFicha? status, String busca = ''}) async {
    final linhas = await _cliente.rpc('listar_fichas', params: {
      'p_status': status?.valor,
      'p_busca': busca.trim().isEmpty ? null : busca.trim(),
    }) as List<dynamic>;
    return linhas.map((l) => ItemFicha.deJson(Map<String, dynamic>.from(l as Map))).toList();
  }

  Future<FichaCliente> fichaCompleta(String clienteId) async {
    final dados = await _cliente.rpc('ficha_completa', params: {'p_cliente_id': clienteId});
    return FichaCliente.deJson(Map<String, dynamic>.from(dados as Map));
  }

  Future<void> aprovar(String clienteId, Dinheiro limite) async {
    await _cliente.rpc('analisar_ficha', params: {
      'p_cliente_id': clienteId,
      'p_status': StatusFicha.aprovada.valor,
      'p_limite_centavos': limite.centavos,
    });
  }

  Future<void> recusar(String clienteId, String motivo) async {
    await _cliente.rpc('analisar_ficha', params: {
      'p_cliente_id': clienteId,
      'p_status': StatusFicha.recusada.valor,
      'p_limite_centavos': 0,
      'p_motivo': motivo.trim(),
    });
  }

  Future<void> definirBloqueio(String clienteId, {required bool bloqueado, String? motivo}) async {
    await _cliente.rpc('definir_bloqueio_credito', params: {
      'p_cliente_id': clienteId,
      'p_bloqueado': bloqueado,
      'p_motivo': motivo?.trim(),
    });
  }

  /// Quem deve. O dono pode filtrar por central; a central vê só os dela.
  Future<List<Devedor>> devedores({String? centralId}) async {
    final linhas = await _cliente.rpc('devedores', params: {'p_central_id': centralId}) as List<dynamic>;
    return linhas.map((l) => Devedor.deJson(Map<String, dynamic>.from(l as Map))).toList();
  }

  Future<ResumoCredito> registrarPagamento({
    required String clienteId,
    required Dinheiro valor,
    required FormaPagamento forma,
    String? observacao,
  }) async {
    final dados = await _cliente.rpc('registrar_pagamento_credito', params: {
      'p_cliente_id': clienteId,
      'p_valor_centavos': valor.centavos,
      'p_forma': forma.valor,
      'p_observacao': (observacao ?? '').trim().isEmpty ? null : observacao!.trim(),
    });
    return ResumoCredito.deJson(Map<String, dynamic>.from(dados as Map));
  }

  /// Ajuste manual (só o dono). Valor positivo aumenta a dívida.
  Future<ResumoCredito> ajustar({
    required String clienteId,
    required Dinheiro valor,
    required String motivo,
  }) async {
    final dados = await _cliente.rpc('ajustar_credito', params: {
      'p_cliente_id': clienteId,
      'p_valor_centavos': valor.centavos,
      'p_motivo': motivo.trim(),
    });
    return ResumoCredito.deJson(Map<String, dynamic>.from(dados as Map));
  }

  Future<Configuracoes> configuracoes() async {
    final dados = await _cliente.from('configuracoes').select().maybeSingle();
    return dados == null
        ? const Configuracoes(centraisAprovamCredito: false)
        : Configuracoes.deJson(dados);
  }

  Future<void> salvarConfiguracoes(Configuracoes configuracoes) async {
    await _cliente.from('configuracoes').update({
      'centrais_aprovam_credito': configuracoes.centraisAprovamCredito,
      'limite_maximo_central_centavos': configuracoes.limiteMaximoCentral?.centavos,
    }).eq('id', true);
  }
}
