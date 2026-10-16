/// Valor monetário expresso em centavos inteiros.
///
/// O aplicativo usa esta classe para representar e exibir valores sem ponto
/// flutuante. Totais, disponibilidade e preços finais continuam sendo
/// calculados e validados pelo servidor.
final class Dinheiro implements Comparable<Dinheiro> {
  const Dinheiro(this.centavos);

  static const zero = Dinheiro(0);

  final int centavos;

  /// Lê um valor digitado em reais, como "110", "110,5", "1.234,56" ou
  /// "R$ 12,90". Devolve nulo quando o texto não é um valor válido.
  static Dinheiro? lerReais(String texto) {
    final limpo = texto.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (limpo.isEmpty) {
      return null;
    }
    if (!RegExp(r'^\d{1,3}(\.\d{3})*(,\d{1,2})?$|^\d+(,\d{1,2})?$')
        .hasMatch(limpo)) {
      return null;
    }
    final partes = limpo.replaceAll('.', '').split(',');
    final reais = int.parse(partes[0]);
    var centavos = 0;
    if (partes.length > 1) {
      centavos = int.parse(partes[1].padRight(2, '0'));
    }
    return Dinheiro(reais * 100 + centavos);
  }

  Dinheiro operator +(Dinheiro outro) => Dinheiro(centavos + outro.centavos);

  Dinheiro operator -(Dinheiro outro) => Dinheiro(centavos - outro.centavos);

  Dinheiro operator *(int quantidade) => Dinheiro(centavos * quantidade);

  bool operator <(Dinheiro outro) => centavos < outro.centavos;

  bool operator <=(Dinheiro outro) => centavos <= outro.centavos;

  bool operator >(Dinheiro outro) => centavos > outro.centavos;

  bool operator >=(Dinheiro outro) => centavos >= outro.centavos;

  bool get ehZero => centavos == 0;

  /// Formata em reais brasileiros sem conversão para ponto flutuante.
  String formatarEmReais() {
    final valorAbsoluto = centavos.abs();
    final reais = valorAbsoluto ~/ 100;
    final fracao = (valorAbsoluto % 100).toString().padLeft(2, '0');
    final sinal = centavos < 0 ? '-' : '';

    return '${sinal}R\$ ${_separarMilhares(reais)},$fracao';
  }

  /// Valor para preencher um campo de edição, sem "R$" ("1.234,50").
  String formatarParaEdicao() {
    final valorAbsoluto = centavos.abs();
    final reais = valorAbsoluto ~/ 100;
    final fracao = (valorAbsoluto % 100).toString().padLeft(2, '0');
    return '${centavos < 0 ? '-' : ''}${_separarMilhares(reais)},$fracao';
  }

  @override
  int compareTo(Dinheiro other) => centavos.compareTo(other.centavos);

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
