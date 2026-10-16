import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../comum/acoes_externas.dart';
import '../../estado/provedores.dart';

/// Abre o pedido em tela cheia (celular) ou janela (computador).
Future<void> mostrarDetalhePedido(
  BuildContext context, {
  required String pedidoId,
  required String centralId,
}) {
  final largura = MediaQuery.sizeOf(context).width;
  final conteudo = DetalhePedido(pedidoId: pedidoId, centralId: centralId);
  if (largura < 760) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => conteudo),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 860),
        child: conteudo,
      ),
    ),
  );
}

final _provedorPedido = FutureProvider.autoDispose.family<Pedido?, String>(
  (ref, id) => ref.watch(provedorPedidos).pedido(id),
);

final _provedorEntregadoresAtivos =
    FutureProvider.autoDispose.family<List<Entregador>, String>(
  (ref, centralId) =>
      ref.watch(provedorGestao).entregadores(centralId, somenteAtivos: true),
);

class DetalhePedido extends ConsumerStatefulWidget {
  const DetalhePedido(
      {required this.pedidoId, required this.centralId, super.key});

  final String pedidoId;
  final String centralId;

  @override
  ConsumerState<DetalhePedido> createState() => _DetalhePedidoState();
}

class _DetalhePedidoState extends ConsumerState<DetalhePedido> {
  bool _trabalhando = false;

