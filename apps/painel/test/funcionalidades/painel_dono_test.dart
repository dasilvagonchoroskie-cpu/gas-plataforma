import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:painel/funcionalidades/dono/painel_dono.dart';

void main() {
  testWidgets('abre o shell do dono sem dados fictícios', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PaginaPainelDono()),
    );

    expect(find.text('Painel do dono'), findsOneWidget);
    expect(find.text('Visão geral da empresa'), findsOneWidget);
    expect(
      find.textContaining('dados reais só serão exibidos'),
      findsOneWidget,
    );
  });

  testWidgets('navega pelas áreas planejadas para o dono', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PaginaPainelDono()),
    );
    await tester.tap(find.text('Centrais'));
    await tester.pumpAndSettle();

    expect(find.text('Centrais da empresa'), findsOneWidget);
  });
}
