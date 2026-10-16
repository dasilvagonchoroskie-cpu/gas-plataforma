import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

/// "Meu crediário": limite, quanto deve, quanto está livre e o extrato.
class TelaCrediario extends ConsumerWidget {
  const TelaCrediario({super.key});

  Future<void> _recarregar(WidgetRef ref) async {
    ref
      ..invalidate(provedorMinhaFicha)
      ..invalidate(provedorMeuExtrato);
    await ref.read(provedorMeuCredito.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credito = ref.watch(provedorMeuCredito);
    return Scaffold(
      appBar: AppBar(title: const Text('Meu crediário')),
      body: credito.when(
        loading: () => const Carregando(),
        error: (erro, _) => EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () => ref.invalidate(provedorMeuCredito),
        ),
        data: (resumo) {
          if (resumo == null || !resumo.temFicha) {
            return EstadoVazio(
              icone: Icons.badge_outlined,
              titulo: 'Preencha sua ficha',
              mensagem:
                  'O crediário é liberado pela loja depois que ela analisar sua ficha de cadastro.',
              rotuloAcao: 'Preencher ficha',
              aoAcionar: () => context.push('/ficha'),
            );
          }
          return RefreshIndicator(
            onRefresh: () => _recarregar(ref),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                LarguraMaxima(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CartaoSituacao(resumo: resumo),
                      const TituloSecao('Extrato'),
                      const _Extrato(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CartaoSituacao extends StatelessWidget {
  const _CartaoSituacao({required this.resumo});

  final ResumoCredito resumo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final String aviso;
    if (resumo.status == StatusFicha.pendente) {
      aviso =
          'Sua ficha está em análise. Quando for aprovada, o crediário aparece na hora de pagar.';
    } else if (resumo.status == StatusFicha.recusada) {
      aviso =
          'Sua ficha não foi aprovada. Veja o motivo em "Minha ficha de cadastro".';
    } else if (resumo.bloqueado) {
      aviso = 'Seu crediário está bloqueado. Fale com a loja.';
    } else {
      aviso =
          'Escolha "Crediário (fiado)" na hora de pagar. O valor entra na sua conta quando o pedido é entregue.';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Livre para comprar', style: tema.textTheme.bodyLarge),
            Text(
              resumo.disponivel.formatarEmReais(),
              style: tema.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Divider(height: 24),
            LinhaValor(
                rotulo: 'Limite', valor: resumo.limite.formatarEmReais()),
            LinhaValor(
                rotulo: 'Você deve',
                valor: resumo.devido.formatarEmReais(),
                destaque: true),
            if (!resumo.reservado.ehZero)
              LinhaValor(
                  rotulo: 'Pedidos fiado a caminho',
                  valor: resumo.reservado.formatarEmReais()),
            const SizedBox(height: 10),
            Text(aviso),
          ],
        ),
      ),
    );
  }
}

class _Extrato extends ConsumerWidget {
  const _Extrato();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extrato = ref.watch(provedorMeuExtrato);
    return extrato.when(
      loading: () =>
          const Padding(padding: EdgeInsets.all(24), child: Carregando()),
      error: (erro, _) => Text(mensagemDeErro(erro)),
      data: (lancamentos) {
        if (lancamentos.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Nenhuma compra no fiado ainda.'),
          );
        }
        return Column(
          children: [
            for (final l in lancamentos) LinhaLancamento(lancamento: l),
          ],
        );
      },
    );
  }
}
