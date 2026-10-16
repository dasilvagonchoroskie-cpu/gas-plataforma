import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';
import '../pedidos/fila_pedidos.dart';

final _provedorHoje = FutureProvider.autoDispose<List<ResumoCentral>>((ref) {
  final hoje = Datas.hoje();
  return ref.watch(provedorGestao).resumoCentrais(hoje, hoje);
});

/// Um cartão por central com os números de hoje. Tocar abre a fila daquela
/// central.
class SecaoVisaoGeral extends ConsumerWidget {
  const SecaoVisaoGeral({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumo = ref.watch(_provedorHoje);
    final tema = Theme.of(context);
    return resumo.when(
      loading: () => const Carregando(),
      error: (erro, _) => EstadoErro(
        mensagem: mensagemDeErro(erro),
        aoTentarNovamente: () => ref.invalidate(_provedorHoje),
      ),
      data: (centrais) {
        if (centrais.isEmpty) {
          return const EstadoVazio(
            icone: Icons.store_outlined,
            titulo: 'Nenhuma central ainda',
            mensagem: 'Crie a primeira central na seção "Centrais".',
          );
        }
        final totalPedidos = centrais.fold(0, (s, c) => s + c.pedidos);
        final totalAberto = centrais.fold(0, (s, c) => s + c.emAberto);
        final faturamento =
            centrais.fold(Dinheiro.zero, (s, c) => s + c.faturamento);
        return RefreshIndicator(
          onRefresh: () => ref.refresh(_provedorHoje.future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Hoje, ${Datas.formatarData(Datas.hoje())}',
                  style: tema.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '$totalPedidos pedidos · $totalAberto em aberto · '
                '${faturamento.formatarEmReais()} entregue',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final c in centrais)
                    SizedBox(
                      width: 320,
                      child: Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => Scaffold(
                                appBar: AppBar(
                                    title: Text('Pedidos · ${c.centralNome}')),
                                body: FilaPedidos(centralId: c.centralId),
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(c.centralNome,
                                          style: tema.textTheme.titleMedium),
                                    ),
                                    if (!c.ativa)
                                      const Chip(
                                        label: Text('Desativada'),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                                Text(c.cidade),
                                const Divider(),
                                LinhaValor(
                                    rotulo: 'Pedidos hoje',
                                    valor: '${c.pedidos}'),
                                LinhaValor(
                                    rotulo: 'Em aberto',
                                    valor: '${c.emAberto}'),
                                LinhaValor(
                                    rotulo: 'Entregues',
                                    valor: '${c.entregues}'),
                                LinhaValor(
                                  rotulo: 'Faturamento',
                                  valor: c.faturamento.formatarEmReais(),
                                  destaque: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
