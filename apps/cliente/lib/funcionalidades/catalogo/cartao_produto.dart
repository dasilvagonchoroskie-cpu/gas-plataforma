import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

/// Cartão de produto com foto, preço e botões grandes de + e -.
class CartaoProduto extends ConsumerWidget {
  const CartaoProduto({required this.item, super.key});

  final ItemCatalogo item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final quantidade = ref.watch(
      provedorCarrinho.select((c) => c.quantidadeDe(item.produto.id)),
    );
    final carrinho = ref.read(provedorCarrinho.notifier);
    final produto = item.produto;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Foto(produto: produto),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(produto.nome, style: tema.textTheme.titleMedium),
                  if (produto.descricao != null) ...[
                    const SizedBox(height: 2),
                    Text(produto.descricao!, style: tema.textTheme.bodyMedium),
                  ],
                  if (produto.trocaVasilhame) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tenha o vasilhame vazio para trocar',
                      style: tema.textTheme.bodyMedium
                          ?.copyWith(color: tema.colorScheme.primary),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.preco.formatarEmReais(),
                          style: tema.textTheme.titleLarge,
                        ),
                      ),
                      if (quantidade == 0)
                        FilledButton.icon(
                          onPressed: () => carrinho.adicionar(item),
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar'),
                        )
                      else
                        _Quantidade(
                          quantidade: quantidade,
                          aoDiminuir: () => carrinho.remover(item),
                          aoAumentar: quantidade >= Carrinho.quantidadeMaxima
                              ? null
                              : () => carrinho.adicionar(item),
                        ),
                    ],
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

class _Foto extends StatelessWidget {
  const _Foto({required this.produto});

  final Produto produto;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final icone = Icon(
      produto.categoria == CategoriaProduto.gas
          ? Icons.propane_tank_outlined
          : Icons.water_drop_outlined,
      size: 40,
      color: cores.primary,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        height: 72,
        color: cores.primaryContainer.withValues(alpha: 0.5),
        child: produto.fotoUrl == null
            ? icone
            : Image.network(
                produto.fotoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, erro, pilha) => icone,
              ),
      ),
    );
  }
}

class _Quantidade extends StatelessWidget {
  const _Quantidade({
    required this.quantidade,
    required this.aoDiminuir,
    required this.aoAumentar,
  });

  final int quantidade;
  final VoidCallback aoDiminuir;
  final VoidCallback? aoAumentar;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Tirar um',
          iconSize: 28,
          onPressed: aoDiminuir,
          icon: Icon(quantidade == 1 ? Icons.delete_outline : Icons.remove),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$quantidade',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        IconButton.filled(
          tooltip: 'Pôr mais um',
          iconSize: 28,
          onPressed: aoAumentar,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
