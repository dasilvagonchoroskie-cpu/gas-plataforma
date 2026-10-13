import 'package:flutter_test/flutter_test.dart';
import 'package:painel_proprietario/main.dart';

void main() {
  testWidgets('abre o shell responsivo do proprietário sem dados fictícios', (
    tester,
  ) async {
    await tester.pumpWidget(const PainelProprietarioApp());

    expect(find.text('Painel do proprietário'), findsOneWidget);
    expect(find.text('Visão geral da empresa'), findsOneWidget);
    expect(
      find.textContaining('dados reais só serão exibidos'),
      findsOneWidget,
    );
  });

  testWidgets('navega para as áreas de gestão planejadas', (tester) async {
    await tester.pumpWidget(const PainelProprietarioApp());
    await tester.tap(find.text('Centrais'));
    await tester.pumpAndSettle();

    expect(find.text('Centrais da empresa'), findsOneWidget);
  });
}
