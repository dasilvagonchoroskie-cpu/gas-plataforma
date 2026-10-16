import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';
import 'detalhe_pedido.dart';

/// Fila de pedidos de uma central, ao vivo.
///
/// Recarrega sozinha quando o servidor avisa que algo mudou (pedido novo,
/// mudança de status, transferência) e, por segurança, a cada 45 segundos.
/// Toca um aviso sonoro quando chega pedido novo.
class FilaPedidos extends ConsumerStatefulWidget {
  const FilaPedidos({
    required this.centralId,
    this.aoMudarNovos,
    this.tocarSom = true,
    super.key,
  });

  final String centralId;

  /// Informa quantos pedidos novos estão esperando (para o contador do menu).
  final ValueChanged<int>? aoMudarNovos;
  final bool tocarSom;

  @override
  ConsumerState<FilaPedidos> createState() => _FilaPedidosState();
}

class _FilaPedidosState extends ConsumerState<FilaPedidos> {
  List<Pedido> _pedidos = const [];
  Object? _erro;
  bool _carregando = true;
  bool _somLigado = true;
  DateTime? _atualizadoEm;
  final Set<String> _novosJaVistos = {};
  bool _primeiraCarga = true;
  StreamSubscription<List<Map<String, dynamic>>>? _assinatura;
  Timer? _intervalo;
  Timer? _espera;
  final _som = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _ligar();
  }

  @override
  void didUpdateWidget(covariant FilaPedidos antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.centralId != widget.centralId) {
      _desligar();
      setState(() {
        _pedidos = const [];
        _carregando = true;
        _primeiraCarga = true;
        _novosJaVistos.clear();
      });
      _ligar();
    }
  }

  void _ligar() {
    unawaited(_recarregar());
    _assinatura = ref
        .read(provedorPedidos)
        .mudancasDaCentral(widget.centralId)
        .listen((_) => _agendarRecarga(), onError: (_) => _agendarRecarga());
    _intervalo =
        Timer.periodic(const Duration(seconds: 45), (_) => _recarregar());
  }

  void _desligar() {
    _assinatura?.cancel();
    _intervalo?.cancel();
    _espera?.cancel();
  }

  @override
  void dispose() {
    _desligar();
    _som.dispose();
    super.dispose();
  }

  /// Várias mudanças seguidas viram uma recarga só.
  void _agendarRecarga() {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), _recarregar);
  }

  Future<void> _recarregar() async {
    try {
      final pedidos =
          await ref.read(provedorPedidos).pedidosDaCentral(widget.centralId);
      if (!mounted) {
        return;
      }
      final novos =
          pedidos.where((p) => p.status == StatusPedido.novo).toList();
      final chegaram =
          novos.where((p) => !_novosJaVistos.contains(p.id)).toList();
      _novosJaVistos.addAll(novos.map((p) => p.id));
      setState(() {
        _pedidos = pedidos;
        _erro = null;
        _carregando = false;
        _atualizadoEm = Datas.paraLocal(DateTime.now());
      });
      widget.aoMudarNovos?.call(novos.length);
      if (!_primeiraCarga && chegaram.isNotEmpty) {
        _avisarNovos(chegaram);
      }
      _primeiraCarga = false;
    } catch (erro) {
      if (mounted) {
        setState(() {
          _erro = erro;
          _carregando = false;
        });
      }
    }
  }

  Future<void> _avisarNovos(List<Pedido> chegaram) async {
    if (widget.tocarSom && _somLigado) {
      try {
        await _som.play(AssetSource('som/novo_pedido.wav'));
      } catch (_) {
        // O navegador pode bloquear o som até a primeira interação.
      }
    }
    if (mounted) {
      mostrarMensagem(
        context,
        chegaram.length == 1
            ? 'Pedido novo nº ${chegaram.first.numero}!'
            : '${chegaram.length} pedidos novos!',
      );
    }
  }

  Future<void> _abrir(Pedido pedido) async {
    await mostrarDetalhePedido(context,
        pedidoId: pedido.id, centralId: widget.centralId);
    await _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Carregando(mensagem: 'Carregando pedidos...');
    }
    if (_erro != null && _pedidos.isEmpty) {
      return EstadoErro(
          mensagem: mensagemDeErro(_erro!), aoTentarNovamente: _recarregar);
    }

    final colunas = <(String, List<Pedido>)>[
      ('Novos', _pedidos.where((p) => p.status == StatusPedido.novo).toList()),
      (
        'Confirmados',
        _pedidos.where((p) => p.status == StatusPedido.confirmado).toList()
      ),
      (
        'Em rota',
        _pedidos.where((p) => p.status == StatusPedido.emRota).toList()
      ),
      ('Encerrados hoje', _pedidos.where((p) => p.status.ehFinal).toList()),
    ];

    final barra = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _erro != null
                  ? 'Sem conexão — tentando de novo...'
                  : 'Atualizado às ${_atualizadoEm == null ? '--' : Datas.formatarHoraDe(_atualizadoEm!)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _erro != null
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
            ),
          ),
          IconButton(
            tooltip:
                _somLigado ? 'Desligar aviso sonoro' : 'Ligar aviso sonoro',
            icon: Icon(_somLigado ? Icons.volume_up : Icons.volume_off),
            onPressed: () => setState(() => _somLigado = !_somLigado),
          ),
          IconButton(
            tooltip: 'Atualizar agora',
            icon: const Icon(Icons.refresh),
            onPressed: _recarregar,
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, restricoes) {
        if (restricoes.maxWidth >= 1000) {
          return Column(
            children: [
              barra,
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (titulo, lista) in colunas)
                      Expanded(
                        child: _Coluna(
                            titulo: titulo, pedidos: lista, aoAbrir: _abrir),
                      ),
                  ],
                ),
              ),
            ],
          );
        }
        return DefaultTabController(
          length: colunas.length,
          child: Column(
            children: [
              barra,
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final (titulo, lista) in colunas)
                    Tab(text: '$titulo (${lista.length})'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final (titulo, lista) in colunas)
                      _ListaPedidos(
                        pedidos: lista,
                        vazio: 'Nenhum pedido em "$titulo".',
                        aoAbrir: _abrir,
                        aoAtualizar: _recarregar,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Coluna extends StatelessWidget {
  const _Coluna(
      {required this.titulo, required this.pedidos, required this.aoAbrir});

  final String titulo;
  final List<Pedido> pedidos;
  final ValueChanged<Pedido> aoAbrir;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('$titulo (${pedidos.length})',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: _ListaPedidos(
                  pedidos: pedidos, vazio: 'Nenhum pedido.', aoAbrir: aoAbrir),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaPedidos extends StatelessWidget {
  const _ListaPedidos({
    required this.pedidos,
    required this.vazio,
    required this.aoAbrir,
    this.aoAtualizar,
  });

  final List<Pedido> pedidos;
  final String vazio;
  final ValueChanged<Pedido> aoAbrir;
  final Future<void> Function()? aoAtualizar;

  @override
  Widget build(BuildContext context) {
    final lista = pedidos.isEmpty
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(vazio, textAlign: TextAlign.center),
              ),
            ],
          )
        : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            itemCount: pedidos.length,
            separatorBuilder: (context, indice) => const SizedBox(height: 8),
            itemBuilder: (context, indice) =>
                CartaoPedidoFila(pedido: pedidos[indice], aoAbrir: aoAbrir),
          );
    final atualizar = aoAtualizar;
    return atualizar == null
        ? lista
        : RefreshIndicator(onRefresh: atualizar, child: lista);
  }
}

/// Cartão resumido do pedido na fila.
class CartaoPedidoFila extends StatelessWidget {
  const CartaoPedidoFila(
      {required this.pedido, required this.aoAbrir, super.key});

  final Pedido pedido;
  final ValueChanged<Pedido> aoAbrir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final atrasado = pedido.status.emAndamento &&
        (pedido.dataEntrega.isBefore(Datas.hoje()) ||
            (pedido.dataEntrega == Datas.hoje() &&
                pedido.horaFim.compareTo(
                        Datas.formatarHoraDe(Datas.paraLocal(DateTime.now()))) <
                    0));
    return Card(
      color: tema.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => aoAbrir(pedido),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Nº ${pedido.numero}',
                        style: tema.textTheme.titleMedium),
                  ),
                  SeloStatus(status: pedido.status, paraCentral: true),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                pedido.horario,
                style: tema.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: atrasado ? tema.colorScheme.error : null,
                ),
              ),
              Text('${pedido.bairro} · ${pedido.cidade}'),
              const SizedBox(height: 4),
              Text(pedido.resumoItens,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(pedido.total.formatarEmReais(),
                      style: tema.textTheme.titleMedium),
                  Chip(
                      label: Text(pedido.formaPagamento.rotulo),
                      visualDensity: VisualDensity.compact),
                  if (!pedido.trocoALevar.ehZero)
                    Chip(
                      label: Text(
                          'Troco: ${pedido.trocoALevar.formatarEmReais()}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (pedido.transferencias > 0)
                    const Chip(
                      avatar: Icon(Icons.swap_horiz, size: 18),
                      label: Text('Transferido'),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (pedido.entregadorNome != null)
                    Chip(
                      avatar: const Icon(Icons.delivery_dining, size: 18),
                      label: Text(pedido.entregadorNome!),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (atrasado)
                    Chip(
                      avatar: Icon(Icons.warning_amber,
                          size: 18, color: tema.colorScheme.error),
                      label: const Text('Atrasado'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
