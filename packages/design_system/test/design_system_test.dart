import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Componentes visuais compartilhados', () {
    test('cria tema Material 3', () {
      final tema = criarTemaPlataforma();

      expect(tema.useMaterial3, isTrue);
    });

    testWidgets('mostra quando uma área aguarda integração', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EstadoModuloEmPreparacao(titulo: 'Relatórios'),
        ),
      );

      expect(find.text('Relatórios'), findsOneWidget);
      expect(find.textContaining('será conectada após a aprovação'), findsOneWidget);
    });

    testWidgets('permite navegar entre seções do painel', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CascaPainel(
            titulo: 'Painel de teste',
            secoes: const [
              SecaoPainel(
                rotulo: 'Visão geral',
                icone: Icons.home_outlined,
                conteudo: Text('Conteúdo inicial'),
              ),
              SecaoPainel(
                rotulo: 'Centrais',
                icone: Icons.store_outlined,
                conteudo: Text('Conteúdo das centrais'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Conteúdo inicial'), findsOneWidget);
      await tester.tap(find.text('Centrais'));
      await tester.pumpAndSettle();
      expect(find.text('Conteúdo das centrais'), findsOneWidget);
    });
  });
}
