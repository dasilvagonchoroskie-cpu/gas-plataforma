import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleo/nucleo.dart';

import '../../app.dart';
import '../../estado/provedores.dart';

class TelaEntrar extends ConsumerStatefulWidget {
  const TelaEntrar({super.key});

  @override
  ConsumerState<TelaEntrar> createState() => _TelaEntrarState();
}

class _TelaEntrarState extends ConsumerState<TelaEntrar> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;
  bool _mostrarSenha = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!(_formulario.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _carregando = true);
    try {
      await ref.read(provedorConta).entrar(email: _email.text, senha: _senha.text);
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: LarguraMaxima(
              largura: 440,
              child: Form(
                key: _formulario,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.local_fire_department_rounded, size: 64, color: tema.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        nomeDoApp,
                        textAlign: TextAlign.center,
                        style: tema.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Peça gás e água sem sair de casa.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: Validacoes.email,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _senha,
                        obscureText: !_mostrarSenha,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _entrar(),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _mostrarSenha ? 'Esconder senha' : 'Mostrar senha',
                            icon: Icon(_mostrarSenha ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                          ),
                        ),
                        validator: (valor) =>
                            (valor ?? '').isEmpty ? 'Digite sua senha.' : null,
                      ),
                      const SizedBox(height: 24),
                      BotaoPrincipal(
                        rotulo: 'Entrar',
                        icone: Icons.login,
                        carregando: _carregando,
                        aoPressionar: _entrar,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.push('/recuperar-senha'),
                        child: const Text('Esqueci minha senha'),
                      ),
                      const Divider(height: 32),
                      const Text('Ainda não tem conta?', textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      BotaoPrincipal(
                        rotulo: 'Criar minha conta',
                        icone: Icons.person_add_alt_1,
                        secundario: true,
                        aoPressionar: () => context.push('/cadastro'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
