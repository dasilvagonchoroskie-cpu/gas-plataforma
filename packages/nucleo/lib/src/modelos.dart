import 'datas.dart';
import 'dinheiro.dart';
import 'enumeracoes.dart';

typedef Json = Map<String, dynamic>;

int _inteiro(Object? valor, [int padrao = 0]) {
  if (valor is int) {
    return valor;
  }
  if (valor is num) {
    return valor.toInt();
  }
  if (valor is String) {
    return int.tryParse(valor) ?? num.tryParse(valor)?.toInt() ?? padrao;
  }
  return padrao;
}

double _decimal(Object? valor, [double padrao = 0]) {
  if (valor is num) {
    return valor.toDouble();
  }
  if (valor is String) {
    return double.tryParse(valor) ?? padrao;
  }
  return padrao;
}

String _texto(Object? valor, [String padrao = '']) =>
    valor == null ? padrao : valor.toString();

String? _textoOuNulo(Object? valor) {
  final texto = valor?.toString().trim();
  return texto == null || texto.isEmpty ? null : texto;
}

bool _logico(Object? valor, [bool padrao = false]) =>
    valor is bool ? valor : padrao;

/// Pega o primeiro objeto de um relacionamento (o Supabase pode devolver
/// objeto ou lista, conforme a relação).
Json? _objeto(Object? valor) {
  if (valor is Map<String, dynamic>) {
    return valor;
  }
  if (valor is List && valor.isNotEmpty && valor.first is Map) {
    return Map<String, dynamic>.from(valor.first as Map);
  }
  return null;
}

