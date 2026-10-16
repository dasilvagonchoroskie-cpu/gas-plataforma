import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleo/nucleo.dart';

import '../../app.dart';
import '../../comum/links.dart';
import '../../estado/provedores.dart';
import 'cartao_produto.dart';

/// Início: endereço de entrega, central que atende e catálogo com preços.
class AbaInicio extends ConsumerWidget {
  const AbaInicio({required this.aoVerPedidos, super.key});

  final VoidCallback aoVerPedidos;

  Future<void> _recarregar(WidgetRef ref) async {
    ref.invalidate(provedorEnderecos);
    ref.invalidate(provedorMeusPedidos);
    await ref.read(provedorCatalogo.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endereco = ref.watch(provedorEnderecoAtual);
    final carrinho = ref.watch(provedorCarrinho);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: InkWell(
          onTap: () => context.push('/enderecos'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Entregar em',
                    style: Theme.of(context).textTheme.bodyMedium),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        endereco.valueOrNull?.apelido ?? nomeDoApp,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: endereco.when(
        loading: () => const Carregando(mensagem: 'Carregando...'),
        error: (erro, _) => EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () => ref.invalidate(provedorEnderecos),
        ),
        data: (atual) {
          if (atual == null) {
            return EstadoVazio(
              icone: Icons.home_outlined,
              titulo: 'Onde vamos entregar?',
              mensagem:
                  'Cadastre seu endereço para ver os produtos e preços da central mais perto de você.',
              rotuloAcao: 'Cadastrar endereço',
              aoAcionar: () => context.push('/enderecos/novo'),
            );
          }
          return RefreshIndicator(
            onRefresh: () => _recarregar(ref),
            child:
                _ConteudoCatalogo(endereco: atual, aoVerPedidos: aoVerPedidos),
          );
        },
      ),
      bottomNavigationBar: carrinho.vazio
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: BotaoPrincipal(
                  icone: Icons.shopping_cart_outlined,
                  rotulo: 'Ver carrinho · ${carrinho.quantidadeTotal} '
                      '${carrinho.quantidadeTotal == 1 ? 'item' : 'itens'} · '
                      '${carrinho.subtotal.formatarEmReais()}',
                  aoPressionar: () => context.push('/carrinho'),
                ),
              ),
            ),
    );
  }
}

class _ConteudoCatalogo extends ConsumerWidget {
  const _ConteudoCatalogo({required this.endereco, required this.aoVerPedidos});

  final Endereco endereco;
  final VoidCallback aoVerPedidos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atendimento = ref.watch(provedorAtendimento);
    return atendimento.when(
      loading: () =>
          const Carregando(mensagem: 'Procurando a central mais perto...'),
      error: (erro, _) => EstadoErro(
        mensagem: mensagemDeErro(erro),
        aoTentarNovamente: () => ref.invalidate(provedorAtendimento),
      ),
      data: (central) {
        if (central == null) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 40),
              EstadoVazio(
                icone: Icons.location_off_outlined,
                titulo: 'Ainda não entregamos aí',
                mensagem:
                    'Nenhuma central atende "${endereco.linhaPrincipal}". '
                    'Se o endereço estiver errado, corrija ou cadastre outro.',
                rotuloAcao: 'Trocar endereço',
                aoAcionar: () => context.push('/enderecos'),
              ),
            ],
          );
        }
        return _ListaProdutos(atendimento: central, aoVerPedidos: aoVerPedidos);
      },
    );
  }
}

class _ListaProdutos extends ConsumerWidget {
  const _ListaProdutos({required this.atendimento, required this.aoVerPedidos});

  final Atendimento atendimento;
  final VoidCallback aoVerPedidos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(provedorCatalogo);
    final pedidos =
        ref.watch(provedorMeusPedidos).valueOrNull ?? const <Pedido>[];
    final emAndamento = pedidos.where((p) => p.status.emAndamento).toList();
    final ultimo = pedidos.isEmpty ? null : pedidos.first;

