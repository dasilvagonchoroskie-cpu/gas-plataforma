import 'package:dados/dados.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ponto achado só pela rua ou cidade precisa ser conferido no mapa', () {
    const exato = Localizacao(latitude: -18, longitude: -49);
    const rua = Localizacao(latitude: -18, longitude: -49, precisao: 'rua');
    const cidade =
        Localizacao(latitude: -18, longitude: -49, precisao: 'cidade');

    expect(exato.precisaConferir, isFalse);
    expect(exato.aproximada, isFalse);
    expect(rua.precisaConferir, isTrue);
    expect(rua.aproximada, isFalse);
    expect(cidade.precisaConferir, isTrue);
    expect(cidade.aproximada, isTrue);
  });
}
