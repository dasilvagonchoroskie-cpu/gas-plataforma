import 'package:flutter_test/flutter_test.dart';
import 'package:nucleo/nucleo.dart';

void main() {
  group('Dinheiro', () {
    test('formata zero e centavos sem ponto flutuante', () {
      expect(const Dinheiro(0).formatarEmReais(), 'R\$ 0,00');
      expect(const Dinheiro(5).formatarEmReais(), 'R\$ 0,05');
      expect(const Dinheiro(12345).formatarEmReais(), 'R\$ 123,45');
    });

    test('separa milhares e preserva os centavos', () {
      expect(
        const Dinheiro(123456789).formatarEmReais(),
        'R\$ 1.234.567,89',
      );
    });

    test('formata valores negativos com sinal explícito', () {
      expect(const Dinheiro(-5).formatarEmReais(), '-R\$ 0,05');
      expect(const Dinheiro(-12345).toString(), '-R\$ 123,45');
    });

    test('usa igualdade por valor', () {
      expect(const Dinheiro(2500), const Dinheiro(2500));
      expect(const Dinheiro(2500), isNot(const Dinheiro(2501)));
      expect(const Dinheiro(2500).hashCode, const Dinheiro(2500).hashCode);
    });
  });
}
