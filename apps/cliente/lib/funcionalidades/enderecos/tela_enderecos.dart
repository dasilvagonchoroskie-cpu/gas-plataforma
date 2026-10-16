import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

/// Lista de endereços: tocar escolhe onde entregar.
class TelaEnderecos extends ConsumerWidget {
  const TelaEnderecos({super.key});

  Future<void> _excluir(BuildContext context, WidgetRef ref, Endereco endereco) async {
    final certeza = await confirmar(
      context,
      titulo: 'Apagar endereço?',
      mensagem: 'O endereço "${endereco.apelido}" será apagado.',
      rotuloConfirmar: 'Apagar',
      perigoso: true,
    );
    if (!certeza) {
      return;
    }
    try {
      await ref.read(provedorRepositorioEnderecos).excluir(endereco.id!);
      if (ref.read(provedorIdEnderecoEscolhido) == endereco.id) {
        await ref.read(provedorIdEnderecoEscolhido.notifier).escolher(null);
      }
      ref.invalidate(provedorEnderecos);
    } catch (erro) {
      if (context.mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enderecos = ref.watch(provedorEnderecos);
    final atual = ref.watch(provedorEnderecoAtual).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Meus endereços')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/enderecos/novo'),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Novo endereço'),
      ),
      body: enderecos.when(
        loading: () => const Carregando(),
        error: (erro, _) => EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () => ref.invalidate(provedorEnderecos),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return EstadoVazio(
              icone: Icons.home_outlined,
              titulo: 'Nenhum endereço ainda',
              mensagem: 'Cadastre onde você quer receber o gás e a água.',
              rotuloAcao: 'Cadastrar endereço',
              aoAcionar: () => context.push('/enderecos/novo'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: lista.length,
            separatorBuilder: (context, indice) => const SizedBox(height: 12),
            itemBuilder: (context, indice) {
              final endereco = lista[indice];
              final escolhido = endereco.id == atual?.id;
              return Card(
                child: ListTile(
                  leading: Icon(
                    escolhido ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: escolhido ? Theme.of(context).colorScheme.primary : null,
                  ),
                  title: Text(endereco.apelido),
                  subtitle: Text(
                    '${endereco.linhaPrincipal}\n${endereco.cidade}/${endereco.uf} · '
                    'CEP ${Validacoes.formatarCep(endereco.cep)}',
                  ),
                  isThreeLine: true,
                  onTap: () async {
                    await ref.read(provedorIdEnderecoEscolhido.notifier).escolher(endereco.id);
                    if (context.mounted) {
                      context.pop();
                    }
                  },
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Opções',
                    onSelected: (opcao) {
                      if (opcao == 'editar') {
                        context.push('/enderecos/${endereco.id}');
                      } else {
                        _excluir(context, ref, endereco);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(value: 'apagar', child: Text('Apagar')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
