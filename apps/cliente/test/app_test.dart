import 'package:cliente/app.dart';
import 'package:cliente/estado/provedores.dart';
import 'package:cliente/funcionalidades/autenticacao/tela_entrar.dart';
import 'package:cliente/funcionalidades/catalogo/cartao_produto.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nucleo/nucleo.dart';

const _gas = ItemCatalogo(
  centralId: 'c1',
  preco: Dinheiro(11000),
  disponivel: true,
  produto: Produto(
    id: 'gas',
    nome: 'Gás P13 (13 kg)',
    categoria: CategoriaProduto.gas,
    trocaVasilhame: true,
    ativo: true,
  ),
);

Widget _comTema(Widget filho) => ProviderScope(
      child: MaterialApp(theme: criarTemaPlataforma(), home: Scaffold(body: filho)),
    );

void main() {
  testWidgets('sem configuração do servidor, avisa em vez de quebrar', (tester) async {
    await tester.pumpWidget(const AplicativoSemConfiguracao());

    expect(find.text('Aplicativo sem configuração'), findsOneWidget);
  });

  testWidgets('login pede e-mail e senha antes de enviar', (tester) async {
    await tester.pumpWidget(_comTema(const TelaEntrar()));

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(find.text('Digite sua senha.'), findsOneWidget);
    expect(find.text('Criar minha conta'), findsOneWidget);
  });

  testWidgets('cartão do produto mostra preço e soma no carrinho', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: criarTemaPlataforma(),
          home: const Scaffold(body: CartaoProduto(item: _gas)),
        ),
      ),
    );

    expect(find.text('R\$ 110,00'), findsOneWidget);
    expect(find.text('Tenha o vasilhame vazio para trocar'), findsOneWidget);

    await tester.tap(find.text('Adicionar'));
    await tester.pump();
    expect(container.read(provedorCarrinho).quantidadeDe('gas'), 1);

    await tester.tap(find.byTooltip('Pôr mais um'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
    expect(container.read(provedorCarrinho).subtotal, const Dinheiro(22000));
  });
}
