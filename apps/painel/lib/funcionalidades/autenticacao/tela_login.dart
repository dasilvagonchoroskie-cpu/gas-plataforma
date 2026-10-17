import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';
import '../../tipo_painel.dart';

/// Entrada do painel. Contas do painel são criadas pelo dono (não há cadastro
/// aberto aqui).
class TelaLogin extends ConsumerStatefulWidget {
  const TelaLogin({super.key});

  @override
  ConsumerState<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends ConsumerState<TelaLogin> {
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
      await ref
          .read(provedorConta)
          .entrar(email: _email.text, senha: _senha.text);
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

  Future<void> _esqueci() async {
    final email = await pedirTexto(
      context,
      titulo: 'Esqueci minha senha',
      rotulo: 'E-mail da conta',
      mensagem:
          'Vamos mandar um link para criar uma senha nova. Se não chegar, '
          'peça ao dono da revenda para redefinir sua senha no painel.',
      rotuloConfirmar: 'Enviar link',
      maximo: 254,
    );
    if (email == null || email.isEmpty || !mounted) {
      return;
    }
    if (Validacoes.email(email) != null) {
      mostrarMensagem(context, 'E-mail inválido.', erro: true);
      return;
    }
    try {
      await ref.read(provedorConta).recuperarSenha(email);
      if (mounted) {
        mostrarMensagem(context,
            'Se o e-mail estiver cadastrado, o link chega em alguns minutos.');
      }
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tipo = ref.watch(provedorTipoPainel);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formulario,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: LogoMarca(tamanho: 64)),
                          const SizedBox(height: 12),
                          Text(
                            tipo.nome,
                            textAlign: TextAlign.center,
                            style: tema.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(tipo.descricao, textAlign: TextAlign.center),
                          const SizedBox(height: 28),
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
                            onFieldSubmitted: (_) => _entrar(),
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _mostrarSenha
                                    ? 'Esconder senha'
                                    : 'Mostrar senha',
                                icon: Icon(_mostrarSenha
                                    ? Icons.visibility_off
                                    : Icons.visibility),
                                onPressed: () => setState(
                                    () => _mostrarSenha = !_mostrarSenha),
                              ),
                            ),
                            validator: (v) =>
                                (v ?? '').isEmpty ? 'Digite sua senha.' : null,
                          ),
                          const SizedBox(height: 24),
                          BotaoPrincipal(
                            rotulo: 'Entrar',
                            icone: Icons.login,
                            carregando: _carregando,
                            aoPressionar: _entrar,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                              onPressed: _esqueci,
                              child: const Text('Esqueci minha senha')),
                        ],
                      ),
                    ),
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
