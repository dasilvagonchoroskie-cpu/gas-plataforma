import 'dart:typed_data';

import 'package:nucleo/nucleo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'erros.dart';

/// Cadastros e operação dos painéis: centrais, produtos, preços, horários,
/// estoque, entregadores, usuários, relatórios e auditoria.
///
/// As permissões não dependem desta classe: o banco recusa o que o papel do
/// usuário não pode fazer.
class RepositorioGestao {
  RepositorioGestao(this._cliente);

  final SupabaseClient _cliente;

  // -------------------------------------------------------------------------
  // Centrais e faixas de entrega
  // -------------------------------------------------------------------------

  Future<List<Central>> centrais() async {
    final linhas = await _cliente.from('centrais').select().order('nome');
    return linhas.map(Central.deJson).toList();
  }

  Future<Central?> central(String id) async {
    final dados = await _cliente.from('centrais').select().eq('id', id).maybeSingle();
    return dados == null ? null : Central.deJson(dados);
  }

  Future<String> criarCentral({
    required String nome,
    required String cidade,
    required String uf,
    required String endereco,
    required double latitude,
    required double longitude,
    String? whatsapp,
    bool ativa = false,
    String? centralModeloId,
  }) async {
    final id = await _cliente.rpc('criar_central', params: {
      'p_nome': nome.trim(),
      'p_cidade': cidade.trim(),
      'p_uf': uf.trim().toUpperCase(),
      'p_endereco': endereco.trim(),
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_whatsapp': (whatsapp ?? '').trim().isEmpty ? null : whatsapp,
      'p_ativa': ativa,
      'p_central_modelo_id': centralModeloId,
    });
    return id as String;
  }

  Future<void> atualizarCentral(Central central) async {
    await _cliente.from('centrais').update({
      'nome': central.nome.trim(),
      'cidade': central.cidade.trim(),
      'uf': central.uf.trim().toUpperCase(),
      'endereco': central.endereco.trim(),
      'latitude': central.latitude,
      'longitude': central.longitude,
      'whatsapp': (central.whatsapp ?? '').trim().isEmpty ? null : central.whatsapp,
      'ativa': central.ativa,
    }).eq('id', central.id);
  }

  Future<List<FaixaEntrega>> faixas(String centralId) async {
    final linhas = await _cliente
        .from('faixas_entrega')
        .select()
        .eq('central_id', centralId)
        .order('ate_km');
    return linhas.map(FaixaEntrega.deJson).toList();
  }

  /// Troca todas as faixas da central pelas informadas.
  Future<void> salvarFaixas(String centralId, List<FaixaEntrega> faixas) async {
    if (faixas.isEmpty) {
      throw const ErroDeNegocio('A central precisa de pelo menos uma faixa de entrega.');
    }
    final distancias = faixas.map((f) => f.ateKm).toSet();
    if (distancias.length != faixas.length) {
      throw const ErroDeNegocio('Há duas faixas com a mesma distância.');
    }
    await _cliente.from('faixas_entrega').delete().eq('central_id', centralId);
    await _cliente.from('faixas_entrega').insert([
      for (final f in faixas)
        {
          'central_id': centralId,
          'ate_km': f.ateKm,
          'taxa_entrega_centavos': f.taxa.centavos,
        },
    ]);
  }

  // -------------------------------------------------------------------------
  // Produtos e preços
  // -------------------------------------------------------------------------

  Future<List<Produto>> produtos() async {
    final linhas = await _cliente.from('produtos').select().order('ordem').order('nome');
    return linhas.map(Produto.deJson).toList();
  }

  Future<void> salvarProduto({
    required String nome,
    required CategoriaProduto categoria,
    required bool trocaVasilhame,
    required bool ativo,
    String? id,
    String? descricao,
    String? fotoUrl,
    int ordem = 0,
  }) async {
    final dados = {
      'nome': nome.trim(),
      'categoria': categoria.valor,
      'descricao': (descricao ?? '').trim().isEmpty ? null : descricao!.trim(),
      'foto_url': fotoUrl,
      'troca_vasilhame': trocaVasilhame,
      'ordem': ordem,
      'ativo': ativo,
    };
    if (id == null) {
      await _cliente.from('produtos').insert(dados);
    } else {
      await _cliente.from('produtos').update(dados).eq('id', id);
    }
  }

  /// Envia a foto do produto e devolve o endereço público.
  Future<String> enviarFotoProduto(Uint8List bytes, String tipo) async {
    final extensao = switch (tipo) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final caminho = 'catalogo/${gerarIdentificadorUnico()}.$extensao';
    await _cliente.storage.from('produtos').uploadBinary(
          caminho,
          bytes,
          fileOptions: FileOptions(contentType: tipo, upsert: false),
        );
    return _cliente.storage.from('produtos').getPublicUrl(caminho);
  }

