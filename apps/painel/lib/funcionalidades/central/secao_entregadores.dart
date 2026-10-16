import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

final _provedorEntregadores =
    FutureProvider.autoDispose.family<List<Entregador>, String>(
  (ref, centralId) => ref.watch(provedorGestao).entregadores(centralId),
);

/// Cadastro de entregadores da central (sem login no piloto).
class SecaoEntregadores extends ConsumerWidget {
  const SecaoEntregadores({required this.centralId, super.key});

  final String centralId;

  Future<void> _editar(BuildContext context, WidgetRef ref,
      [Entregador? entregador]) async {
    final dados =
        await showDialog<({String nome, String telefone, bool ativo})>(
      context: context,
      builder: (_) => _DialogoEntregador(entregador: entregador),
    );
    if (dados == null || !context.mounted) {
      return;
    }
    try {
      await ref.read(provedorGestao).salvarEntregador(
            centralId: centralId,
            id: entregador?.id,
            nome: dados.nome,
            telefone: dados.telefone,
            ativo: dados.ativo,
          );
      ref.invalidate(_provedorEntregadores(centralId));
      if (context.mounted) {
        mostrarMensagem(context, 'Entregador salvo.');
      }
    } catch (erro) {
      if (context.mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entregadores = ref.watch(_provedorEntregadores(centralId));
    return entregadores.when(
      loading: () => const Carregando(),
      error: (erro, _) => EstadoErro(
        mensagem: mensagemDeErro(erro),
        aoTentarNovamente: () =>
            ref.invalidate(_provedorEntregadores(centralId)),
      ),
      data: (lista) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LarguraMaxima(
            largura: 800,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TituloSecao(
                  'Entregadores',
                  acao: FilledButton.icon(
                    onPressed: () => _editar(context, ref),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Novo'),
                  ),
                ),
                const Text(
                    'Escolha quem leva cada pedido no detalhe do pedido.'),
                const SizedBox(height: 12),
                if (lista.isEmpty) const Text('Nenhum entregador cadastrado.'),
                for (final e in lista)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.delivery_dining,
                        color: e.ativo ? null : Theme.of(context).disabledColor,
                      ),
                      title: Text(e.nome),
                      subtitle: Text(
                        '${e.telefone.isEmpty ? 'Sem telefone' : Validacoes.formatarTelefone(e.telefone)}'
                        '${e.ativo ? '' : ' · desativado'}',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editar(context, ref, e),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogoEntregador extends StatefulWidget {
  const _DialogoEntregador({this.entregador});

  final Entregador? entregador;

  @override
  State<_DialogoEntregador> createState() => _DialogoEntregadorState();
}

class _DialogoEntregadorState extends State<_DialogoEntregador> {
  final _formulario = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.entregador?.nome ?? '');
  late final _telefone = TextEditingController(
    text: Validacoes.formatarTelefone(widget.entregador?.telefone ?? ''),
  );
  late bool _ativo = widget.entregador?.ativo ?? true;

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.entregador == null ? 'Novo entregador' : 'Editar entregador'),
      content: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: Validacoes.nome,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9() \-]'))
              ],
              decoration:
                  const InputDecoration(labelText: 'Celular (opcional)'),
              validator: Validacoes.telefoneOpcional,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _ativo,
              title: const Text('Ativo'),
              onChanged: (v) => setState(() => _ativo = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Voltar')),
        FilledButton(
          onPressed: () {
            if (_formulario.currentState?.validate() ?? false) {
              Navigator.of(context).pop((
                nome: _nome.text.trim(),
                telefone: _telefone.text,
                ativo: _ativo
              ));
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
