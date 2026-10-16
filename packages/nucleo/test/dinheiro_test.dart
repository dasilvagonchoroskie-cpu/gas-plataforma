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

    test('soma, subtrai e multiplica em centavos', () {
      expect(const Dinheiro(1050) + const Dinheiro(50), const Dinheiro(1100));
      expect(const Dinheiro(1050) - const Dinheiro(50), const Dinheiro(1000));
      expect(const Dinheiro(1050) * 3, const Dinheiro(3150));
    });

    test('lê valores digitados em reais', () {
      expect(Dinheiro.lerReais('110'), const Dinheiro(11000));
      expect(Dinheiro.lerReais('110,5'), const Dinheiro(11050));
      expect(Dinheiro.lerReais('1.234,56'), const Dinheiro(123456));
      expect(Dinheiro.lerReais('R\$ 12,90'), const Dinheiro(1290));
      expect(Dinheiro.lerReais('0,05'), const Dinheiro(5));
    });

    test('recusa valores inválidos', () {
      expect(Dinheiro.lerReais(''), isNull);
      expect(Dinheiro.lerReais('abc'), isNull);
      expect(Dinheiro.lerReais('12,345'), isNull);
      expect(Dinheiro.lerReais('-5'), isNull);
    });

    test('prepara valor para edição', () {
      expect(const Dinheiro(123456).formatarParaEdicao(), '1.234,56');
    });
  });
}
