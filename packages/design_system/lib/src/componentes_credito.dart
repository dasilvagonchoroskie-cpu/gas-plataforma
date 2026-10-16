import 'package:flutter/material.dart';
import 'package:nucleo/nucleo.dart';

/// Uma linha do extrato: compra (aumenta a dívida) ou pagamento (diminui).
class LinhaLancamento extends StatelessWidget {
  const LinhaLancamento({required this.lancamento, super.key});

  final LancamentoCredito lancamento;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final pagou = lancamento.valor.centavos < 0;
    final valor =
        pagou ? Dinheiro(-lancamento.valor.centavos) : lancamento.valor;
    final detalhe = [
      Datas.formatarDataHora(lancamento.criadoEm),
      if (lancamento.forma != null) lancamento.forma!.rotulo,
      if (lancamento.observacao != null) lancamento.observacao!,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        pagou ? Icons.south_west : Icons.north_east,
        color: pagou ? const Color(0xFF15803D) : cores.error,
      ),
      title: Text(lancamento.tipo.rotulo),
      subtitle: Text(detalhe),
      trailing: Text(
        '${pagou ? '−' : '+'} ${valor.formatarEmReais()}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: pagou ? const Color(0xFF15803D) : cores.error,
        ),
      ),
    );
  }
}
