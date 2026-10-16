import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';
import 'editor_central.dart';

/// Lista de centrais. O dono cria quantas quiser, em qualquer cidade.
class SecaoCentrais extends ConsumerWidget {
  const SecaoCentrais({super.key});

  Future<void> _abrir(BuildContext context, WidgetRef ref,
      [Central? central]) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditorCentral(central: central)),
    );
    if (salvou == true) {
      ref.invalidate(provedorCentrais);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centrais = ref.watch(provedorCentrais);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(context, ref),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Nova central'),
      ),
      body: centrais.when(
        loading: () => const Carregando(),
        error: (erro, _) => EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () => ref.invalidate(provedorCentrais),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return EstadoVazio(
              icone: Icons.store_outlined,
              titulo: 'Nenhuma central',
              mensagem:
                  'Crie a primeira central. Ela começa desativada até você ligar.',
              rotuloAcao: 'Criar central',
              aoAcionar: () => _abrir(context, ref),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              const Text(
                'O cliente é atendido pela central ativa mais perto dele, dentro do '
                'alcance definido nas faixas de entrega de cada central.',
              ),
              const SizedBox(height: 12),
              for (final c in lista)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.store,
                        color: c.ativa
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).disabledColor,
                      ),
                      title: Text(c.nome),
                      subtitle: Text(
                        '${c.cidadeUf}${c.endereco.isEmpty ? '' : ' · ${c.endereco}'}\n'
                        '${c.ativa ? 'Ativa: recebendo pedidos' : 'Desativada: não aparece para os clientes'}'
                        '${c.whatsapp == null ? '' : ' · WhatsApp ${Validacoes.formatarTelefone(c.whatsapp)}'}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _abrir(context, ref, c),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
