import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

final _provedorEstoque =
    FutureProvider.autoDispose.family<List<ItemEstoque>, String>(
  (ref, centralId) => ref.watch(provedorGestao).estoque(centralId),
);

final _provedorPrecos =
    FutureProvider.autoDispose.family<List<ItemCatalogo>, String>(
  (ref, centralId) => ref.watch(provedorGestao).precos(centralId),
);

final _provedorMovimentos =
    FutureProvider.autoDispose.family<List<MovimentoEstoque>, String>(
  (ref, centralId) => ref.watch(provedorGestao).movimentos(centralId),
);

/// Estoque da central: cheios e vazios de cada produto, com entrada, saída,
/// ajuste e contagem — sempre com motivo. A entrega de pedido baixa sozinha.
class SecaoEstoque extends ConsumerWidget {
  const SecaoEstoque({required this.centralId, super.key});

  final String centralId;

  void _atualizar(WidgetRef ref) {
    ref.invalidate(_provedorEstoque(centralId));
    ref.invalidate(_provedorMovimentos(centralId));
  }

  Future<void> _movimentar(
      BuildContext context, WidgetRef ref, _LinhaEstoque linha) async {
    final dados = await showDialog<_Movimento>(
      context: context,
      builder: (_) => _DialogoMovimento(linha: linha),
    );
    if (dados == null || !context.mounted) {
      return;
    }
    try {
      await ref.read(provedorGestao).movimentarEstoque(
            centralId: centralId,
            produtoId: linha.produtoId,
            tipo: dados.tipo,
            cheios: dados.cheios,
            vazios: dados.vazios,
            motivo: dados.motivo,
          );
      _atualizar(ref);
      if (context.mounted) {
        mostrarMensagem(context, 'Estoque atualizado.');
      }
    } catch (erro) {
      if (context.mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    }
  }

  Future<void> _alerta(
      BuildContext context, WidgetRef ref, _LinhaEstoque linha) async {
    final texto = await pedirTexto(
      context,
      titulo: 'Avisar quando tiver pouco',
      rotulo: 'Avisar com quantos cheios ou menos? (${linha.nome})',
      maximo: 5,
    );
    if (texto == null || !context.mounted) {
      return;
    }
    final minimo = int.tryParse(texto);
    if (minimo == null || minimo < 0) {
      mostrarMensagem(context, 'Digite um número a partir de zero.',
          erro: true);
      return;
    }
    try {
      if (!linha.temRegistro) {
        await ref.read(provedorGestao).movimentarEstoque(
              centralId: centralId,
              produtoId: linha.produtoId,
              tipo: TipoMovimentoEstoque.contagem,
              cheios: 0,
              vazios: 0,
              motivo: 'Início do controle de estoque',
            );
      }
      await ref
          .read(provedorGestao)
          .definirAlertaMinimo(centralId, linha.produtoId, minimo);
      _atualizar(ref);
    } catch (erro) {
      if (context.mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estoque = ref.watch(_provedorEstoque(centralId));
    final precos = ref.watch(_provedorPrecos(centralId)).valueOrNull ??
        const <ItemCatalogo>[];
    final movimentos = ref.watch(_provedorMovimentos(centralId));
    final tema = Theme.of(context);

    return estoque.when(
      loading: () => const Carregando(),
      error: (erro, _) => EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () => _atualizar(ref)),
      data: (itens) {
        final linhas = <_LinhaEstoque>[
          for (final i in itens) _LinhaEstoque.deEstoque(i),
          for (final p in precos)
            if (!itens.any((i) => i.produtoId == p.produto.id))
              _LinhaEstoque.semRegistro(p.produto),
        ]..sort((a, b) => a.nome.compareTo(b.nome));
        return RefreshIndicator(
          onRefresh: () async => _atualizar(ref),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LarguraMaxima(
                largura: 900,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TituloSecao('Estoque agora'),
                    if (linhas.isEmpty)
                      const Text(
                          'Nenhum produto cadastrado para esta central.'),
                    for (final linha in linhas)
                      Card(
                        color: linha.negativo || linha.baixo
                            ? tema.colorScheme.errorContainer
                                .withValues(alpha: 0.5)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(linha.nome,
                                        style: tema.textTheme.titleMedium),
                                    Text(
                                      'Cheios: ${linha.cheios}'
                                      '${linha.troca ? '   ·   Vazios: ${linha.vazios}' : ''}',
                                      style: tema.textTheme.bodyLarge,
                                    ),
                                    if (linha.negativo)
                                      Text(
                                          'Estoque negativo: faça uma contagem.',
                                          style: TextStyle(
                                              color: tema.colorScheme.error)),
                                    if (!linha.negativo && linha.baixo)
                                      Text(
                                          'Pouco estoque (aviso em ${linha.alertaMinimo}).',
                                          style: TextStyle(
                                              color: tema.colorScheme.error)),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Aviso de pouco estoque',
                                icon: const Icon(
                                    Icons.notifications_active_outlined),
                                onPressed: () => _alerta(context, ref, linha),
                              ),
                              FilledButton.tonal(
                                onPressed: () =>
                                    _movimentar(context, ref, linha),
                                child: const Text('Movimentar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const TituloSecao('Últimos movimentos'),
                    ...movimentos.when<List<Widget>>(
                      loading: () => const [LinearProgressIndicator()],
                      error: (erro, _) => [Text(mensagemDeErro(erro))],
                      data: (lista) => lista.isEmpty
                          ? const [Text('Nenhum movimento ainda.')]
                          : [
                              for (final m in lista)
                                ListTile(
                                  dense: true,
                                  leading: Icon(
                                    m.deltaCheios >= 0
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: m.deltaCheios >= 0
                                        ? Colors.green.shade700
                                        : tema.colorScheme.error,
                                  ),
                                  title: Text(
                                    '${m.produtoNome}: cheios ${_sinal(m.deltaCheios)}'
                                    '${m.deltaVazios != 0 ? ', vazios ${_sinal(m.deltaVazios)}' : ''}',
                                  ),
                                  subtitle: Text(
                                    '${m.tipo.rotulo} · ${m.motivo} · ${Datas.formatarDataHora(m.criadoEm)}',
                                  ),
                                  trailing: Text('${m.cheiosApos}'),
                                ),
                            ],
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

  static String _sinal(int valor) => valor > 0 ? '+$valor' : '$valor';
}

class _LinhaEstoque {
  const _LinhaEstoque({
    required this.produtoId,
    required this.nome,
    required this.cheios,
    required this.vazios,
    required this.alertaMinimo,
    required this.troca,
    required this.temRegistro,
  });

  factory _LinhaEstoque.deEstoque(ItemEstoque i) => _LinhaEstoque(
        produtoId: i.produtoId,
        nome: i.produtoNome,
        cheios: i.cheios,
        vazios: i.vazios,
        alertaMinimo: i.alertaMinimo,
        troca: i.trocaVasilhame,
        temRegistro: true,
      );

  factory _LinhaEstoque.semRegistro(Produto p) => _LinhaEstoque(
        produtoId: p.id,
        nome: p.nome,
        cheios: 0,
        vazios: 0,
        alertaMinimo: 0,
        troca: p.trocaVasilhame,
        temRegistro: false,
      );

  final String produtoId;
  final String nome;
  final int cheios;
  final int vazios;
  final int alertaMinimo;
  final bool troca;
  final bool temRegistro;

  bool get negativo => cheios < 0 || vazios < 0;
  bool get baixo => alertaMinimo > 0 && cheios <= alertaMinimo;
}

class _Movimento {
  const _Movimento(this.tipo, this.cheios, this.vazios, this.motivo);

  final TipoMovimentoEstoque tipo;
  final int cheios;
  final int vazios;
  final String motivo;
}

class _DialogoMovimento extends StatefulWidget {
  const _DialogoMovimento({required this.linha});

  final _LinhaEstoque linha;

  @override
  State<_DialogoMovimento> createState() => _DialogoMovimentoState();
}

class _DialogoMovimentoState extends State<_DialogoMovimento> {
  TipoMovimentoEstoque _tipo = TipoMovimentoEstoque.entrada;
  final _cheios = TextEditingController();
  final _vazios = TextEditingController();
  final _motivo = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _cheios.dispose();
    _vazios.dispose();
    _motivo.dispose();
    super.dispose();
  }

  String get _ajuda => switch (_tipo) {
        TipoMovimentoEstoque.entrada =>
          'Chegou carga: some os cheios que chegaram e os vazios que foram devolvidos ao fornecedor.',
        TipoMovimentoEstoque.saida =>
          'Saída sem venda: perda, vazamento, devolução.',
        TipoMovimentoEstoque.ajuste =>
          'Correção: use número negativo para tirar (ex.: -2).',
        TipoMovimentoEstoque.contagem =>
          'Digite quanto tem agora, contado na central.',
        TipoMovimentoEstoque.entregaPedido => '',
      };

  void _confirmar() {
    final permiteNegativo = _tipo == TipoMovimentoEstoque.ajuste;
    int? ler(TextEditingController c) {
      final texto = c.text.trim();
      if (texto.isEmpty) {
        return 0;
      }
      final valor = int.tryParse(texto);
      if (valor == null || (!permiteNegativo && valor < 0)) {
        return null;
      }
      return valor;
    }

    final cheios = ler(_cheios);
    final vazios = widget.linha.troca ? ler(_vazios) : 0;
    if (cheios == null || vazios == null) {
      setState(() => _erro = 'Quantidades inválidas.');
      return;
    }
    if (_tipo != TipoMovimentoEstoque.contagem && cheios == 0 && vazios == 0) {
      setState(() => _erro = 'Informe alguma quantidade.');
      return;
    }
    if (_motivo.text.trim().isEmpty) {
      setState(() => _erro = 'Escreva o motivo.');
      return;
    }
    Navigator.of(context)
        .pop(_Movimento(_tipo, cheios, vazios, _motivo.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final contagem = _tipo == TipoMovimentoEstoque.contagem;
    return AlertDialog(
      title: Text(widget.linha.nome),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Agora: ${widget.linha.cheios} cheios'
                '${widget.linha.troca ? ', ${widget.linha.vazios} vazios' : ''}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tipo in TipoMovimentoEstoque.values)
                  if (tipo != TipoMovimentoEstoque.entregaPedido)
                    ChoiceChip(
                      label: Text(tipo.rotulo),
                      selected: _tipo == tipo,
                      onSelected: (_) => setState(() => _tipo = tipo),
                    ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_ajuda),
            const SizedBox(height: 12),
            TextField(
              controller: _cheios,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))
              ],
              decoration: InputDecoration(
                  labelText: contagem ? 'Cheios contados' : 'Cheios'),
            ),
            if (widget.linha.troca) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _vazios,
                keyboardType:
                    const TextInputType.numberWithOptions(signed: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))
                ],
                decoration: InputDecoration(
                    labelText: contagem ? 'Vazios contados' : 'Vazios'),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _motivo,
              maxLength: 200,
              decoration:
                  const InputDecoration(labelText: 'Motivo (obrigatório)'),
            ),
            if (_erro != null)
              Text(_erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Voltar')),
        FilledButton(onPressed: _confirmar, child: const Text('Registrar')),
      ],
    );
  }
}