  /// Preços de uma central (todos os produtos, inclusive indisponíveis).
  Future<List<ItemCatalogo>> precos(String centralId) async {
    final linhas = await _cliente
        .from('precos_central')
        .select('central_id, produto_id, preco_centavos, disponivel, produtos(*)')
        .eq('central_id', centralId);
    return linhas.map(ItemCatalogo.deJson).toList()
      ..sort((a, b) => a.produto.ordem.compareTo(b.produto.ordem));
  }

  Future<void> salvarPreco({
    required String centralId,
    required String produtoId,
    required Dinheiro preco,
    required bool disponivel,
  }) async {
    await _cliente.from('precos_central').upsert({
      'central_id': centralId,
      'produto_id': produtoId,
      'preco_centavos': preco.centavos,
      'disponivel': disponivel,
    }, onConflict: 'central_id,produto_id');
  }

  /// A central só liga/desliga a disponibilidade (o valor é do dono).
  Future<void> definirDisponivel(String centralId, String produtoId, bool disponivel) async {
    await _cliente
        .from('precos_central')
        .update({'disponivel': disponivel})
        .eq('central_id', centralId)
        .eq('produto_id', produtoId);
  }

  Future<void> removerPreco(String centralId, String produtoId) async {
    await _cliente
        .from('precos_central')
        .delete()
        .eq('central_id', centralId)
        .eq('produto_id', produtoId);
  }

  // -------------------------------------------------------------------------
  // Horários e bloqueios
  // -------------------------------------------------------------------------

  Future<List<JanelaEntrega>> janelas(String centralId) async {
    final linhas = await _cliente
        .from('janelas_entrega')
        .select()
        .eq('central_id', centralId)
        .order('dia_semana')
        .order('hora_inicio');
    return linhas.map(JanelaEntrega.deJson).toList();
  }

  Future<void> criarJanela({
    required String centralId,
    required List<int> diasSemana,
    required String horaInicio,
    required String horaFim,
    required int capacidade,
  }) async {
    if (diasSemana.isEmpty) {
      throw const ErroDeNegocio('Escolha pelo menos um dia da semana.');
    }
    await _cliente.from('janelas_entrega').insert([
      for (final dia in diasSemana)
        {
          'central_id': centralId,
          'dia_semana': dia,
          'hora_inicio': horaInicio,
          'hora_fim': horaFim,
          'capacidade': capacidade,
        },
    ]);
  }

  Future<void> atualizarJanela(String id, {int? capacidade, bool? ativa}) async {
    await _cliente.from('janelas_entrega').update({
      if (capacidade != null) 'capacidade': capacidade,
      if (ativa != null) 'ativa': ativa,
    }).eq('id', id);
  }

  Future<List<BloqueioAgenda>> bloqueios(String centralId) async {
    final linhas = await _cliente
        .from('bloqueios_agenda')
        .select()
        .eq('central_id', centralId)
        .gte('data', Datas.paraBanco(Datas.hoje()))
        .order('data');
    return linhas.map(BloqueioAgenda.deJson).toList();
  }

  Future<void> bloquear({
    required String centralId,
    required DateTime data,
    required String motivo,
    String? janelaId,
  }) async {
    await _cliente.from('bloqueios_agenda').insert({
      'central_id': centralId,
      'data': Datas.paraBanco(data),
      'janela_id': janelaId,
      'motivo': motivo.trim(),
    });
  }

  Future<void> desbloquear(String id) async {
    await _cliente.from('bloqueios_agenda').delete().eq('id', id);
  }

  // -------------------------------------------------------------------------
  // Estoque
  // -------------------------------------------------------------------------

  Future<List<ItemEstoque>> estoque(String centralId) async {
    final linhas = await _cliente
        .from('estoque_central')
        .select('*, produtos(nome, troca_vasilhame, ordem)')
        .eq('central_id', centralId);
    return linhas.map(ItemEstoque.deJson).toList()
      ..sort((a, b) => a.produtoNome.compareTo(b.produtoNome));
  }

  Future<void> movimentarEstoque({
    required String centralId,
    required String produtoId,
    required TipoMovimentoEstoque tipo,
    required int cheios,
    required int vazios,
    required String motivo,
  }) async {
    await _cliente.rpc('movimentar_estoque', params: {
      'p_central_id': centralId,
      'p_produto_id': produtoId,
      'p_tipo': tipo.valor,
      'p_cheios': cheios,
      'p_vazios': vazios,
      'p_motivo': motivo.trim(),
    });
  }

  Future<void> definirAlertaMinimo(String centralId, String produtoId, int minimo) async {
    await _cliente
        .from('estoque_central')
        .update({'alerta_minimo': minimo})
        .eq('central_id', centralId)
        .eq('produto_id', produtoId);
  }

  Future<List<MovimentoEstoque>> movimentos(String centralId, {int limite = 100}) async {
    final linhas = await _cliente
        .from('movimentos_estoque')
        .select('*, produtos(nome)')
        .eq('central_id', centralId)
        .order('criado_em', ascending: false)
        .limit(limite);
    return linhas.map(MovimentoEstoque.deJson).toList();
  }