List<Json> _lista(Object? valor) {
  if (valor is List) {
    return [
      for (final item in valor)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  return const [];
}

// ---------------------------------------------------------------------------
// Pessoas
// ---------------------------------------------------------------------------

final class Perfil {
  const Perfil({
    required this.id,
    required this.nome,
    required this.telefone,
    required this.papel,
    required this.ativo,
    this.email,
    this.centralId,
    this.criadoEm,
  });

  factory Perfil.deJson(Json json, {String? centralId}) => Perfil(
        id: _texto(json['id']),
        nome: _texto(json['nome']),
        telefone: _texto(json['telefone']),
        email: _textoOuNulo(json['email']),
        papel: PapelPerfil.deValor(_texto(json['papel'], 'cliente')),
        ativo: _logico(json['ativo'], true),
        centralId: centralId ??
            _textoOuNulo(_objeto(json['operadores_central'])?['central_id']),
        criadoEm: Datas.lerInstante(json['criado_em']),
      );

  final String id;
  final String nome;
  final String telefone;
  final String? email;
  final PapelPerfil papel;
  final bool ativo;

  /// Central do operador (nulo para os outros papéis).
  final String? centralId;
  final DateTime? criadoEm;

  String get primeiroNome => nome.trim().split(RegExp(r'\s+')).first;
}

// ---------------------------------------------------------------------------
// Centrais
// ---------------------------------------------------------------------------

final class FaixaEntrega {
  const FaixaEntrega({
    required this.ateKm,
    required this.taxa,
    this.id,
    this.centralId,
  });

  factory FaixaEntrega.deJson(Json json) => FaixaEntrega(
        id: _textoOuNulo(json['id']),
        centralId: _textoOuNulo(json['central_id']),
        ateKm: _decimal(json['ate_km']),
        taxa: Dinheiro(_inteiro(json['taxa_entrega_centavos'])),
      );

  final String? id;
  final String? centralId;
  final double ateKm;
  final Dinheiro taxa;
}

final class Central {
  const Central({
    required this.id,
    required this.nome,
    required this.cidade,
    required this.uf,
    required this.endereco,
    required this.latitude,
    required this.longitude,
    required this.ativa,
    this.whatsapp,
  });

  factory Central.deJson(Json json) => Central(
        id: _texto(json['id']),
        nome: _texto(json['nome']),
        cidade: _texto(json['cidade']),
        uf: _texto(json['uf']),
        endereco: _texto(json['endereco']),
        latitude: _decimal(json['latitude']),
        longitude: _decimal(json['longitude']),
        whatsapp: _textoOuNulo(json['whatsapp']),
        ativa: _logico(json['ativa']),
      );

  final String id;
  final String nome;
  final String cidade;
  final String uf;
  final String endereco;
  final double latitude;
  final double longitude;
  final String? whatsapp;
  final bool ativa;

  String get cidadeUf => '$cidade - $uf';
}

/// Qual central atende um endereço, com a taxa de entrega.
final class Atendimento {
  const Atendimento({
    required this.centralId,
    required this.centralNome,
    required this.cidade,
    required this.uf,
    required this.distanciaKm,
    required this.taxaEntrega,
    this.whatsapp,
  });

  factory Atendimento.deJson(Json json) => Atendimento(
        centralId: _texto(json['central_id']),
        centralNome: _texto(json['central_nome']),
        cidade: _texto(json['cidade']),
        uf: _texto(json['uf']),
        whatsapp: _textoOuNulo(json['whatsapp']),
        distanciaKm: _decimal(json['distancia_km']),
        taxaEntrega: Dinheiro(_inteiro(json['taxa_entrega_centavos'])),
      );

  final String centralId;
  final String centralNome;
  final String cidade;
  final String uf;
  final String? whatsapp;
  final double distanciaKm;
  final Dinheiro taxaEntrega;
}

// ---------------------------------------------------------------------------
// Catálogo
// ---------------------------------------------------------------------------

final class Produto {
  const Produto({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.trocaVasilhame,
    required this.ativo,
    this.descricao,
    this.fotoUrl,
    this.ordem = 0,
  });

  factory Produto.deJson(Json json) => Produto(
        id: _texto(json['id']),
        nome: _texto(json['nome']),
        categoria: CategoriaProduto.deValor(_texto(json['categoria'], 'gas')),
        descricao: _textoOuNulo(json['descricao']),
        fotoUrl: _textoOuNulo(json['foto_url']),
        trocaVasilhame: _logico(json['troca_vasilhame']),
        ordem: _inteiro(json['ordem']),
        ativo: _logico(json['ativo'], true),
      );

  final String id;
  final String nome;
  final CategoriaProduto categoria;
  final String? descricao;
  final String? fotoUrl;
  final bool trocaVasilhame;
  final int ordem;
  final bool ativo;
}

/// Produto com o preço de uma central.
final class ItemCatalogo {
  const ItemCatalogo({
    required this.produto,
    required this.preco,
    required this.disponivel,
    required this.centralId,
  });

  /// Linha de `precos_central` com o produto aninhado (`produtos(*)`).
  factory ItemCatalogo.deJson(Json json) => ItemCatalogo(
        centralId: _texto(json['central_id']),
        produto: Produto.deJson(_objeto(json['produtos']) ?? const {}),
        preco: Dinheiro(_inteiro(json['preco_centavos'])),
        disponivel: _logico(json['disponivel'], true),
      );

  final Produto produto;
  final Dinheiro preco;
  final bool disponivel;
  final String centralId;
}

// ---------------------------------------------------------------------------
// Agenda
// ---------------------------------------------------------------------------

final class HorarioDisponivel {
  const HorarioDisponivel({
    required this.data,
    required this.janelaId,
    required this.horaInicio,
    required this.horaFim,
    required this.vagas,
  });

  factory HorarioDisponivel.deJson(Json json) => HorarioDisponivel(
        data: Datas.lerData(json['data']) ?? Datas.hoje(),
        janelaId: _texto(json['janela_id']),
        horaInicio: _texto(json['hora_inicio']),
        horaFim: _texto(json['hora_fim']),
        vagas: _inteiro(json['vagas']),
      );

  final DateTime data;
  final String janelaId;
  final String horaInicio;
  final String horaFim;
  final int vagas;

  String get intervalo => Datas.formatarIntervalo(horaInicio, horaFim);
}

final class JanelaEntrega {
  const JanelaEntrega({
    required this.id,
    required this.centralId,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFim,
    required this.capacidade,
    required this.ativa,
  });

  factory JanelaEntrega.deJson(Json json) => JanelaEntrega(
        id: _texto(json['id']),
        centralId: _texto(json['central_id']),
        diaSemana: _inteiro(json['dia_semana']),
        horaInicio: _texto(json['hora_inicio']),
        horaFim: _texto(json['hora_fim']),
        capacidade: _inteiro(json['capacidade']),
        ativa: _logico(json['ativa'], true),
      );

  final String id;
  final String centralId;
  final int diaSemana;
  final String horaInicio;
  final String horaFim;
  final int capacidade;
  final bool ativa;

  String get intervalo => Datas.formatarIntervalo(horaInicio, horaFim);
}

final class BloqueioAgenda {
  const BloqueioAgenda({
    required this.id,
    required this.data,
    required this.motivo,
    this.janelaId,
  });

  factory BloqueioAgenda.deJson(Json json) => BloqueioAgenda(
        id: _texto(json['id']),
        data: Datas.lerData(json['data']) ?? Datas.hoje(),
        janelaId: _textoOuNulo(json['janela_id']),
        motivo: _texto(json['motivo']),
      );

  final String id;
  final DateTime data;
  final String? janelaId;
  final String motivo;
}

// ---------------------------------------------------------------------------
// Endereços
// ---------------------------------------------------------------------------

final class Endereco {
  const Endereco({
    required this.apelido,
    required this.cep,
    required this.logradouro,
    required this.numero,
    required this.bairro,
    required this.cidade,
    required this.uf,
    required this.latitude,
    required this.longitude,
    this.id,
    this.complemento,
    this.referencia,
  });

  factory Endereco.deJson(Json json) => Endereco(
        id: _textoOuNulo(json['id']),
        apelido: _texto(json['apelido']),
        cep: _texto(json['cep']),
        logradouro: _texto(json['logradouro']),
        numero: _texto(json['numero']),
        bairro: _texto(json['bairro']),
        cidade: _texto(json['cidade']),
        uf: _texto(json['uf']),
        complemento: _textoOuNulo(json['complemento']),
        referencia: _textoOuNulo(json['referencia']),
        latitude: _decimal(json['latitude']),
        longitude: _decimal(json['longitude']),
      );

  final String? id;
  final String apelido;
  final String cep;
  final String logradouro;
  final String numero;
  final String bairro;
  final String cidade;
  final String uf;
  final String? complemento;
  final String? referencia;
  final double latitude;
  final double longitude;

  /// "Rua Um, 10 - Centro".
  String get linhaPrincipal {
    final complementoTexto = complemento == null ? '' : ', $complemento';
    return '$logradouro, $numero$complementoTexto - $bairro';
  }

  Json paraBanco(String clienteId) => {
        'cliente_id': clienteId,
        'apelido': apelido.trim(),
        'cep': cep,
        'logradouro': logradouro.trim(),
        'numero': numero.trim(),
        'bairro': bairro.trim(),
        'cidade': cidade.trim(),
        'uf': uf.trim().toUpperCase(),
        'complemento': complemento,
        'referencia': referencia,
        'latitude': latitude,
        'longitude': longitude,
      };
}

// ---------------------------------------------------------------------------
// Pedidos
// ---------------------------------------------------------------------------

final class ItemPedido {
  const ItemPedido({
    required this.produtoId,
    required this.produtoNome,
    required this.quantidade,
    required this.precoUnitario,
    required this.trocaVasilhame,
  });

  factory ItemPedido.deJson(Json json) => ItemPedido(
        produtoId: _texto(json['produto_id']),
        produtoNome: _texto(json['produto_nome']),
        quantidade: _inteiro(json['quantidade'], 1),
        precoUnitario: Dinheiro(_inteiro(json['preco_unitario_centavos'])),
        trocaVasilhame: _logico(json['troca_vasilhame']),
      );

  final String produtoId;
  final String produtoNome;
  final int quantidade;
  final Dinheiro precoUnitario;
  final bool trocaVasilhame;

  Dinheiro get total => precoUnitario * quantidade;
}

final class EventoPedido {
  const EventoPedido({
    required this.status,
    required this.evento,
    required this.criadoEm,
    this.observacao,
  });

  factory EventoPedido.deJson(Json json) => EventoPedido(
        status: StatusPedido.deValor(_texto(json['status'], 'novo')),
        evento: _texto(json['evento'], 'status'),
        observacao: _textoOuNulo(json['observacao']),
        criadoEm: Datas.lerInstante(json['criado_em']) ?? Datas.hoje(),
      );

  final StatusPedido status;

  /// "status", "transferencia" ou "entregador".
  final String evento;
  final String? observacao;
  final DateTime criadoEm;

  String get descricao {
    if (evento == 'transferencia') {
      return 'Pedido encaminhado para outra central';
    }
    if (evento == 'entregador') {
      return observacao ?? 'Entregador definido';
    }
    return status.rotuloCliente;
  }
}

final class Pedido {
  const Pedido({
    required this.id,
    required this.numero,
    required this.clienteId,
    required this.centralId,
    required this.clienteNome,
    required this.clienteTelefone,
    required this.logradouro,
    required this.numeroEndereco,
    required this.bairro,
    required this.cidade,
    required this.uf,
    required this.cep,
    required this.latitude,
    required this.longitude,
    required this.distanciaKm,
    required this.dataEntrega,
    required this.horaInicio,
    required this.horaFim,
    required this.status,
    required this.formaPagamento,
    required this.trocoPara,
    required this.subtotal,
    required this.taxaEntrega,
    required this.total,
    required this.transferencias,
    required this.criadoEm,
    this.enderecoApelido,
    this.complemento,
    this.referencia,
    this.janelaId,
    this.observacao,
    this.entregadorId,
    this.motivoCancelamento,
    this.centralNome,
    this.centralWhatsapp,
    this.entregadorNome,
    this.itens = const [],
    this.eventos = const [],
  });

  factory Pedido.deJson(Json json) {
    final central = _objeto(json['centrais']);
    final entregador = _objeto(json['entregadores']);
    final eventos = _lista(json['historico_status'])
        .map(EventoPedido.deJson)
        .toList()
      ..sort((a, b) => a.criadoEm.compareTo(b.criadoEm));
    return Pedido(
      id: _texto(json['id']),
      numero: _inteiro(json['numero']),
      clienteId: _texto(json['cliente_id']),
      centralId: _texto(json['central_id']),
      centralNome: _textoOuNulo(central?['nome']),
      centralWhatsapp: _textoOuNulo(central?['whatsapp']),
      clienteNome: _texto(json['cliente_nome']),
      clienteTelefone: _texto(json['cliente_telefone']),
      enderecoApelido: _textoOuNulo(json['endereco_apelido']),
      logradouro: _texto(json['logradouro_entrega']),
      numeroEndereco: _texto(json['numero_entrega']),
      bairro: _texto(json['bairro_entrega']),
      cidade: _texto(json['cidade_entrega']),
      uf: _texto(json['uf_entrega']),
      cep: _texto(json['cep_entrega']),
      complemento: _textoOuNulo(json['complemento_entrega']),
      referencia: _textoOuNulo(json['referencia_entrega']),
      latitude: _decimal(json['latitude_entrega']),
      longitude: _decimal(json['longitude_entrega']),
      distanciaKm: _decimal(json['distancia_km']),
      dataEntrega: Datas.lerData(json['data_entrega']) ?? Datas.hoje(),
      janelaId: _textoOuNulo(json['janela_id']),
      horaInicio: _texto(json['hora_inicio']),
      horaFim: _texto(json['hora_fim']),
      status: StatusPedido.deValor(_texto(json['status'], 'novo')),
      formaPagamento:
          FormaPagamento.deValor(_texto(json['forma_pagamento'], 'dinheiro')),
      trocoPara: Dinheiro(_inteiro(json['troco_para_centavos'])),
      observacao: _textoOuNulo(json['observacao']),
      subtotal: Dinheiro(_inteiro(json['subtotal_centavos'])),
      taxaEntrega: Dinheiro(_inteiro(json['taxa_entrega_centavos'])),
      total: Dinheiro(_inteiro(json['total_centavos'])),
      entregadorId: _textoOuNulo(json['entregador_id']),
      entregadorNome: _textoOuNulo(entregador?['nome']),
      motivoCancelamento: _textoOuNulo(json['motivo_cancelamento']),
      transferencias: _inteiro(json['transferencias']),
      criadoEm: Datas.lerInstante(json['criado_em']) ?? Datas.hoje(),
      itens: _lista(json['itens_pedido']).map(ItemPedido.deJson).toList(),
      eventos: eventos,
    );
  }

  final String id;
  final int numero;
  final String clienteId;
  final String centralId;
  final String? centralNome;
  final String? centralWhatsapp;
  final String clienteNome;
  final String clienteTelefone;
  final String? enderecoApelido;
  final String logradouro;
  final String numeroEndereco;
  final String bairro;
  final String cidade;
  final String uf;
  final String cep;
  final String? complemento;
  final String? referencia;
  final double latitude;
  final double longitude;
  final double distanciaKm;
  final DateTime dataEntrega;
  final String? janelaId;
  final String horaInicio;
  final String horaFim;
  final StatusPedido status;
  final FormaPagamento formaPagamento;
  final Dinheiro trocoPara;
  final String? observacao;
  final Dinheiro subtotal;
  final Dinheiro taxaEntrega;
  final Dinheiro total;
  final String? entregadorId;
  final String? entregadorNome;
  final String? motivoCancelamento;
  final int transferencias;
  final DateTime criadoEm;
  final List<ItemPedido> itens;
  final List<EventoPedido> eventos;

  String get enderecoCompleto {
    final complementoTexto = complemento == null ? '' : ', $complemento';
    return '$logradouro, $numeroEndereco$complementoTexto - $bairro, $cidade/$uf';
  }

  String get horario =>
      '${Datas.rotuloDia(dataEntrega)}, ${Datas.formatarIntervalo(horaInicio, horaFim)}';

  String get resumoItens =>
      itens.map((i) => '${i.quantidade}x ${i.produtoNome}').join(', ');

  /// Troco que o entregador precisa levar (só em dinheiro).
  Dinheiro get trocoALevar =>
      formaPagamento == FormaPagamento.dinheiro && trocoPara.centavos > 0
          ? trocoPara - total
          : Dinheiro.zero;
}

/// Uma central para onde o pedido pode ser transferido.
final class OpcaoTransferencia {
  const OpcaoTransferencia({
    required this.centralId,
    required this.centralNome,
    required this.cidade,
    required this.uf,
    required this.distanciaKm,
    required this.produtosDisponiveis,
    required this.estoqueSuficiente,
  });

  factory OpcaoTransferencia.deJson(Json json) => OpcaoTransferencia(
        centralId: _texto(json['central_id']),
        centralNome: _texto(json['central_nome']),
        cidade: _texto(json['cidade']),
        uf: _texto(json['uf']),
        distanciaKm: _decimal(json['distancia_km']),
        produtosDisponiveis: _logico(json['produtos_disponiveis']),
        estoqueSuficiente: _logico(json['estoque_suficiente']),
      );

  final String centralId;
  final String centralNome;
  final String cidade;
  final String uf;
  final double distanciaKm;
  final bool produtosDisponiveis;
  final bool estoqueSuficiente;
}

// ---------------------------------------------------------------------------
// Operação da central
// ---------------------------------------------------------------------------

final class Entregador {
  const Entregador({
    required this.id,
    required this.centralId,
    required this.nome,
    required this.telefone,
    required this.ativo,
  });

  factory Entregador.deJson(Json json) => Entregador(
        id: _texto(json['id']),
        centralId: _texto(json['central_id']),
        nome: _texto(json['nome']),
        telefone: _texto(json['telefone']),
        ativo: _logico(json['ativo'], true),
      );

  final String id;
  final String centralId;
  final String nome;
  final String telefone;
  final bool ativo;
}

final class ItemEstoque {
  const ItemEstoque({
    required this.centralId,
    required this.produtoId,
    required this.produtoNome,
    required this.cheios,
    required this.vazios,
    required this.alertaMinimo,
    required this.trocaVasilhame,
  });

  factory ItemEstoque.deJson(Json json) {
    final produto = _objeto(json['produtos']) ?? const {};
    return ItemEstoque(
      centralId: _texto(json['central_id']),
      produtoId: _texto(json['produto_id']),
      produtoNome: _texto(produto['nome']),
      trocaVasilhame: _logico(produto['troca_vasilhame']),
      cheios: _inteiro(json['cheios']),
      vazios: _inteiro(json['vazios']),
      alertaMinimo: _inteiro(json['alerta_minimo']),
    );
  }

  final String centralId;
  final String produtoId;
  final String produtoNome;
  final int cheios;
  final int vazios;
  final int alertaMinimo;
  final bool trocaVasilhame;

  bool get abaixoDoMinimo => cheios <= alertaMinimo;
  bool get negativo => cheios < 0 || vazios < 0;
}

final class MovimentoEstoque {
  const MovimentoEstoque({
    required this.tipo,
    required this.produtoNome,
    required this.deltaCheios,
    required this.deltaVazios,
    required this.cheiosApos,
    required this.vaziosApos,
    required this.motivo,
    required this.criadoEm,
  });

  factory MovimentoEstoque.deJson(Json json) => MovimentoEstoque(
        tipo: TipoMovimentoEstoque.deValor(_texto(json['tipo'], 'ajuste')),
        produtoNome: _texto(_objeto(json['produtos'])?['nome']),
        deltaCheios: _inteiro(json['delta_cheios']),
        deltaVazios: _inteiro(json['delta_vazios']),
        cheiosApos: _inteiro(json['cheios_apos']),
        vaziosApos: _inteiro(json['vazios_apos']),
        motivo: _texto(json['motivo']),
        criadoEm: Datas.lerInstante(json['criado_em']) ?? Datas.hoje(),
      );

  final TipoMovimentoEstoque tipo;
  final String produtoNome;
  final int deltaCheios;
  final int deltaVazios;
  final int cheiosApos;
  final int vaziosApos;
  final String motivo;
  final DateTime criadoEm;
}

// ---------------------------------------------------------------------------
// Relatórios e auditoria
// ---------------------------------------------------------------------------

final class ResumoCentral {
  const ResumoCentral({
    required this.centralId,
    required this.centralNome,
    required this.cidade,
    required this.ativa,
    required this.pedidos,
    required this.entregues,
    required this.cancelados,
    required this.emAberto,
    required this.faturamento,
    required this.ticketMedio,
  });

  factory ResumoCentral.deJson(Json json) => ResumoCentral(
        centralId: _texto(json['central_id']),
        centralNome: _texto(json['central_nome']),
        cidade: _texto(json['cidade']),
        ativa: _logico(json['ativa']),
        pedidos: _inteiro(json['pedidos']),
        entregues: _inteiro(json['entregues']),
        cancelados: _inteiro(json['cancelados']),
        emAberto: _inteiro(json['em_aberto']),
        faturamento: Dinheiro(_inteiro(json['faturamento_centavos'])),
        ticketMedio: Dinheiro(_inteiro(json['ticket_medio_centavos'])),
      );

  final String centralId;
  final String centralNome;
  final String cidade;
  final bool ativa;
  final int pedidos;
  final int entregues;
  final int cancelados;
  final int emAberto;
  final Dinheiro faturamento;
  final Dinheiro ticketMedio;
}

final class VendaProduto {
  const VendaProduto({
    required this.produtoNome,
    required this.quantidade,
    required this.valor,
  });

  factory VendaProduto.deJson(Json json) => VendaProduto(
        produtoNome: _texto(json['produto_nome']),
        quantidade: _inteiro(json['quantidade']),
        valor: Dinheiro(_inteiro(json['valor_centavos'])),
      );

  final String produtoNome;
  final int quantidade;
  final Dinheiro valor;
}

final class VendaDia {
  const VendaDia({
    required this.dia,
    required this.pedidos,
    required this.entregues,
    required this.cancelados,
    required this.faturamento,
  });

  factory VendaDia.deJson(Json json) => VendaDia(
        dia: Datas.lerData(json['dia']) ?? Datas.hoje(),
        pedidos: _inteiro(json['pedidos']),
        entregues: _inteiro(json['entregues']),
        cancelados: _inteiro(json['cancelados']),
        faturamento: Dinheiro(_inteiro(json['faturamento_centavos'])),
      );

  final DateTime dia;
  final int pedidos;
  final int entregues;
  final int cancelados;
  final Dinheiro faturamento;
}

final class RegistroAuditoria {
  const RegistroAuditoria({
    required this.id,
    required this.acao,
    required this.tabela,
    required this.criadoEm,
    this.registroId,
    this.quem,
    this.antes,
    this.depois,
  });

  factory RegistroAuditoria.deJson(Json json) => RegistroAuditoria(
        id: _inteiro(json['id']),
        acao: _texto(json['acao']),
        tabela: _texto(json['tabela']),
        registroId: _textoOuNulo(json['registro_id']),
        quem: _textoOuNulo(_objeto(json['perfis'])?['nome']),
        antes: json['antes'] is Map
            ? Map<String, dynamic>.from(json['antes'] as Map)
            : null,
        depois: json['depois'] is Map
            ? Map<String, dynamic>.from(json['depois'] as Map)
            : null,
        criadoEm: Datas.lerInstante(json['criado_em']) ?? Datas.hoje(),
      );

  final int id;
  final String acao;
  final String tabela;
  final String? registroId;
  final String? quem;
  final Json? antes;
  final Json? depois;
  final DateTime criadoEm;

  /// Campos que mudaram numa alteração.
  List<String> get camposAlterados {
    final a = antes;
    final d = depois;
    if (a == null || d == null) {
      return const [];
    }
    return [
      for (final chave in d.keys)
        if ('${a[chave]}' != '${d[chave]}') chave,
    ];
  }
}
