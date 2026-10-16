import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

/// Resumo e forma de pagamento. O botão "Confirmar pedido" envia ao servidor,
/// que confere preços, vaga no horário e calcula o total.
class TelaFinalizar extends ConsumerStatefulWidget {
  const TelaFinalizar({super.key});

  @override
  ConsumerState<TelaFinalizar> createState() => _TelaFinalizarState();
}

class _TelaFinalizarState extends ConsumerState<TelaFinalizar> {
  final _troco = TextEditingController();
  final _observacao = TextEditingController();
  bool _enviando = false;
  String? _erroTroco;

  @override
  void initState() {
    super.initState();
    final dados = ref.read(provedorFinalizacao);
    if (dados.trocoPara != null) {
      _troco.text = dados.trocoPara!.formatarParaEdicao();
    }
    _observacao.text = dados.observacao;
  }

  @override
  void dispose() {
    _troco.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final dados = ref.read(provedorFinalizacao);
    final carrinho = ref.read(provedorCarrinho);
    final endereco = ref.read(provedorEnderecoAtual).valueOrNull;
    final atendimento = ref.read(provedorAtendimento).valueOrNull;
    final horario = dados.horario;
    if (endereco?.id == null || atendimento == null || horario == null || carrinho.vazio) {
      mostrarMensagem(context, 'Faltam informações do pedido. Volte e confira.', erro: true);
      return;
    }

    Dinheiro? troco;
    if (dados.formaPagamento == FormaPagamento.dinheiro && _troco.text.trim().isNotEmpty) {
      troco = Dinheiro.lerReais(_troco.text);
      final total = carrinho.subtotal + atendimento.taxaEntrega;
      if (troco == null) {
        setState(() => _erroTroco = 'Digite só o valor, por exemplo 150 ou 150,00.');
        return;
      }
      if (troco < total) {
        setState(() => _erroTroco = 'O valor para troco precisa ser maior que o total.');
        return;
      }
    }
    setState(() {
      _erroTroco = null;
      _enviando = true;
    });

    try {
      final criado = await ref.read(provedorRepositorioPedidos).criarPedido(
            enderecoId: endereco!.id!,
            horario: horario,
            formaPagamento: dados.formaPagamento,
            carrinho: carrinho,
            chaveIdempotencia: dados.chaveIdempotencia,
            trocoPara: troco,
            observacao: _observacao.text,
          );
      ref.read(provedorCarrinho.notifier).limpar();
      ref.read(provedorFinalizacao.notifier).recomecar();
      ref.invalidate(provedorMeusPedidos);
      if (mounted) {
        context.go('/pedido/${criado.id}');
      }
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dados = ref.watch(provedorFinalizacao);
    final carrinho = ref.watch(provedorCarrinho);
    final endereco = ref.watch(provedorEnderecoAtual).valueOrNull;
    final atendimento = ref.watch(provedorAtendimento).valueOrNull;
    final taxa = atendimento?.taxaEntrega ?? Dinheiro.zero;
    final horario = dados.horario;
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar pedido')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(endereco?.apelido ?? 'Endereço'),
              subtitle: Text(endereco == null ? '' : '${endereco.linhaPrincipal}\n${endereco.cidade}/${endereco.uf}'),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(
                horario == null
                    ? 'Escolha o horário'
                    : '${Datas.rotuloDia(horario.data)}, ${horario.intervalo}',
              ),
              subtitle: Text(atendimento?.centralNome ?? ''),
              trailing: TextButton(onPressed: () => context.pop(), child: const Text('Trocar')),
            ),
          ),
          const TituloSecao('Como vai pagar na entrega?'),
          for (final forma in FormaPagamento.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                color: dados.formaPagamento == forma ? tema.colorScheme.primaryContainer : null,
                child: ListTile(
                  leading: Icon(
                    switch (forma) {
                      FormaPagamento.dinheiro => Icons.payments_outlined,
                      FormaPagamento.cartaoNaEntrega => Icons.credit_card,
                      FormaPagamento.pixNaEntrega => Icons.qr_code_2,
                    },
                  ),
                  title: Text(forma.rotulo),
                  trailing: dados.formaPagamento == forma ? const Icon(Icons.check_circle) : null,
                  onTap: () => ref.read(provedorFinalizacao.notifier).escolherPagamento(forma),
                ),
              ),
            ),
          if (dados.formaPagamento == FormaPagamento.dinheiro) ...[
            const SizedBox(height: 4),
            TextField(
              controller: _troco,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
              decoration: InputDecoration(
                labelText: 'Precisa de troco para quanto? (opcional)',
                prefixText: 'R\$ ',
                errorText: _erroTroco,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _observacao,
            maxLength: 300,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (texto) => ref.read(provedorFinalizacao.notifier).definirObservacao(texto),
            decoration: const InputDecoration(
              labelText: 'Observação para o entregador (opcional)',
              hintText: 'Ex.: tocar a campainha, casa dos fundos',
            ),
          ),
          const TituloSecao('Resumo'),
          for (final linha in carrinho.itens)
            LinhaValor(
              rotulo: '${linha.quantidade}x ${linha.item.produto.nome}',
              valor: linha.total.formatarEmReais(),
            ),
          LinhaValor(rotulo: 'Entrega', valor: taxa.ehZero ? 'Grátis' : taxa.formatarEmReais()),
          const Divider(),
          LinhaValor(
            rotulo: 'Total a pagar na entrega',
            valor: (carrinho.subtotal + taxa).formatarEmReais(),
            destaque: true,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: BotaoPrincipal(
            icone: Icons.check_circle_outline,
            rotulo: 'Confirmar pedido',
            carregando: _enviando,
            aoPressionar: horario == null || carrinho.vazio ? null : _confirmar,
          ),
        ),
      ),
    );
  }
}