  // -------------------------------------------------------------------------
  // Entregadores
  // -------------------------------------------------------------------------

  Future<List<Entregador>> entregadores(String centralId, {bool somenteAtivos = false}) async {
    var consulta = _cliente.from('entregadores').select().eq('central_id', centralId);
    if (somenteAtivos) {
      consulta = consulta.eq('ativo', true);
    }
    final linhas = await consulta.order('nome');
    return linhas.map(Entregador.deJson).toList();
  }

  Future<void> salvarEntregador({
    required String centralId,
    required String nome,
    required String telefone,
    required bool ativo,
    String? id,
  }) async {
    final dados = {
      'nome': nome.trim(),
      'telefone': Validacoes.somenteDigitos(telefone),
      'ativo': ativo,
    };
    if (id == null) {
      await _cliente.from('entregadores').insert({...dados, 'central_id': centralId});
    } else {
      await _cliente.from('entregadores').update(dados).eq('id', id);
    }
  }

  // -------------------------------------------------------------------------
  // Usuários (somente o dono; a função do servidor confere)
  // -------------------------------------------------------------------------

  Future<List<Perfil>> usuarios({PapelPerfil? papel, String busca = ''}) async {
    var consulta = _cliente
        .from('perfis')
        .select('*, operadores_central(central_id)')
        .isFilter('excluido_em', null);
    if (papel != null) {
      consulta = consulta.eq('papel', papel.valor);
    }
    final termo = busca.trim().replaceAll(RegExp(r'[,()%*]'), ' ').trim();
    if (termo.isNotEmpty) {
      consulta = consulta.or('nome.ilike.%$termo%,email.ilike.%$termo%,telefone.ilike.%$termo%');
    }
    final linhas = await consulta.order('nome').limit(300);
    return linhas.map((l) => Perfil.deJson(l)).toList();
  }

  Future<void> _adminUsuarios(Map<String, dynamic> corpo) async {
    await _cliente.functions.invoke('admin-usuarios', body: corpo);
  }

  Future<void> criarUsuario({
    required String nome,
    required String email,
    required String telefone,
    required String senha,
    required PapelPerfil papel,
    String? centralId,
  }) =>
      _adminUsuarios({
        'acao': 'criar',
        'nome': nome.trim(),
        'email': email.trim().toLowerCase(),
        'telefone': Validacoes.somenteDigitos(telefone),
        'senha': senha,
        'papel': papel.valor,
        'central_id': centralId,
      });

  Future<void> mudarPapel(String usuarioId, PapelPerfil papel, {String? centralId}) =>
      _adminUsuarios({
        'acao': 'mudar_papel',
        'usuario_id': usuarioId,
        'papel': papel.valor,
        'central_id': centralId,
      });

  Future<void> definirAtivo(String usuarioId, bool ativo) =>
      _adminUsuarios({'acao': 'definir_ativo', 'usuario_id': usuarioId, 'ativo': ativo});

  Future<void> redefinirSenha(String usuarioId, String senha) =>
      _adminUsuarios({'acao': 'redefinir_senha', 'usuario_id': usuarioId, 'senha': senha});

  // -------------------------------------------------------------------------
  // Relatórios e auditoria
  // -------------------------------------------------------------------------

  Map<String, dynamic> _periodo(DateTime inicio, DateTime fim, String? centralId) => {
        'p_inicio': Datas.paraBanco(inicio),
        'p_fim': Datas.paraBanco(fim),
        'p_central_id': centralId,
      };

  Future<List<ResumoCentral>> resumoCentrais(DateTime inicio, DateTime fim, {String? centralId}) async {
    final linhas = await _cliente.rpc('resumo_centrais', params: _periodo(inicio, fim, centralId))
        as List<dynamic>;
    return linhas.map((l) => ResumoCentral.deJson(Map<String, dynamic>.from(l as Map))).toList();
  }

  Future<List<VendaProduto>> vendasPorProduto(DateTime inicio, DateTime fim, {String? centralId}) async {
    final linhas = await _cliente.rpc('relatorio_produtos', params: _periodo(inicio, fim, centralId))
        as List<dynamic>;
    return linhas.map((l) => VendaProduto.deJson(Map<String, dynamic>.from(l as Map))).toList();
  }

  Future<List<VendaDia>> vendasPorDia(DateTime inicio, DateTime fim, {String? centralId}) async {
    final linhas = await _cliente.rpc('relatorio_por_dia', params: _periodo(inicio, fim, centralId))
        as List<dynamic>;
    return linhas.map((l) => VendaDia.deJson(Map<String, dynamic>.from(l as Map))).toList();
  }

  Future<List<RegistroAuditoria>> auditoria({String? tabela, int limite = 200}) async {
    var consulta = _cliente.from('auditoria').select('*, perfis(nome)');
    if (tabela != null) {
      consulta = consulta.eq('tabela', tabela);
    }
    final linhas = await consulta.order('id', ascending: false).limit(limite);
    return linhas.map(RegistroAuditoria.deJson).toList();
  }
}
