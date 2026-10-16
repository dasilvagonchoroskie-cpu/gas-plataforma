import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

final _provedorPrecos = FutureProvider.autoDispose.family<List<ItemCatalogo>, String>(
  (ref, centralId) => ref.watch(provedorGestao).precos(centralId),
);

/// A central liga e desliga a venda de cada produto (por exemplo, quando
/// acaba). O preço é definido pelo dono.
class SecaoDisponibilidade extends ConsumerWidget {
  const SecaoDisponibilidade({required this.centralId, super.key});

  final String centralId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final precos = ref.watch(_provedorPrecos(centralId));
    return precos.when(
      loading: () => const Carregando(),
      error: (erro, _) => EstadoErro(
        mensagem: mensagemDeErro(erro),
        aoTentarNovamente: () => ref.invalidate(_provedorPrecos(centralId)),
      ),
      data: (itens) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LarguraMaxima(
            largura: 800,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TituloSecao('Produtos à venda'),
                const Text(
                  'Desligue o produto quando faltar: ele some do aplicativo dos clientes '
                  'desta central até você ligar de novo. O preço é definido pelo dono.',
                ),
                const SizedBox(height: 12),
                if (itens.isEmpty) const Text('O dono ainda não definiu os produtos desta central.'),
                for (final item in itens)
                  Card(
                    child: SwitchListTile(
                      value: item.disponivel,
                      title: Text(item.produto.nome),
                      subtitle: Text(
                        '${item.preco.formatarEmReais()}'
                        '${item.produto.ativo ? '' : ' · desativado pelo dono'}',
                      ),
                      onChanged: (ligado) async {
                        try {
                          await ref.read(provedorGestao).definirDisponivel(centralId, item.produto.id, ligado);
                          ref.invalidate(_provedorPrecos(centralId));
                          if (context.mounted) {
                            mostrarMensagem(
                              context,
                              ligado ? '${item.produto.nome} voltou a ser vendido.' : '${item.produto.nome} saiu do aplicativo.',
                            );
                          }
                        } catch (erro) {
                          if (context.mounted) {
                            mostrarMensagem(context, mensagemDeErro(erro), erro: true);
                          }
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