  Future<void> _executar(Future<void> Function() acao, String sucesso,
      {bool fechar = false}) async {
    setState(() => _trabalhando = true);
    try {
      await acao();
      if (!mounted) {
        return;
      }
      mostrarMensagem(context, sucesso);
      if (fechar) {
        Navigator.of(context).pop();
      } else {
        ref.invalidate(_provedorPedido(widget.pedidoId));
      }
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
        ref.invalidate(_provedorPedido(widget.pedidoId));
      }
    } finally {
      if (mounted) {
        setState(() => _trabalhando = false);
      }
    }
  }

  Future<void> _avancar(Pedido pedido) async {
    final proximo = pedido.status.proximoPassoCentral;
    if (proximo == null) {
      return;
    }
    if (proximo == StatusPedido.entregue) {
      final certeza = await confirmar(
        context,
        titulo: 'Confirmar entrega',
        mensagem:
            'O pedido nº ${pedido.numero} foi entregue e pago? O estoque será baixado.',
        rotuloConfirmar: 'Sim, entregue',
      );
      if (!certeza) {
        return;
      }
    }
    await _executar(
      () => ref.read(provedorPedidos).mudarStatus(pedido.id, proximo),
      'Pedido nº ${pedido.numero}: ${proximo.rotuloCentral}.',
    );
  }

  Future<void> _voltarParaCentral(Pedido pedido) async {
    final motivo = await pedirTexto(
      context,
      titulo: 'Pedido voltou para a central',
      rotulo: 'O que aconteceu?',
      sugestoes: const [
        'Cliente ausente',
        'Endereço não encontrado',
        'Problema com o veículo'
      ],
    );
    if (motivo == null) {
      return;
    }
    await _executar(
      () => ref
          .read(provedorPedidos)
          .mudarStatus(pedido.id, StatusPedido.confirmado, motivo: motivo),
      'Pedido voltou para "Confirmados".',
    );
  }

  Future<void> _cancelar(Pedido pedido) async {
    final motivo = await pedirTexto(
      context,
      titulo: 'Cancelar o pedido nº ${pedido.numero}',
      rotulo: 'Motivo do cancelamento',
      mensagem: 'O cliente vê esse motivo no aplicativo.',
      rotuloConfirmar: 'Cancelar pedido',
      sugestoes: const [
        'Cliente desistiu',
        'Cliente não atendeu',
        'Fora da área de entrega',
        'Produto em falta',
      ],
    );
    if (motivo == null) {
      return;
    }
    await _executar(
      () => ref
          .read(provedorPedidos)
          .mudarStatus(pedido.id, StatusPedido.cancelado, motivo: motivo),
      'Pedido cancelado.',
      fechar: true,
    );
  }

  Future<void> _transferir(Pedido pedido) async {
    final escolha = await showDialog<OpcaoTransferencia>(
      context: context,
      builder: (_) => _DialogoTransferencia(pedido: pedido),
    );
    if (escolha == null || !mounted) {
      return;
    }
    final motivo = await pedirTexto(
      context,
      titulo: 'Transferir para ${escolha.centralNome}',
      rotulo: 'Motivo',
      mensagem:
          'O pedido sai da sua fila e vai para a ${escolha.centralNome}, com o mesmo preço e horário.',
      rotuloConfirmar: 'Transferir',
      sugestoes: const [
        'Produto em falta',
        'Sem entregador disponível',
        'Mais perto da outra central'
      ],
    );
    if (motivo == null) {
      return;
    }
    await _executar(
      () => ref
          .read(provedorPedidos)
          .transferir(pedido.id, escolha.centralId, motivo),
      'Pedido transferido para ${escolha.centralNome}.',
      fechar: true,
    );
  }

  Future<void> _escolherEntregador(
      Pedido pedido, List<Entregador> entregadores) async {
    final escolhido = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Quem vai entregar?'),
        children: [
          for (final e in entregadores)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(e.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(e.nome, style: const TextStyle(fontSize: 18)),
              ),
            ),
          if (pedido.entregadorId != null)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child:
                    Text('Tirar o entregador', style: TextStyle(fontSize: 18)),
              ),
            ),
        ],
      ),
    );
    if (escolhido == null) {
      return;
    }
    await _executar(
      () => ref
          .read(provedorPedidos)
          .atribuirEntregador(pedido.id, escolhido.isEmpty ? null : escolhido),
      'Entregador atualizado.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final pedido = ref.watch(_provedorPedido(widget.pedidoId));
    return Scaffold(
      appBar: AppBar(
        title: Text(pedido.valueOrNull == null
            ? 'Pedido'
            : 'Pedido nº ${pedido.valueOrNull!.numero}'),
        actions: [
          IconButton(
            tooltip: 'Fechar',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: pedido.when(
        loading: () => const Carregando(),
        error: (erro, _) => EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () =>
              ref.invalidate(_provedorPedido(widget.pedidoId)),
        ),
        data: (p) {
          if (p == null || p.centralId != widget.centralId) {
            return const EstadoVazio(
              icone: Icons.swap_horiz,
              titulo: 'Este pedido não está mais nesta central',
              mensagem: 'Ele pode ter sido transferido para outra central.',
            );
          }
          return _conteudo(context, p);
        },
      ),
    );
  }

  Widget _conteudo(BuildContext context, Pedido p) {
    final tema = Theme.of(context);
    final entregadores =
        ref.watch(_provedorEntregadoresAtivos(widget.centralId)).valueOrNull ??
            const <Entregador>[];
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                SeloStatus(status: p.status, paraCentral: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    p.horario,
                    style: tema.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (p.status == StatusPedido.cancelado &&
                p.motivoCancelamento != null) ...[
              const SizedBox(height: 8),
              Text('Motivo: ${p.motivoCancelamento}',
                  style: TextStyle(color: tema.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            if (p.status.proximoPassoCentral != null)
              BotaoPrincipal(
                icone: switch (p.status) {
                  StatusPedido.novo => Icons.check,
                  StatusPedido.confirmado => Icons.local_shipping_outlined,
                  _ => Icons.done_all,
                },
                rotulo: p.status.acaoProximoPasso!,
                carregando: _trabalhando,
                aoPressionar: () => _avancar(p),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (p.status.emAndamento && entregadores.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _trabalhando
                        ? null
                        : () => _escolherEntregador(p, entregadores),
                    icon: const Icon(Icons.delivery_dining),
                    label: Text(p.entregadorNome == null
                        ? 'Escolher entregador'
                        : 'Entregador: ${p.entregadorNome}'),
                  ),
                if (p.status.podeTransferir)
                  OutlinedButton.icon(
                    onPressed: _trabalhando ? null : () => _transferir(p),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Transferir para outra central'),
                  ),
                if (p.status == StatusPedido.emRota)
                  OutlinedButton.icon(
                    onPressed:
                        _trabalhando ? null : () => _voltarParaCentral(p),
                    icon: const Icon(Icons.undo),
                    label: const Text('Voltou para a central'),
                  ),
                if (p.status.emAndamento)
                  OutlinedButton.icon(
                    onPressed: _trabalhando ? null : () => _cancelar(p),
                    icon: Icon(Icons.close, color: tema.colorScheme.error),
                    label: Text('Cancelar',
                        style: TextStyle(color: tema.colorScheme.error)),
                  ),
              ],
            ),
            const TituloSecao('Cliente'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(p.clienteNome),
                    subtitle:
                        Text(Validacoes.formatarTelefone(p.clienteTelefone)),
                  ),
                  if (p.clienteTelefone.isNotEmpty)
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => ligar(context, p.clienteTelefone),
                          icon: const Icon(Icons.call),
                          label: const Text('Ligar'),
                        ),
                        TextButton.icon(
                          onPressed: () => abrirWhatsapp(
                            context,
                            p.clienteTelefone,
                            mensagem:
                                'Olá, ${p.clienteNome.split(' ').first}! Aqui é da central, sobre o seu pedido nº ${p.numero}.',
                          ),
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('WhatsApp'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const TituloSecao('Entrega'),
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(p.enderecoCompleto),
                    subtitle: Text([
                      'CEP ${Validacoes.formatarCep(p.cep)}',
                      if (p.referencia != null) 'Referência: ${p.referencia}',
                      '${p.distanciaKm.toStringAsFixed(1).replaceAll('.', ',')} km da central',
                    ].join('\n')),
                    isThreeLine: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: TextButton.icon(
                      onPressed: () =>
                          abrirMapa(context, p.latitude, p.longitude),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('Abrir rota no mapa'),
                    ),
                  ),
                  if (p.observacao != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text('Observação do cliente: ${p.observacao}',
                          style: tema.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            const TituloSecao('Itens e pagamento'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final item in p.itens)
                      LinhaValor(
                        rotulo: '${item.quantidade}x ${item.produtoNome}'
                            '${item.trocaVasilhame ? ' (troca)' : ''}',
                        valor: item.total.formatarEmReais(),
                      ),
                    LinhaValor(
                      rotulo: 'Taxa de entrega',
                      valor: p.taxaEntrega.ehZero
                          ? 'Grátis'
                          : p.taxaEntrega.formatarEmReais(),
                    ),
                    const Divider(),
                    LinhaValor(
                        rotulo: 'Total',
                        valor: p.total.formatarEmReais(),
                        destaque: true),
                    LinhaValor(
                        rotulo: 'Pagamento', valor: p.formaPagamento.rotulo),
                    if (!p.formaPagamento.naEntrega)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                            'Fiado: não cobrar na entrega. O valor entra na conta do cliente ao marcar como entregue.'),
                      ),
                    if (!p.trocoALevar.ehZero)
                      LinhaValor(
                        rotulo:
                            'Levar troco (cliente paga com ${p.trocoPara.formatarEmReais()})',
                        valor: p.trocoALevar.formatarEmReais(),
                        destaque: true,
                      ),
                  ],
                ),
              ),
            ),
            const TituloSecao('Histórico'),
            Card(
              child: Column(
                children: [
                  for (final evento in p.eventos.reversed)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        evento.evento == 'transferencia'
                            ? Icons.swap_horiz
                            : Icons.history,
                      ),
                      title: Text(evento.evento == 'status'
                          ? evento.status.rotuloCentral
                          : evento.descricao),
                      subtitle: Text([
                        Datas.formatarDataHora(evento.criadoEm),
                        if (evento.observacao != null &&
                            evento.evento != 'entregador')
                          evento.observacao!,
                      ].join(' · ')),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Pedido feito em ${Datas.formatarDataHora(p.criadoEm)}',
              style: tema.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        if (_trabalhando) const LinearProgressIndicator(),
      ],
    );
  }
}

