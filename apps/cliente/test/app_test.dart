import 'package:cliente/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('abre o shell do app do cliente sem exibir dados fictícios', (
    tester,
  ) async {
    await tester.pumpWidget(const AplicativoCliente());

    expect(find.text('Pedidos de gás e água'), findsOneWidget);
    expect(find.text('Solicite gás e água'), findsOneWidget);
    expect(
      find.textContaining('serão conectados após a revisão'),
      findsOneWidget,
    );
  });

  testWidgets('permite navegar pelas áreas planejadas', (tester) async {
    await tester.pumpWidget(const AplicativoCliente());
    await tester.tap(find.text('Pedidos').last);
    await tester.pumpAndSettle();

    expect(find.text('Seus pedidos'), findsOneWidget);
  });
}
