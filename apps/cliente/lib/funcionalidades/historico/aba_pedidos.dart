import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

/// Meus pedidos: os em andamento primeiro, depois o histórico.
class AbaPedidos extends ConsumerWidget {
  const AbaPedidos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidos = ref.watch(provedorMeusPedidos);
    return Scaffold(
      appBar: AppBar(title: const Text('Meus pedidos')),
      body: pedidos.when(
        loading: () => const Carregando(),
        error: (erro, _) => EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () => ref.invalidate(provedorMeusPedidos),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(provedorMeusPedidos.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 60),
                  EstadoVazio(
                    icone: Icons.receipt_long_outlined,
                    titulo: 'Nenhum pedido ainda',
                    mensagem: 'Quando você fizer um pedido, ele aparece aqui.',
                  ),
                ],
              ),
            );
          }
          final ordenados = [
            ...lista.where((p) => p.status.emAndamento),
            ...lista.where((p) => p.status.ehFinal),
          ];
          return RefreshIndicator(
            onRefresh: () => ref.refresh(provedorMeusPedidos.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: ordenados.length,
              separatorBuilder: (context, indice) => const SizedBox(height: 12),
              itemBuilder: (context, indice) => _CartaoPedido(pedido: ordenados[indice]),
            ),
          );
        },
      ),
    );
  }
}

class _CartaoPedido extends StatelessWidget {
  const _CartaoPedido({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/pedido/${pedido.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Pedido nº ${pedido.numero}', style: tema.textTheme.titleMedium),
                  ),
                  SeloStatus(status: pedido.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(pedido.resumoItens),
              const SizedBox(height: 6),
              Text(
                '${Datas.formatarData(pedido.dataEntrega)} · '
                '${Datas.formatarIntervalo(pedido.horaInicio, pedido.horaFim)} · '
                '${pedido.total.formatarEmReais()}',
                style: tema.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
