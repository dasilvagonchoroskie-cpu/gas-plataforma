import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleo/nucleo.dart';

import '../../comum/links.dart';
import '../../estado/provedores.dart';

class AbaPerfil extends ConsumerWidget {
  const AbaPerfil({super.key});

  Future<void> _editar(BuildContext context, WidgetRef ref, Perfil perfil) async {
    final salvou = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogoEditarPerfil(perfil: perfil),
    );
    if (salvou == true) {
      ref.invalidate(provedorPerfil);
      if (context.mounted) {
        mostrarMensagem(context, 'Dados atualizados.');
      }
    }
  }

  Future<void> _sair(BuildContext context, WidgetRef ref) async {
    final certeza = await confirmar(
      context,
      titulo: 'Sair da conta?',
      mensagem: 'Para pedir de novo, você vai precisar entrar com e-mail e senha.',
      rotuloConfirmar: 'Sair',
    );
    if (certeza) {
      ref.read(provedorCarrinho.notifier).limpar();
      await ref.read(provedorConta).sair();
    }
  }

  Future<void> _excluirConta(BuildContext context, WidgetRef ref) async {
    final primeira = await confirmar(
      context,
      titulo: 'Excluir minha conta',
      mensagem: 'Seus dados pessoais e endereços serão apagados e você não poderá mais entrar '
          'com este e-mail. O histórico de vendas fica sem seu nome, só para os relatórios da revenda.',
      rotuloConfirmar: 'Continuar',
      perigoso: true,
    );
    if (!primeira || !context.mounted) {
      return;
    }
    final segunda = await confirmar(
      context,
      titulo: 'Tem certeza?',
      mensagem: 'Esta ação não pode ser desfeita.',
      rotuloConfirmar: 'Excluir para sempre',
      perigoso: true,
    );
    if (!segunda) {
      return;
    }
    try {
      await ref.read(provedorConta).excluirConta();
      ref.read(provedorCarrinho.notifier).limpar();
      await ref.read(provedorIdEnderecoEscolhido.notifier).escolher(null);
    } catch (erro) {
      if (context.mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(provedorPerfil);
    final atendimento = ref.watch(provedorAtendimento).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Meu perfil')),
      body: perfil.when(
        loading: () => const Carregando(),
        error: (erro, _) => EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () => ref.invalidate(provedorPerfil),
        ),
        data: (p) {
          if (p == null) {
            return const Carregando();
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(p.nome),
                  subtitle: Text('${Validacoes.formatarTelefone(p.telefone)}\n${p.email ?? ''}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Editar meus dados',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editar(context, ref, p),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: const Text('Meus endereços'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/enderecos'),
                    ),
                    if (atendimento?.whatsapp != null)
                      ListTile(
                        leading: const Icon(Icons.chat_outlined),
                        title: Text('Falar com a ${atendimento?.centralNome ?? 'central'}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => abrirWhatsapp(
                          context,
                          numero: atendimento?.whatsapp,
                          mensagem: 'Olá! Vim pelo aplicativo.',
                        ),
                      ),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Termos de uso'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => abrirLink(context, enderecoTermos),
                    ),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Política de privacidade'),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => abrirLink(context, enderecoPrivacidade),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              BotaoPrincipal(
                icone: Icons.logout,
                rotulo: 'Sair da conta',
                secundario: true,
                aoPressionar: () => _sair(context, ref),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _excluirConta(context, ref),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Excluir minha conta'),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DialogoEditarPerfil extends ConsumerStatefulWidget {
  const _DialogoEditarPerfil({required this.perfil});

  final Perfil perfil;

  @override
  ConsumerState<_DialogoEditarPerfil> createState() => _DialogoEditarPerfilState();
}

class _DialogoEditarPerfilState extends ConsumerState<_DialogoEditarPerfil> {
  final _formulario = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.perfil.nome);
  late final _telefone =
      TextEditingController(text: Validacoes.formatarTelefone(widget.perfil.telefone));
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!(_formulario.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _salvando = true);
    try {
      await ref.read(provedorConta).atualizarPerfil(nome: _nome.text, telefone: _telefone.text);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Meus dados'),
      content: Form(
        key: _formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome completo'),
              validator: Validacoes.nome,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9() \-]'))],
              decoration: const InputDecoration(labelText: 'Celular com DDD'),
              validator: Validacoes.celular,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Voltar')),
        FilledButton(
          onPressed: _salvando ? null : _salvar,
          child: Text(_salvando ? 'Salvando...' : 'Salvar'),
        ),
      ],
    );
  }
}
