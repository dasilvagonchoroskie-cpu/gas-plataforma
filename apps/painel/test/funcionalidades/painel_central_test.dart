import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:painel/funcionalidades/central/painel_central.dart';

void main() {
  testWidgets('abre o shell da central sem pedidos simulados', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PaginaPainelCentral()),
    );

    expect(find.text('Painel da central'), findsOneWidget);
    expect(find.text('Fila de pedidos'), findsOneWidget);
    expect(
      find.textContaining('validação de identidade e permissões'),
      findsOneWidget,
    );
  });

  testWidgets('navega pelos módulos previstos da central', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PaginaPainelCentral()),
    );
    await tester.tap(find.text('Estoque'));
    await tester.pumpAndSettle();

    expect(find.text('Estoque da central'), findsOneWidget);
  });
}
