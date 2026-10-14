import 'package:flutter_test/flutter_test.dart';
import 'package:painel/main.dart';

void main() {
  testWidgets('apresenta o estado seguro enquanto o login está pendente', (
    tester,
  ) async {
    await tester.pumpWidget(const AplicativoPainel());

    expect(find.text('Painel unificado'), findsOneWidget);
    expect(find.textContaining('fases 2 e 3'), findsOneWidget);
  });
}
