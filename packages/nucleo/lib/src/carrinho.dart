import 'dinheiro.dart';
import 'modelos.dart';

/// Linha do carrinho.
final class ItemCarrinho {
  const ItemCarrinho({required this.item, required this.quantidade});

  final ItemCatalogo item;
  final int quantidade;

  Dinheiro get total => item.preco * quantidade;
}

/// Carrinho imutável: cada alteração devolve um carrinho novo.
///
/// Os valores servem só para mostrar ao cliente. O total que vale é sempre o
/// calculado pelo servidor ao criar o pedido.
final class Carrinho {
  const Carrinho._(this._itens, this.centralId);

  const Carrinho.vazio() : this._(const {}, null);

  static const int quantidadeMaxima = 50;

  final Map<String, ItemCarrinho> _itens;

  /// Central dos preços. Se o cliente trocar de endereço e a central mudar, o
  /// carrinho é refeito com os preços da nova central.
  final String? centralId;

  List<ItemCarrinho> get itens => _itens.values.toList(growable: false);

  bool get vazio => _itens.isEmpty;

  int get quantidadeTotal =>
      _itens.values.fold(0, (soma, linha) => soma + linha.quantidade);

  Dinheiro get subtotal =>
      _itens.values.fold(Dinheiro.zero, (soma, linha) => soma + linha.total);

  int quantidadeDe(String produtoId) => _itens[produtoId]?.quantidade ?? 0;

  Carrinho definir(ItemCatalogo item, int quantidade) {
    final novos = Map<String, ItemCarrinho>.of(_itens);
    final central = centralId ?? item.centralId;
    if (central != item.centralId) {
      // Produto de outra central: começa um carrinho novo.
      novos.clear();
    }
    final limitada = quantidade < 0
        ? 0
        : (quantidade > quantidadeMaxima ? quantidadeMaxima : quantidade);
    if (limitada == 0) {
      novos.remove(item.produto.id);
    } else {
      novos[item.produto.id] = ItemCarrinho(item: item, quantidade: limitada);
    }
    return Carrinho._(
      Map.unmodifiable(novos),
      novos.isEmpty ? null : item.centralId,
    );
  }

  Carrinho adicionar(ItemCatalogo item, [int quantidade = 1]) =>
      definir(item, quantidadeDe(item.produto.id) + quantidade);

  Carrinho remover(ItemCatalogo item, [int quantidade = 1]) =>
      definir(item, quantidadeDe(item.produto.id) - quantidade);

  /// Refaz o carrinho com os preços atuais (por exemplo, ao repetir um pedido
  /// antigo). Produtos que não estão mais à venda ficam de fora.
  static Carrinho aPartirDe(
    Map<String, int> quantidades,
    List<ItemCatalogo> catalogo,
  ) {
    var carrinho = const Carrinho.vazio();
    for (final item in catalogo) {
      final quantidade = quantidades[item.produto.id];
      if (quantidade != null && quantidade > 0 && item.disponivel) {
        carrinho = carrinho.definir(item, quantidade);
      }
    }
    return carrinho;
  }

  /// Itens no formato da função criar_pedido: só produto e quantidade.
  List<Map<String, Object>> paraPedido() => [
        for (final linha in _itens.values)
          {'produto_id': linha.item.produto.id, 'quantidade': linha.quantidade},
      ];
}
