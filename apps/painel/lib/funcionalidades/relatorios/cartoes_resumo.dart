import 'package:flutter/material.dart';
import 'package:nucleo/nucleo.dart';

/// Quatro números grandes: pedidos, em aberto, entregues e faturamento.
class CartoesResumo extends StatelessWidget {
  const CartoesResumo({required this.resumo, super.key});

  final ResumoCentral resumo;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        CartaoNumero(rotulo: 'Pedidos', valor: '${resumo.pedidos}', icone: Icons.receipt_long),
        CartaoNumero(rotulo: 'Em aberto', valor: '${resumo.emAberto}', icone: Icons.pending_actions),
        CartaoNumero(rotulo: 'Entregues', valor: '${resumo.entregues}', icone: Icons.done_all),
        CartaoNumero(rotulo: 'Cancelados', valor: '${resumo.cancelados}', icone: Icons.cancel_outlined),
        CartaoNumero(
          rotulo: 'Faturamento',
          valor: resumo.faturamento.formatarEmReais(),
          icone: Icons.payments_outlined,
          largo: true,
        ),
        CartaoNumero(
          rotulo: 'Ticket médio',
          valor: resumo.ticketMedio.formatarEmReais(),
          icone: Icons.trending_up,
        ),
      ],
    );
  }
}

class CartaoNumero extends StatelessWidget {
  const CartaoNumero({
    required this.rotulo,
    required this.valor,
    required this.icone,
    this.largo = false,
    super.key,
  });

  final String rotulo;
  final String valor;
  final IconData icone;
  final bool largo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SizedBox(
      width: largo ? 260 : 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icone, color: tema.colorScheme.primary),
              const SizedBox(height: 8),
              Text(valor, style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text(rotulo, style: tema.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
