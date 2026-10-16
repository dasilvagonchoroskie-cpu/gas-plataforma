import 'dart:math';

import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

/// Gera uma senha provisória fácil de ditar (sem 0/O, 1/l/I).
String gerarSenhaTemporaria([Random? gerador]) {
  const letras = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz';
  const numeros = '23456789';
  final aleatorio = gerador ?? Random.secure();
  final partes = [
    for (var i = 0; i < 6; i++) letras[aleatorio.nextInt(letras.length)],
    for (var i = 0; i < 4; i++) numeros[aleatorio.nextInt(numeros.length)],
  ];
  return partes.join();
}

typedef _Filtro = ({PapelPerfil? papel, String busca});

final _provedorUsuarios = FutureProvider.autoDispose.family<List<Perfil>, _Filtro>(
  (ref, filtro) => ref.watch(provedorGestao).usuarios(papel: filtro.papel, busca: filtro.busca),
);

/// Quem acessa o sistema: clientes, operadores das centrais e administradores.
class SecaoUsuarios extends ConsumerStatefulWidget {
  const SecaoUsuarios({super.key});

  @override
  ConsumerState<SecaoUsuarios> createState() => _SecaoUsuariosState();
}

class _SecaoUsuariosState extends ConsumerState<SecaoUsuarios> {
  final _busca = TextEditingController();
  PapelPerfil? _papel = PapelPerfil.operadorCentral;
  String _termo = '';

