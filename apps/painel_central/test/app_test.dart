import 'package:flutter_test/flutter_test.dart';
import 'package:painel_central/main.dart';

void main() {
  testWidgets('abre o shell da central sem pedidos simulados', (
    tester,
  ) async {
    await tester.pumpWidget(const PainelCentralApp());

    expect(find.text('Painel da central'), findsOneWidget);
    expect(find.text('Fila de pedidos'), findsOneWidget);
    expect(
      find.textContaining('validação de identidade e permissões'),
      findsOneWidget,
    );
  });

  testWidgets('navega para os módulos operacionais', (tester) async {
    await tester.pumpWidget(const PainelCentralApp());
    await tester.tap(find.text('Estoque'));
    await tester.pumpAndSettle();

    expect(find.text('Estoque da central'), findsOneWidget);
  });
}
