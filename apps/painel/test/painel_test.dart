import 'dart:math';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nucleo/nucleo.dart';
import 'package:painel/app.dart';
import 'package:painel/funcionalidades/autenticacao/tela_login.dart';
import 'package:painel/funcionalidades/dono/secao_auditoria.dart';
import 'package:painel/funcionalidades/dono/secao_relatorios.dart';
import 'package:painel/funcionalidades/dono/secao_usuarios.dart';
import 'package:painel/tipo_painel.dart';

ResumoCentral _resumo(String nome,
        {int pedidos = 0, int entregues = 0, int faturamento = 0}) =>
    ResumoCentral(
      centralId: nome,
      centralNome: nome,
      cidade: 'Goiatuba',
      ativa: true,
      pedidos: pedidos,
      entregues: entregues,
      cancelados: 1,
      emAberto: 2,
      faturamento: Dinheiro(faturamento),
      ticketMedio: Dinheiro.zero,
    );

Perfil _perfil(PapelPerfil papel, {bool ativo = true, String? centralId}) =>
    Perfil(
      id: 'p1',
      nome: 'Pessoa Teste',
      telefone: '64999990000',
      papel: papel,
      ativo: ativo,
      centralId: centralId,
    );

void main() {
  test('cada aplicativo do painel aceita só o seu tipo de conta', () {
    const superCentral = TipoPainel.superCentral;
    const central = TipoPainel.central;
    final dono = _perfil(PapelPerfil.dono);
    final loja = _perfil(PapelPerfil.operadorCentral, centralId: 'c1');

    expect(superCentral.motivoSemAcesso(dono), isNull);
    expect(superCentral.motivoSemAcesso(loja), contains('aplicativo Central'));
    expect(central.motivoSemAcesso(loja), isNull);
    expect(central.motivoSemAcesso(dono), contains('Super Central'));

    expect(central.motivoSemAcesso(_perfil(PapelPerfil.operadorCentral)),
        contains('não está ligada a uma loja'));
    for (final tipo in TipoPainel.values) {
      expect(tipo.motivoSemAcesso(_perfil(PapelPerfil.cliente)),
          contains('cliente'));
      expect(tipo.motivoSemAcesso(_perfil(PapelPerfil.entregador)), isNotNull);
      expect(
          tipo.motivoSemAcesso(_perfil(PapelPerfil.dono, ativo: false)),
          contains('desativada'));
      expect(
          tipo.motivoSemAcesso(_perfil(PapelPerfil.operadorCentral,
              ativo: false, centralId: 'c1')),
          contains('desativada'));
    }
  });

  test('tipo do painel vem do build; sem nada, vale o Central', () {
    expect(TipoPainel.deValor('supercentral'), TipoPainel.superCentral);
    expect(TipoPainel.deValor(' SuperCentral '), TipoPainel.superCentral);
    expect(TipoPainel.deValor('central'), TipoPainel.central);
    expect(TipoPainel.deValor(null), TipoPainel.central);
    expect(TipoPainel.deValor('qualquer'), TipoPainel.central);
    expect(TipoPainel.doBuild, TipoPainel.central);
  });

  testWidgets('tela de entrada mostra o nome do aplicativo', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          provedorTipoPainel.overrideWithValue(TipoPainel.superCentral),
        ],
        child:
            MaterialApp(theme: criarTemaPlataforma(), home: const TelaLogin()),
      ),
    );

    expect(find.text('Super Central'), findsOneWidget);
    expect(find.text('Acesso do dono: todas as lojas'), findsOneWidget);
  });

  testWidgets('sem configuração do servidor, avisa em vez de quebrar',
      (tester) async {
    await tester.pumpWidget(const PainelSemConfiguracao());

    expect(find.text('Painel sem configuração'), findsOneWidget);
  });

  testWidgets('login do painel pede e-mail e senha antes de enviar',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child:
            MaterialApp(theme: criarTemaPlataforma(), home: const TelaLogin()),
      ),
    );

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(find.text('Digite sua senha.'), findsOneWidget);
  });

  test('senha provisória tem 10 caracteres sem letras ou números confusos', () {
    final gerador = Random(42);
    for (var i = 0; i < 200; i++) {
      final senha = gerarSenhaTemporaria(gerador);
      expect(senha.length, 10);
      expect(senha, isNot(matches(RegExp('[01OIl]'))));
      expect(Validacoes.senha(senha), isNull);
    }
  });

  test('resumo total soma as centrais e calcula o ticket médio', () {
    final total = somarResumos([
      _resumo('A', pedidos: 3, entregues: 2, faturamento: 30000),
      _resumo('B', pedidos: 5, entregues: 4, faturamento: 60000),
    ]);

    expect(total.pedidos, 8);
    expect(total.entregues, 6);
    expect(total.cancelados, 2);
    expect(total.emAberto, 4);
    expect(total.faturamento, const Dinheiro(90000));
    expect(total.ticketMedio, const Dinheiro(15000));
    expect(somarResumos(const []).ticketMedio, Dinheiro.zero);
  });

  test('planilha não deixa nome virar fórmula nem quebrar colunas', () {
    final csv = relatorioEmCsv(
      (
        centrais: [
          _resumo('=SOMA(A1);x', pedidos: 1, entregues: 1, faturamento: 11000)
        ],
        produtos: const [
          VendaProduto(
              produtoNome: 'Gás P13', quantidade: 1, valor: Dinheiro(11000))
        ],
        dias: const [],
      ),
      '16/10/2026',
    );

    expect(csv, contains("'=SOMA(A1) x;Goiatuba;1;1;1;2;110,00;0,00"));
    expect(csv, contains('Gás P13;1;110,00'));
  });

  test('auditoria mostra valores em português', () {
    expect(descreverValorAuditoria('preco_centavos', 11000), 'R\$ 110,00');
    expect(descreverValorAuditoria('ativa', false), 'não');
    expect(descreverValorAuditoria('dia_semana', 1), 'segunda-feira');
    expect(descreverValorAuditoria('papel', 'dono'), 'Administrador (dono)');
    expect(descreverValorAuditoria('nome', null), '(vazio)');
  });
}