  _Filtro get _filtro => (papel: _papel, busca: _termo);

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

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
      ref.invalidate(_provedorUsuarios);
    }
  }

  Future<void> _novo() async {
    final criado = await showDialog<({String email, String senha})>(
      context: context,
      builder: (_) => const _DialogoNovoUsuario(),
    );
    if (criado == null || !mounted) {
      return;
    }
    ref.invalidate(_provedorUsuarios);
    await _mostrarSenha(
      titulo: 'Usuário criado',
      mensagem: 'Passe estes dados para a pessoa. Ela pode trocar a senha depois, no perfil.',
      email: criado.email,
      senha: criado.senha,
    );
  }

  Future<void> _mostrarSenha({
    required String titulo,
    required String mensagem,
    required String senha,
    String? email,
  }) {
    return showDialog<void>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mensagem),
            const SizedBox(height: 12),
            if (email != null) SelectableText('E-mail: $email', style: const TextStyle(fontSize: 18)),
            SelectableText(
              'Senha: $senha',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: email == null ? senha : 'E-mail: $email\nSenha: $senha'),
              );
              if (contexto.mounted) {
                mostrarMensagem(contexto, 'Copiado.');
              }
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
          ),
          FilledButton(onPressed: () => Navigator.of(contexto).pop(), child: const Text('Pronto')),
        ],
      ),
    );
  }

  Future<void> _opcoes(Perfil usuario) async {
    final souEu = usuario.id == ref.read(provedorUsuarioId);
    final escolha = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(usuario.nome, style: Theme.of(contexto).textTheme.titleMedium),
              subtitle: Text(usuario.email ?? Validacoes.formatarTelefone(usuario.telefone)),
            ),
            if (!souEu)
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Mudar papel ou central'),
                onTap: () => Navigator.of(contexto).pop('papel'),
              ),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Criar senha nova'),
              onTap: () => Navigator.of(contexto).pop('senha'),
            ),
            if (!souEu)
              ListTile(
                leading: Icon(usuario.ativo ? Icons.block : Icons.check_circle_outline),
                title: Text(usuario.ativo ? 'Desativar acesso' : 'Reativar acesso'),
                onTap: () => Navigator.of(contexto).pop('ativo'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || escolha == null) {
      return;
    }
    final gestao = ref.read(provedorGestao);
    switch (escolha) {
      case 'papel':
        final novo = await showDialog<({PapelPerfil papel, String? centralId})>(
          context: context,
          builder: (_) => _DialogoPapel(usuario: usuario),
        );
        if (novo != null) {
          await _executar(
            () => gestao.mudarPapel(usuario.id, novo.papel, centralId: novo.centralId),
            'Papel atualizado.',
          );
        }
      case 'senha':
        final certeza = await confirmar(
          context,
          titulo: 'Criar senha nova para ${usuario.primeiroNome}?',
          mensagem: 'A senha atual deixa de funcionar. Você vai ver a nova senha para passar à pessoa.',
          rotuloConfirmar: 'Criar senha',
        );
        if (!certeza) {
          return;
        }
        final senha = gerarSenhaTemporaria();
        try {
          await gestao.redefinirSenha(usuario.id, senha);
          if (mounted) {
            await _mostrarSenha(
              titulo: 'Senha nova',
              mensagem: 'Passe esta senha para ${usuario.primeiroNome}.',
              email: usuario.email,
              senha: senha,
            );
          }
        } catch (erro) {
          if (mounted) {
            mostrarMensagem(context, mensagemDeErro(erro), erro: true);
          }
        }
      case 'ativo':
        final certeza = await confirmar(
          context,
          titulo: usuario.ativo ? 'Desativar ${usuario.primeiroNome}?' : 'Reativar ${usuario.primeiroNome}?',
          mensagem: usuario.ativo
              ? 'A pessoa não consegue mais entrar no aplicativo nem no painel.'
              : 'A pessoa volta a entrar com o e-mail e a senha dela.',
          rotuloConfirmar: usuario.ativo ? 'Desativar' : 'Reativar',
          perigoso: usuario.ativo,
        );
        if (certeza) {
          await _executar(
            () => gestao.definirAtivo(usuario.id, !usuario.ativo),
            usuario.ativo ? 'Acesso desativado.' : 'Acesso reativado.',
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarios = ref.watch(_provedorUsuarios(_filtro));
    final centrais = {
      for (final c in ref.watch(provedorCentrais).valueOrNull ?? const <Central>[]) c.id: c.nome,
    };
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _novo,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Novo usuário'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _busca,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Buscar por nome, e-mail ou telefone',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _termo.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar',
                            onPressed: () => setState(() {
                              _busca.clear();
                              _termo = '';
                            }),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onSubmitted: (texto) => setState(() => _termo = texto.trim()),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final opcao in <(String, PapelPerfil?)>[
                      ('Operadores', PapelPerfil.operadorCentral),
                      ('Administradores', PapelPerfil.dono),
                      ('Clientes', PapelPerfil.cliente),
                      ('Todos', null),
                    ])
                      ChoiceChip(
                        label: Text(opcao.$1),
                        selected: _papel == opcao.$2,
                        onSelected: (_) => setState(() => _papel = opcao.$2),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: usuarios.when(
              loading: () => const Carregando(),
              error: (erro, _) => EstadoErro(
                mensagem: mensagemDeErro(erro),
                aoTentarNovamente: () => ref.invalidate(_provedorUsuarios),
              ),
              data: (lista) {
                if (lista.isEmpty) {
                  return const EstadoVazio(icone: Icons.group_outlined, titulo: 'Ninguém encontrado');
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final u = lista[i];
                    final central = u.centralId == null ? null : centrais[u.centralId];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text(u.nome.isEmpty ? '?' : u.nome[0].toUpperCase())),
                        title: Text(u.nome.isEmpty ? '(sem nome)' : u.nome),
                        subtitle: Text(
                          [
                            '${u.papel.rotulo}${central == null ? '' : ' · $central'}',
                            if (u.email != null) u.email!,
                            if (u.telefone.isNotEmpty) Validacoes.formatarTelefone(u.telefone),
                            if (!u.ativo) 'ACESSO DESATIVADO',
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.more_vert),
                        onTap: () => _opcoes(u),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Escolha de papel e, para operador, da central.
class _CampoPapelCentral extends ConsumerWidget {
  const _CampoPapelCentral({
    required this.papeis,
    required this.papel,
    required this.centralId,
    required this.aoMudarPapel,
    required this.aoMudarCentral,
  });

  final List<PapelPerfil> papeis;
  final PapelPerfil papel;
  final String? centralId;
  final ValueChanged<PapelPerfil> aoMudarPapel;
  final ValueChanged<String?> aoMudarCentral;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centrais = ref.watch(provedorCentrais).valueOrNull ?? const <Central>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RadioGroup<PapelPerfil>(
          groupValue: papel,
          onChanged: (v) => aoMudarPapel(v ?? papel),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final p in papeis)
                RadioListTile<PapelPerfil>(
                  value: p,
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.rotulo),
                  subtitle: Text(switch (p) {
                    PapelPerfil.operadorCentral => 'Atende os pedidos de uma central',
                    PapelPerfil.dono => 'Vê e controla tudo, todas as centrais',
                    PapelPerfil.cliente => 'Só faz pedidos pelo aplicativo',
                    PapelPerfil.entregador => 'Entregador',
                  }),
                ),
            ],
          ),
        ),
        if (papel == PapelPerfil.operadorCentral) ...[
          const SizedBox(height: 8),
          DropdownMenu<String>(
            initialSelection: centralId,
            label: const Text('Central'),
            expandedInsets: EdgeInsets.zero,
            onSelected: aoMudarCentral,
            dropdownMenuEntries: [
              for (final c in centrais) DropdownMenuEntry(value: c.id, label: c.nome),
            ],
          ),
        ],
      ],
    );
  }
}

