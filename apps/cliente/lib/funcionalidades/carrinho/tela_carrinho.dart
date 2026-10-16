import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

class TelaCarrinho extends ConsumerWidget {
  const TelaCarrinho({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carrinho = ref.watch(provedorCarrinho);
    final atendimento = ref.watch(provedorAtendimento).valueOrNull;
    final taxa = atendimento?.taxaEntrega ?? Dinheiro.zero;
    final controle = ref.read(provedorCarrinho.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Seu carrinho')),
      body: carrinho.vazio
          ? EstadoVazio(
              icone: Icons.shopping_cart_outlined,
              titulo: 'Carrinho vazio',
              mensagem: 'Escolha o gás ou a água na tela inicial.',
              rotuloAcao: 'Ver produtos',
              aoAcionar: () => context.pop(),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final linha in carrinho.itens)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(linha.item.produto.nome,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  Text(
                                    '${linha.quantidade} x ${linha.item.preco.formatarEmReais()} = '
                                    '${linha.total.formatarEmReais()}',
                                  ),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Tirar um',
                              onPressed: () => controle.remover(linha.item),
                              icon: Icon(linha.quantidade == 1
                                  ? Icons.delete_outline
                                  : Icons.remove),
                            ),
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${linha.quantidade}',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            IconButton.filled(
                              tooltip: 'Pôr mais um',
                              onPressed:
                                  linha.quantidade >= Carrinho.quantidadeMaxima
                                      ? null
                                      : () => controle.adicionar(linha.item),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                LinhaValor(
                    rotulo: 'Produtos',
                    valor: carrinho.subtotal.formatarEmReais()),
                LinhaValor(
                  rotulo: 'Entrega',
                  valor: taxa.ehZero ? 'Grátis' : taxa.formatarEmReais(),
                ),
                const Divider(),
                LinhaValor(
                  rotulo: 'Total',
                  valor: (carrinho.subtotal + taxa).formatarEmReais(),
                  destaque: true,
                ),
                const SizedBox(height: 8),
                const Text(
                  'O pagamento é feito na entrega: dinheiro, cartão ou Pix.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
      bottomNavigationBar: carrinho.vazio
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: BotaoPrincipal(
                  icone: Icons.schedule,
                  rotulo: 'Escolher horário de entrega',
                  aoPressionar: () => context.push('/horario'),
                ),
              ),
            ),
    );
  }
}
