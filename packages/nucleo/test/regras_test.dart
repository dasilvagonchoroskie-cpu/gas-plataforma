import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nucleo/nucleo.dart';

ItemCatalogo _item(String id, int preco, {String central = 'c1'}) =>
    ItemCatalogo(
      centralId: central,
      preco: Dinheiro(preco),
      disponivel: true,
      produto: Produto(
        id: id,
        nome: 'Produto $id',
        categoria: CategoriaProduto.gas,
        trocaVasilhame: true,
        ativo: true,
      ),
    );

void main() {
  group('Carrinho', () {
    final gas = _item('gas', 11000);
    final agua = _item('agua', 1500);

    test('soma quantidades e calcula subtotal para exibição', () {
      final carrinho = const Carrinho.vazio()
          .adicionar(gas)
          .adicionar(gas)
          .adicionar(agua, 3);
      expect(carrinho.quantidadeTotal, 5);
      expect(carrinho.subtotal, const Dinheiro(26500));
      expect(carrinho.quantidadeDe('gas'), 2);
      expect(carrinho.centralId, 'c1');
    });

    test('remove o item quando a quantidade chega a zero', () {
      final carrinho =
          const Carrinho.vazio().adicionar(gas).remover(gas).remover(gas);
      expect(carrinho.vazio, isTrue);
      expect(carrinho.centralId, isNull);
    });

    test('limita a quantidade máxima por produto', () {
      final carrinho = const Carrinho.vazio().definir(gas, 999);
      expect(carrinho.quantidadeDe('gas'), Carrinho.quantidadeMaxima);
    });

    test('produto de outra central recomeça o carrinho', () {
      final outraCentral = _item('gas', 12000, central: 'c2');
      final carrinho =
          const Carrinho.vazio().adicionar(agua).adicionar(outraCentral);
      expect(carrinho.quantidadeTotal, 1);
      expect(carrinho.centralId, 'c2');
    });

    test('manda só produto e quantidade para o pedido', () {
      final itens = const Carrinho.vazio().adicionar(gas, 2).paraPedido();
      expect(itens, [
        {'produto_id': 'gas', 'quantidade': 2},
      ]);
    });

    test('repetir pedido usa preços atuais e ignora o que saiu do catálogo',
        () {
      final carrinho = Carrinho.aPartirDe(
        {'gas': 2, 'sumiu': 1},
        [_item('gas', 11500), agua],
      );
      expect(carrinho.quantidadeTotal, 2);
      expect(carrinho.subtotal, const Dinheiro(23000));
    });
  });

  group('Status do pedido', () {
    test('segue a ordem novo, confirmado, em rota, entregue', () {
      expect(StatusPedido.novo.proximoPassoCentral, StatusPedido.confirmado);
      expect(StatusPedido.confirmado.proximoPassoCentral, StatusPedido.emRota);
      expect(StatusPedido.emRota.proximoPassoCentral, StatusPedido.entregue);
      expect(StatusPedido.entregue.proximoPassoCentral, isNull);
      expect(StatusPedido.cancelado.proximoPassoCentral, isNull);
    });

    test('cliente só cancela pedido novo', () {
      expect(StatusPedido.novo.clientePodeCancelar, isTrue);
      expect(StatusPedido.confirmado.clientePodeCancelar, isFalse);
    });

    test('transferência só antes de sair para entrega', () {
      expect(StatusPedido.novo.podeTransferir, isTrue);
      expect(StatusPedido.confirmado.podeTransferir, isTrue);
      expect(StatusPedido.emRota.podeTransferir, isFalse);
    });

    test('converte os valores do banco', () {
      expect(StatusPedido.deValor('em_rota'), StatusPedido.emRota);
      expect(FormaPagamento.deValor('pix_na_entrega'),
          FormaPagamento.pixNaEntrega);
      expect(
          PapelPerfil.deValor('operador_central'), PapelPerfil.operadorCentral);
      expect(() => StatusPedido.deValor('x'), throwsFormatException);
    });
  });

  group('Validações', () {
    test('celular com DDD', () {
      expect(Validacoes.celular('(64) 99999-0000'), isNull);
      expect(Validacoes.celular('9999-0000'), isNotNull);
    });

    test('e-mail, senha e CEP', () {
      expect(Validacoes.email('a@b.com'), isNull);
      expect(Validacoes.email('a@b'), isNotNull);
      expect(Validacoes.senha('1234567'), isNotNull);
      expect(Validacoes.senha('12345678'), isNull);
      expect(Validacoes.cep('75600-000'), isNull);
      expect(Validacoes.cep('7560'), isNotNull);
    });

    test('formata telefone, CEP e WhatsApp', () {
      expect(Validacoes.formatarTelefone('64999990000'), '(64) 99999-0000');
      expect(Validacoes.formatarTelefone('6430000000'), '(64) 3000-0000');
      expect(Validacoes.formatarCep('75600000'), '75600-000');
      expect(
          Validacoes.whatsappInternacional('(64) 99999-0000'), '5564999990000');
      expect(
          Validacoes.whatsappInternacional('5564999990000'), '5564999990000');
    });

    test('gera identificador único no formato UUID v4', () {
      final id = gerarIdentificadorUnico(Random(1));
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(id),
        isTrue,
      );
      expect(gerarIdentificadorUnico(), isNot(gerarIdentificadorUnico()));
    });
  });

  group('Datas', () {
    test('converte UTC para o horário de Brasília', () {
      final local = Datas.paraLocal(DateTime.utc(2026, 10, 16, 2, 30));
      expect(Datas.formatarDataHora(local), '15/10/2026 às 23:30');
    });

    test('formata horários de entrega', () {
      expect(Datas.formatarHora('08:00:00'), '8h');
      expect(Datas.formatarHora('13:30:00'), '13h30');
      expect(Datas.formatarIntervalo('08:00:00', '12:00:00'), '8h às 12h');
    });

    test('rotula hoje, amanhã e outros dias', () {
      final agora = DateTime.utc(2026, 10, 16, 15);
      expect(Datas.rotuloDia(DateTime.utc(2026, 10, 16), agora: agora), 'Hoje');
      expect(
          Datas.rotuloDia(DateTime.utc(2026, 10, 17), agora: agora), 'Amanhã');
      expect(Datas.rotuloDia(DateTime.utc(2026, 10, 19), agora: agora),
          'Seg 19/10');
    });

    test('dia da semana igual ao banco (0 = domingo)', () {
      expect(Datas.diaDaSemana(DateTime.utc(2026, 10, 18)), 0);
      expect(Datas.diaDaSemana(DateTime.utc(2026, 10, 17)), 6);
    });

    test('lê e escreve datas do banco', () {
      final data = Datas.lerData('2026-10-16')!;
      expect(Datas.paraBanco(data), '2026-10-16');
    });
  });

  group('Modelos', () {
    test('lê um pedido completo vindo do banco', () {
      final pedido = Pedido.deJson({
        'id': 'p1',
        'numero': 1001,
        'cliente_id': 'u1',
        'central_id': 'c1',
        'centrais': {'nome': 'Central Goiatuba'},
        'cliente_nome': 'Maria',
        'cliente_telefone': '64999990000',
        'logradouro_entrega': 'Rua Um',
        'numero_entrega': '10',
        'bairro_entrega': 'Centro',
        'cidade_entrega': 'Goiatuba',
        'uf_entrega': 'GO',
        'cep_entrega': '75600000',
        'latitude_entrega': -18.01,
        'longitude_entrega': -49.36,
        'distancia_km': 1.25,
        'data_entrega': '2026-10-17',
        'hora_inicio': '08:00:00',
        'hora_fim': '12:00:00',
        'status': 'em_rota',
        'forma_pagamento': 'dinheiro',
        'troco_para_centavos': 15000,
        'subtotal_centavos': 11000,
        'taxa_entrega_centavos': 0,
        'total_centavos': 11000,
        'transferencias': 0,
        'criado_em': '2026-10-16T15:00:00+00:00',
        'itens_pedido': [
          {
            'produto_id': 'g',
            'produto_nome': 'Gás P13',
            'quantidade': 1,
            'preco_unitario_centavos': 11000,
            'troca_vasilhame': true,
          },
        ],
        'historico_status': [
          {
            'status': 'confirmado',
            'evento': 'status',
            'criado_em': '2026-10-16T15:05:00Z'
          },
          {
            'status': 'novo',
            'evento': 'status',
            'criado_em': '2026-10-16T15:00:00Z'
          },
        ],
      });
      expect(pedido.status, StatusPedido.emRota);
      expect(pedido.centralNome, 'Central Goiatuba');
      expect(pedido.resumoItens, '1x Gás P13');
      expect(pedido.trocoALevar, const Dinheiro(4000));
      expect(pedido.eventos.first.status, StatusPedido.novo);
      expect(pedido.enderecoCompleto, 'Rua Um, 10 - Centro, Goiatuba/GO');
    });

    test('lê o atendimento da central mais próxima', () {
      final atendimento = Atendimento.deJson({
        'central_id': 'c1',
        'central_nome': 'Central Goiatuba',
        'cidade': 'Goiatuba',
        'uf': 'GO',
        'whatsapp': null,
        'distancia_km': 2.4,
        'taxa_entrega_centavos': 500,
      });
      expect(atendimento.taxaEntrega, const Dinheiro(500));
      expect(atendimento.whatsapp, isNull);
    });

    test('auditoria mostra os campos alterados', () {
      final registro = RegistroAuditoria.deJson({
        'id': 1,
        'acao': 'update',
        'tabela': 'precos_central',
        'antes': {'preco_centavos': 100, 'disponivel': true},
        'depois': {'preco_centavos': 200, 'disponivel': true},
        'criado_em': '2026-10-16T15:00:00Z',
      });
      expect(registro.camposAlterados, ['preco_centavos']);
    });
  });
}
