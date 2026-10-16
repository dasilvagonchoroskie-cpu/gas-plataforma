import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleo/nucleo.dart';

import '../../comum/links.dart';
import '../../estado/provedores.dart';

/// Acompanhamento ao vivo: a tela muda sozinha quando a central atualiza.
class TelaAcompanharPedido extends ConsumerWidget {
  const TelaAcompanharPedido({required this.pedidoId, super.key});

  final String pedidoId;

  Future<void> _cancelar(
      BuildContext context, WidgetRef ref, Pedido pedido) async {
    final certeza = await confirmar(
      context,
      titulo: 'Cancelar o pedido nº ${pedido.numero}?',
      mensagem:
          'A central ainda não confirmou. Se cancelar, ela não fará a entrega.',
      rotuloConfirmar: 'Cancelar pedido',
      rotuloCancelar: 'Manter pedido',
      perigoso: true,
    );
    if (!certeza) {
      return;
    }
    try {
      await ref.read(provedorRepositorioPedidos).cancelarComoCliente(pedido.id);
      ref.invalidate(provedorMeusPedidos);
      if (context.mounted) {
        mostrarMensagem(context, 'Pedido cancelado.');
      }
    } catch (erro) {
      if (context.mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedido = ref.watch(provedorPedidoAoVivo(pedidoId));
    return Scaffold(
      appBar: AppBar(
        title: Text(pedido.valueOrNull == null
            ? 'Pedido'
            : 'Pedido nº ${pedido.valueOrNull!.numero}'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: pedido.when(
        loading: () => const Carregando(),
        error: (erro, _) => EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () =>
              ref.invalidate(provedorPedidoAoVivo(pedidoId)),
        ),
        data: (p) {
          if (p == null) {
            return const EstadoVazio(titulo: 'Pedido não encontrado');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Cabecalho(pedido: p),
              const SizedBox(height: 16),
              _LinhaDoTempo(pedido: p),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Itens',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final item in p.itens)
                        LinhaValor(
                          rotulo: '${item.quantidade}x ${item.produtoNome}',
                          valor: item.total.formatarEmReais(),
                        ),
                      LinhaValor(
                        rotulo: 'Entrega',
                        valor: p.taxaEntrega.ehZero
                            ? 'Grátis'
                            : p.taxaEntrega.formatarEmReais(),
                      ),
                      const Divider(),
                      LinhaValor(
                          rotulo: 'Total',
                          valor: p.total.formatarEmReais(),
                          destaque: true),
                      const SizedBox(height: 8),
                      Text(
                        p.formaPagamento.naEntrega
                            ? 'Pagamento na entrega: ${p.formaPagamento.rotulo}'
                                '${p.trocoPara.centavos > 0 ? ' (troco para ${p.trocoPara.formatarEmReais()})' : ''}'
                            : 'No crediário (fiado): o valor entra na sua conta quando o pedido for entregue.',
                      ),
                      if (p.itens.any((i) => i.trocaVasilhame)) ...[
                        const SizedBox(height: 8),
                        const Text(
                            'Deixe o vasilhame vazio separado para a troca.'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: const Text('Endereço de entrega'),
                  subtitle: Text(p.enderecoCompleto),
                ),
              ),
              const SizedBox(height: 16),
              if (p.status.emAndamento)
                BotaoPrincipal(
                  icone: Icons.chat_outlined,
                  rotulo: 'Falar com a central',
                  secundario: true,
                  aoPressionar: () => abrirWhatsapp(
                    context,
                    numero: p.centralWhatsapp,
                    mensagem: 'Olá! Sobre o meu pedido nº ${p.numero}.',
                  ),
                ),
              if (p.status.clientePodeCancelar) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _cancelar(context, ref, p),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancelar pedido'),
                  style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cor = corDoStatus(pedido.status, tema.colorScheme);
    final mensagem = switch (pedido.status) {
      StatusPedido.novo =>
        'A central recebeu seu pedido e vai confirmar em instantes.',
      StatusPedido.confirmado => 'A central está separando o seu pedido.',
      StatusPedido.emRota =>
        'O entregador está a caminho${pedido.entregadorNome == null ? '' : ': ${pedido.entregadorNome}'}.',
      StatusPedido.entregue => 'Pedido entregue. Obrigado pela preferência!',
      StatusPedido.cancelado =>
        pedido.motivoCancelamento ?? 'Pedido cancelado.',
    };
    return Card(
      color: cor.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SeloStatus(status: pedido.status),
            const SizedBox(height: 12),
            Text(mensagem, style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Entrega: ${pedido.horario}'),
            if (pedido.centralNome != null)
              Text('Central: ${pedido.centralNome}'),
          ],
        ),
      ),
    );
  }
}

class _LinhaDoTempo extends StatelessWidget {
  const _LinhaDoTempo({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    if (pedido.status == StatusPedido.cancelado) {
      return const SizedBox.shrink();
    }
    const etapas = [
      StatusPedido.novo,
      StatusPedido.confirmado,
      StatusPedido.emRota,
      StatusPedido.entregue,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (final etapa in etapas)
              ListTile(
                leading: Icon(
                  pedido.status.etapa >= etapa.etapa
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: pedido.status.etapa >= etapa.etapa
                      ? corDoStatus(etapa, tema.colorScheme)
                      : tema.colorScheme.outline,
                  size: 30,
                ),
                title: Text(
                  etapa.rotuloCliente,
                  style: pedido.status == etapa
                      ? tema.textTheme.titleMedium
                      : tema.textTheme.bodyLarge,
                ),
                subtitle: _horaDa(etapa) == null ? null : Text(_horaDa(etapa)!),
              ),
          ],
        ),
      ),
    );
  }

  String? _horaDa(StatusPedido etapa) {
    for (final evento in pedido.eventos.reversed) {
      if (evento.evento == 'status' && evento.status == etapa) {
        return Datas.formatarDataHora(evento.criadoEm);
      }
    }
    return null;
  }
}
