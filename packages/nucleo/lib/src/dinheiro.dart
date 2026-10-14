/// Valor monetário expresso em centavos inteiros.
///
/// O aplicativo usa esta classe para representar e exibir valores sem ponto
/// flutuante. Totais, disponibilidade e preços finais continuam sendo
/// calculados e validados pelo servidor.
final class Dinheiro {
  const Dinheiro(this.centavos);

  final int centavos;

  /// Formata em reais brasileiros sem conversão para ponto flutuante.
  String formatarEmReais() {
    final valorAbsoluto = centavos.abs();
    final reais = valorAbsoluto ~/ 100;
    final fracao = (valorAbsoluto % 100).toString().padLeft(2, '0');
    final sinal = centavos < 0 ? '-' : '';

    return '${sinal}R\$ ${_separarMilhares(reais)},$fracao';
  }

  @override
  bool operator ==(Object other) =>
      other is Dinheiro && other.centavos == centavos;

  @override
  int get hashCode => centavos.hashCode;

  @override
  String toString() => formatarEmReais();
}

String _separarMilhares(int valor) {
  final grupos = <String>[];
  var restante = valor;

  while (restante >= 1000) {
    grupos.insert(0, (restante % 1000).toString().padLeft(3, '0'));
    restante ~/= 1000;
  }

  grupos.insert(0, restante.toString());
  return grupos.join('.');
}
