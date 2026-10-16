import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';
import 'painel_dono.dart';

final _provedorPrecos = FutureProvider.autoDispose.family<List<ItemCatalogo>, String>(
  (ref, centralId) => ref.watch(provedorGestao).precos(centralId),
);

/// Preço de cada produto em cada central. Só o dono muda valores; a central
/// pode apenas marcar um produto como "em falta".
class SecaoPrecos extends ConsumerStatefulWidget {
  const SecaoPrecos({super.key});

  @override
  ConsumerState<SecaoPrecos> createState() => _SecaoPrecosState();
}

class _SecaoPrecosState extends ConsumerState<SecaoPrecos> {
  String? _centralId;

  Future<void> _executar(Future<void> Function() acao, String sucesso) async {
    try {
      await acao();
      if (mounted) {
        mostrarMensagem(context, sucesso);
      }
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    } finally {
      ref.invalidate(_provedorPrecos);
    }
  }

  Future<void> _definirPreco(String centralId, Produto produto, {ItemCatalogo? atual}) async {
    final resultado = await showDialog<({Dinheiro preco, bool todas})>(
      context: context,
      builder: (_) => _DialogoPreco(produto: produto, atual: atual?.preco),
    );
    if (resultado == null) {
      return;
    }
    final gestao = ref.read(provedorGestao);
    if (!resultado.todas) {
      await _executar(
        () => gestao.salvarPreco(
          centralId: centralId,
          produtoId: produto.id,
          preco: resultado.preco,
          disponivel: atual?.disponivel ?? true,
        ),
        'Preço salvo.',
      );
      return;
    }
    final centrais = await ref.read(provedorCentrais.future);
    await _executar(() async {
      for (final c in centrais) {
        await gestao.salvarPreco(
          centralId: c.id,
          produtoId: produto.id,
          preco: resultado.preco,
          // Mantém a disponibilidade atual da central que está na tela.
          disponivel: c.id == centralId ? (atual?.disponivel ?? true) : true,
        );
      }
    }, 'Preço aplicado em ${centrais.length} centrais.');
  }

  Future<void> _remover(String centralId, ItemCatalogo item) async {
    final certeza = await confirmar(
      context,
      titulo: 'Tirar "${item.produto.nome}" desta central?',
      mensagem: 'O produto deixa de aparecer para os clientes desta central. '
          'Os pedidos antigos continuam guardados.',
      rotuloConfirmar: 'Tirar',
      perigoso: true,
    );
    if (!certeza) {
      return;
    }
    await _executar(
      () => ref.read(provedorGestao).removerPreco(centralId, item.produto.id),
      'Produto retirado da central.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final centrais = ref.watch(provedorCentrais).valueOrNull ?? const <Central>[];
    final centralId = _centralId ?? (centrais.isEmpty ? null : centrais.first.id);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SeletorCentral(
            selecionada: centralId,
            aoEscolher: (id) => setState(() => _centralId = id),
          ),
        ),
        const SizedBox(height: 12),
        if (centralId == null)
          const EstadoVazio(titulo: 'Nenhuma central cadastrada')
        else
          _ListaPrecos(
            centralId: centralId,
            aoDefinirPreco: (produto, atual) => _definirPreco(centralId, produto, atual: atual),
            aoMudarDisponivel: (item, disponivel) => _executar(
              () => ref.read(provedorGestao).salvarPreco(
                    centralId: centralId,
                    produtoId: item.produto.id,
                    preco: item.preco,
                    disponivel: disponivel,
                  ),
              disponivel ? 'Produto disponível.' : 'Produto marcado como em falta.',
            ),
            aoRemover: (item) => _remover(centralId, item),
          ),
      ],
    );
  }
}

class _ListaPrecos extends ConsumerWidget {
  const _ListaPrecos({
    required this.centralId,
    required this.aoDefinirPreco,
    required this.aoMudarDisponivel,
    required this.aoRemover,
  });

  final String centralId;
  final void Function(Produto produto, ItemCatalogo? atual) aoDefinirPreco;
  final void Function(ItemCatalogo item, bool disponivel) aoMudarDisponivel;
  final void Function(ItemCatalogo item) aoRemover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final precos = ref.watch(_provedorPrecos(centralId));
    final produtos = ref.watch(provedorProdutos).valueOrNull ?? const <Produto>[];
    return precos.when(
      loading: () => const Padding(padding: EdgeInsets.all(32), child: Carregando()),
      error: (erro, _) => EstadoErro(
        mensagem: mensagemDeErro(erro),
        aoTentarNovamente: () => ref.invalidate(_provedorPrecos(centralId)),
      ),
      data: (lista) {
        final comPreco = {for (final i in lista) i.produto.id};
        final semPreco = [
          for (final p in produtos)
            if (p.ativo && !comPreco.contains(p.id)) p,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TituloSecao('Vendidos nesta central'),
            if (lista.isEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Nenhum produto com preço nesta central. Adicione abaixo.'),
              ),
            for (final item in lista)
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.produto.nome, style: Theme.of(context).textTheme.titleMedium),
                            Text(
                              item.produto.ativo
                                  ? (item.disponivel ? 'Disponível' : 'Em falta (cliente não consegue pedir)')
                                  : 'Produto desativado no catálogo',
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => aoDefinirPreco(item.produto, item),
                        child: Text(item.preco.formatarEmReais(), style: const TextStyle(fontSize: 18)),
                      ),
                      Switch(
                        value: item.disponivel,
                        onChanged: (v) => aoMudarDisponivel(item, v),
                      ),
                      IconButton(
                        tooltip: 'Tirar desta central',
                        onPressed: () => aoRemover(item),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                ),
              ),
            if (semPreco.isNotEmpty) ...[
              const TituloSecao('Ainda não vendidos nesta central'),
              for (final p in semPreco)
                Card(
                  child: ListTile(
                    title: Text(p.nome),
                    subtitle: const Text('Sem preço: não aparece para o cliente'),
                    trailing: FilledButton.tonal(
                      onPressed: () => aoDefinirPreco(p, null),
                      child: const Text('Definir preço'),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _DialogoPreco extends StatefulWidget {
  const _DialogoPreco({required this.produto, this.atual});

  final Produto produto;
  final Dinheiro? atual;

  @override
  State<_DialogoPreco> createState() => _DialogoPrecoState();
}

class _DialogoPrecoState extends State<_DialogoPreco> {
  late final _valor = TextEditingController(text: widget.atual?.formatarParaEdicao() ?? '');
  bool _todas = false;
  String? _erro;

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  void _confirmar() {
    final preco = Dinheiro.lerReais(_valor.text);
    if (preco == null || preco.centavos < 1 || preco.centavos > 10000000) {
      setState(() => _erro = 'Digite o valor em reais, ex.: 110,00');
      return;
    }
    Navigator.of(context).pop((preco: preco, todas: _todas));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.produto.nome),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _valor,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(labelText: 'Preço', prefixText: 'R\$ ', errorText: _erro),
            onSubmitted: (_) => _confirmar(),
          ),
          CheckboxListTile(
            value: _todas,
            onChanged: (v) => setState(() => _todas = v ?? false),
            contentPadding: EdgeInsets.zero,
            title: const Text('Usar este preço em todas as centrais'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Voltar')),
        FilledButton(onPressed: _confirmar, child: const Text('Salvar')),
      ],
    );
  }
}