class _DialogoPapel extends StatefulWidget {
  const _DialogoPapel({required this.usuario});

  final Perfil usuario;

  @override
  State<_DialogoPapel> createState() => _DialogoPapelState();
}

class _DialogoPapelState extends State<_DialogoPapel> {
  late PapelPerfil _papel =
      widget.usuario.papel == PapelPerfil.entregador ? PapelPerfil.cliente : widget.usuario.papel;
  late String? _centralId = widget.usuario.centralId;
  String? _erro;

  void _confirmar() {
    if (_papel == PapelPerfil.operadorCentral && _centralId == null) {
      setState(() => _erro = 'Escolha a central do operador.');
      return;
    }
    Navigator.of(context).pop((
      papel: _papel,
      centralId: _papel == PapelPerfil.operadorCentral ? _centralId : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Papel de ${widget.usuario.primeiroNome}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CampoPapelCentral(
              papeis: const [PapelPerfil.cliente, PapelPerfil.operadorCentral, PapelPerfil.dono],
              papel: _papel,
              centralId: _centralId,
              aoMudarPapel: (p) => setState(() => _papel = p),
              aoMudarCentral: (id) => setState(() => _centralId = id),
            ),
            if (_erro != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Voltar')),
        FilledButton(onPressed: _confirmar, child: const Text('Salvar')),
      ],
    );
  }
}

class _DialogoNovoUsuario extends ConsumerStatefulWidget {
  const _DialogoNovoUsuario();

  @override
  ConsumerState<_DialogoNovoUsuario> createState() => _DialogoNovoUsuarioState();
}

class _DialogoNovoUsuarioState extends ConsumerState<_DialogoNovoUsuario> {
  final _formulario = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  PapelPerfil _papel = PapelPerfil.operadorCentral;
  String? _centralId;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _telefone.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    if (!(_formulario.currentState?.validate() ?? false)) {
      return;
    }
    if (_papel == PapelPerfil.operadorCentral && _centralId == null) {
      setState(() => _erro = 'Escolha a central do operador.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    final senha = gerarSenhaTemporaria();
    final email = _email.text.trim().toLowerCase();
    try {
      await ref.read(provedorGestao).criarUsuario(
            nome: _nome.text,
            email: email,
            telefone: _telefone.text,
            senha: senha,
            papel: _papel,
            centralId: _papel == PapelPerfil.operadorCentral ? _centralId : null,
          );
      if (mounted) {
        Navigator.of(context).pop((email: email, senha: senha));
      }
    } catch (erro) {
      if (mounted) {
        setState(() => _erro = mensagemDeErro(erro));
      }
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo usuário do painel'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formulario,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nome,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome completo'),
                  validator: Validacoes.nome,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'E-mail (usado para entrar)'),
                  validator: Validacoes.email,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Celular com DDD (opcional)'),
                  validator: Validacoes.telefoneOpcional,
                ),
                const SizedBox(height: 12),
                _CampoPapelCentral(
                  papeis: const [PapelPerfil.operadorCentral, PapelPerfil.dono],
                  papel: _papel,
                  centralId: _centralId,
                  aoMudarPapel: (p) => setState(() => _papel = p),
                  aoMudarCentral: (id) => setState(() => _centralId = id),
                ),
                const SizedBox(height: 12),
                const Text('Uma senha provisória será criada e mostrada na tela.'),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: _salvando ? null : _criar,
          child: _salvando
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Criar'),
        ),
      ],
    );
  }
}
