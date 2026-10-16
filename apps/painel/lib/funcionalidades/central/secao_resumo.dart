import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';
import '../relatorios/cartoes_resumo.dart';

final _provedorResumoHoje = FutureProvider.autoDispose
    .family<({List<ResumoCentral> resumo, List<VendaProduto> produtos}), String>((ref, centralId) async {
  final gestao = ref.watch(provedorGestao);
  final hoje = Datas.hoje();
  final resultados = await Future.wait([
    gestao.resumoCentrais(hoje, hoje, centralId: centralId),
    gestao.vendasPorProduto(hoje, hoje, centralId: centralId),
  ]);
  return (
    resumo: resultados[0] as List<ResumoCentral>,
    produtos: resultados[1] as List<VendaProduto>,
  );
});

/// Resumo do dia da central: pedidos, entregues, cancelados e o que vendeu.
class SecaoResumo extends ConsumerWidget {
  const SecaoResumo({required this.centralId, super.key});

  final String centralId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dados = ref.watch(_provedorResumoHoje(centralId));
    return dados.when(
      loading: () => const Carregando(),
      error: (erro, _) => EstadoErro(
        mensagem: mensagemDeErro(erro),
        aoTentarNovamente: () => ref.invalidate(_provedorResumoHoje(centralId)),
      ),
      data: (d) => RefreshIndicator(
        onRefresh: () => ref.refresh(_provedorResumoHoje(centralId).future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LarguraMaxima(
              largura: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TituloSecao('Hoje, ${Datas.formatarData(Datas.hoje())}'),
                  if (d.resumo.isNotEmpty) CartoesResumo(resumo: d.resumo.first),
                  const TituloSecao('Vendido hoje (entregues)'),
                  if (d.produtos.isEmpty) const Text('Nenhuma entrega concluída hoje.'),
                  for (final p in d.produtos)
                    LinhaValor(
                      rotulo: '${p.quantidade}x ${p.produtoNome}',
                      valor: p.valor.formatarEmReais(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