class _DialogoTransferencia extends ConsumerWidget {
  const _DialogoTransferencia({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('Para qual central?'),
      content: SizedBox(
        width: 480,
        child: FutureBuilder<List<OpcaoTransferencia>>(
          future: ref.read(provedorPedidos).opcoesTransferencia(pedido.id),
          builder: (context, retrato) {
            if (retrato.connectionState != ConnectionState.done) {
              return const SizedBox(height: 120, child: Carregando());
            }
            if (retrato.hasError) {
              return Text(mensagemDeErro(retrato.error!));
            }
            final opcoes = retrato.data ?? const <OpcaoTransferencia>[];
            if (opcoes.isEmpty) {
              return const Text(
                  'Não há outra central ativa para receber o pedido.');
            }
            return ListView(
              shrinkWrap: true,
              children: [
                const Text('Da mais perto do cliente para a mais longe:'),
                const SizedBox(height: 8),
                for (final opcao in opcoes)
                  Card(
                    child: ListTile(
                      title: Text(opcao.centralNome),
                      subtitle: Text(
                        '${opcao.cidade}/${opcao.uf} · '
                        '${opcao.distanciaKm.toStringAsFixed(1).replaceAll('.', ',')} km do cliente\n'
                        '${opcao.produtosDisponiveis ? (opcao.estoqueSuficiente ? 'Tem os produtos em estoque' : 'Vende os produtos, estoque baixo') : 'Não vende algum dos produtos'}',
                      ),
                      isThreeLine: true,
                      leading: Icon(
                        opcao.produtosDisponiveis && opcao.estoqueSuficiente
                            ? Icons.check_circle
                            : Icons.warning_amber,
                        color:
                            opcao.produtosDisponiveis && opcao.estoqueSuficiente
                                ? Colors.green.shade700
                                : Colors.orange.shade800,
                      ),
                      onTap: () => Navigator.of(context).pop(opcao),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Voltar')),
      ],
    );
  }
}
