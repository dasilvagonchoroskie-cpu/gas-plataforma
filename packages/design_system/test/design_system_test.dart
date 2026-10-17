import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nucleo/nucleo.dart';

void main() {
  group('Componentes visuais compartilhados', () {
    test('marca lê a cor do build e tem nomes padrão', () {
      expect(Marca.lerCor('#0B5C7A'), const Color(0xFF0B5C7A));
      expect(Marca.lerCor('0b5c7a'), const Color(0xFF0B5C7A));
      expect(Marca.lerCor('azul'), isNull);
      expect(Marca.lerCor(''), isNull);
      expect(Marca.corPrincipal, corPadraoPlataforma);
      expect(Marca.nome, 'Gás e Água');
      expect(Marca.nomeSuperCentral, 'Super Central');
    });

    test('cria tema Material 3 com botões grandes', () {
      final tema = criarTemaPlataforma();

      expect(tema.useMaterial3, isTrue);
      expect(tema.textTheme.bodyLarge?.fontSize, 18);
    });

    testWidgets('permite navegar entre seções do painel', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CascaPainel(
            titulo: 'Painel de teste',
            secoes: [
              SecaoPainel(
                rotulo: 'Visão geral',
                icone: Icons.home_outlined,
                conteudo: Text('Conteúdo inicial'),
              ),
              SecaoPainel(
                rotulo: 'Centrais',
                icone: Icons.store_outlined,
                conteudo: Text('Conteúdo das centrais'),
                contador: 3,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Conteúdo inicial'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.text('Centrais'));
      await tester.pumpAndSettle();
      expect(find.text('Conteúdo das centrais'), findsOneWidget);
    });

    testWidgets('mostra o status do pedido com o texto certo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SeloStatus(status: StatusPedido.emRota),
                SeloStatus(status: StatusPedido.emRota, paraCentral: true),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Saiu para entrega'), findsOneWidget);
      expect(find.text('Em rota'), findsOneWidget);
    });

    testWidgets('pede o motivo antes de confirmar', (tester) async {
      String? resposta;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resposta = await pedirTexto(
                  context,
                  titulo: 'Cancelar pedido',
                  rotulo: 'Motivo',
                  sugestoes: const ['Cliente desistiu'],
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      expect(find.text('Preencha este campo.'), findsOneWidget);

      await tester.tap(find.text('Cliente desistiu'));
      await tester.pump();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(resposta, 'Cliente desistiu');
    });

    testWidgets('extrato mostra pagamento diminuindo a dívida', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                LinhaLancamento(
                  lancamento: LancamentoCredito(
                    id: 'l1',
                    tipo: TipoLancamento.pagamento,
                    valor: const Dinheiro(-4000),
                    forma: FormaPagamento.dinheiro,
                    criadoEm: DateTime.utc(2026, 10, 16, 12),
                  ),
                ),
                LinhaLancamento(
                  lancamento: LancamentoCredito(
                    id: 'l2',
                    tipo: TipoLancamento.compra,
                    valor: const Dinheiro(11000),
                    criadoEm: DateTime.utc(2026, 10, 16, 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('− R\$ 40,00'), findsOneWidget);
      expect(find.text('+ R\$ 110,00'), findsOneWidget);
      expect(find.text('Pagamento'), findsOneWidget);
      expect(find.text('Compra no fiado'), findsOneWidget);
    });
  });
}