    return catalogo.when(
      loading: () => const Carregando(mensagem: 'Carregando produtos...'),
      error: (erro, _) => EstadoErro(
        mensagem: mensagemDeErro(erro),
        aoTentarNovamente: () => ref.invalidate(provedorCatalogo),
      ),
      data: (itens) {
        final gas = itens
            .where((i) => i.produto.categoria == CategoriaProduto.gas)
            .toList();
        final agua = itens
            .where((i) => i.produto.categoria == CategoriaProduto.agua)
            .toList();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (emAndamento.isNotEmpty)
              _CartaoPedidoEmAndamento(
                  pedido: emAndamento.first, aoVerPedidos: aoVerPedidos),
            _CartaoCentral(atendimento: atendimento),
            const _CartaoFicha(),
            if (ultimo != null && emAndamento.isEmpty)
              _CartaoRepetir(ultimo: ultimo, catalogo: itens),
            if (itens.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: EstadoVazio(
                  icone: Icons.inventory_2_outlined,
                  titulo: 'Sem produtos agora',
                  mensagem:
                      'A central está sem produtos disponíveis no momento. Tente mais tarde ou chame no WhatsApp.',
                ),
              ),
            if (gas.isNotEmpty) ...[
              const TituloSecao('Gás de cozinha'),
              for (final item in gas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CartaoProduto(item: item),
                ),
            ],
            if (agua.isNotEmpty) ...[
              const TituloSecao('Água mineral'),
              for (final item in agua)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CartaoProduto(item: item),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _CartaoCentral extends StatelessWidget {
  const _CartaoCentral({required this.atendimento});

  final Atendimento atendimento;

  @override
  Widget build(BuildContext context) {
    final taxa = atendimento.taxaEntrega.ehZero
        ? 'Entrega grátis'
        : 'Entrega: ${atendimento.taxaEntrega.formatarEmReais()}';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.store_mall_directory_outlined, size: 32),
        title: Text(atendimento.centralNome),
        subtitle: Text(
            '$taxa · ${atendimento.distanciaKm.toStringAsFixed(1).replaceAll('.', ',')} km'),
        trailing: atendimento.whatsapp == null
            ? null
            : IconButton(
                tooltip: 'Falar com a central no WhatsApp',
                icon: const Icon(Icons.chat_outlined),
                onPressed: () => abrirWhatsapp(
                  context,
                  numero: atendimento.whatsapp,
                  mensagem: 'Olá! Vim pelo aplicativo.',
                ),
              ),
      ),
    );
  }
}

class _CartaoPedidoEmAndamento extends StatelessWidget {
  const _CartaoPedidoEmAndamento(
      {required this.pedido, required this.aoVerPedidos});

  final Pedido pedido;
  final VoidCallback aoVerPedidos;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: cores.primaryContainer,
        child: ListTile(
          leading: Icon(Icons.local_shipping_outlined,
              color: cores.onPrimaryContainer, size: 32),
          title: Text(
              'Pedido nº ${pedido.numero}: ${pedido.status.rotuloCliente}'),
          subtitle: Text(pedido.horario),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/pedido/${pedido.id}'),
        ),
      ),
    );
  }
}

/// Lembra o cliente de preencher a ficha (obrigatória para pedir) e mostra o
/// crediário quando aprovado.
class _CartaoFicha extends ConsumerWidget {
  const _CartaoFicha();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ficha = ref.watch(provedorMinhaFicha);
    if (!ficha.hasValue) {
      return const SizedBox.shrink();
    }
    final atual = ficha.requireValue;
    final tema = Theme.of(context);
    final (
      IconData icone,
      String titulo,
      String texto,
      String? acao,
      String rota
    ) = atual == null
        ? (
            Icons.badge_outlined,
            'Complete sua ficha de cadastro',
            'Ela é obrigatória para fazer pedidos e serve para liberar o crediário (fiado).',
            'Preencher ficha',
            '/ficha',
          )
        : switch (atual.status) {
            StatusFicha.pendente => (
                Icons.hourglass_top,
                'Ficha em análise',
                'Você já pode pedir pagando na entrega. O crediário fica liberado depois da aprovação.',
                null,
                '/ficha',
              ),
            StatusFicha.recusada => (
                Icons.error_outline,
                'Ficha não aprovada',
                atual.motivo == null
                    ? 'Confira os dados e envie de novo.'
                    : 'Motivo: ${atual.motivo}. Corrija e envie de novo.',
                'Corrigir ficha',
                '/ficha',
              ),
            StatusFicha.aprovada => (
                Icons.account_balance_wallet_outlined,
                'Crediário liberado',
                atual.creditoBloqueado
                    ? 'Seu crediário está bloqueado. Fale com a loja.'
                    : 'Limite de ${atual.limite.formatarEmReais()}. Toque para ver quanto está livre.',
                null,
                '/crediario',
              ),
          };
    final destaque = atual == null || atual.status == StatusFicha.recusada;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        color: destaque ? tema.colorScheme.errorContainer : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(rota),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(icone),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(titulo, style: tema.textTheme.titleMedium)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(texto),
                if (acao != null) ...[
                  const SizedBox(height: 12),
                  BotaoPrincipal(
                      rotulo: acao, aoPressionar: () => context.push(rota)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Repetir o último pedido: um toque aqui, um para o horário e um para
/// confirmar.
class _CartaoRepetir extends ConsumerWidget {
  const _CartaoRepetir({required this.ultimo, required this.catalogo});

  final Pedido ultimo;
  final List<ItemCatalogo> catalogo;

  void _repetir(BuildContext context, WidgetRef ref) {
    final carrinho = Carrinho.aPartirDe(
      {for (final item in ultimo.itens) item.produtoId: item.quantidade},
      catalogo,
    );
    if (carrinho.vazio) {
      mostrarMensagem(
          context, 'Os produtos do último pedido não estão disponíveis agora.',
          erro: true);
      return;
    }
    ref.read(provedorCarrinho.notifier).substituir(carrinho);
    final finalizacao = ref.read(provedorFinalizacao.notifier)
      ..recomecar()
      ..escolherPagamento(ultimo.formaPagamento);
    if (ultimo.formaPagamento == FormaPagamento.dinheiro &&
        ultimo.trocoPara.centavos > 0) {
      finalizacao.definirTroco(ultimo.trocoPara);
    }
    context.push('/horario');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Seu último pedido',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(ultimo.resumoItens),
              const SizedBox(height: 12),
              BotaoPrincipal(
                icone: Icons.replay,
                rotulo: 'Pedir de novo',
                aoPressionar: () => _repetir(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
