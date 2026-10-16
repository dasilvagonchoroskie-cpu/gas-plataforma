import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../comum/links.dart';
import '../../estado/provedores.dart';

class TelaCadastro extends ConsumerStatefulWidget {
  const TelaCadastro({super.key});

  @override
  ConsumerState<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends ConsumerState<TelaCadastro> {
  final _formulario = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _telefone = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _aceitou = false;
  bool _carregando = false;
  bool _mostrarSenha = false;

  @override
  void dispose() {
    _nome.dispose();
    _telefone.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    if (!(_formulario.currentState?.validate() ?? false)) {
      return;
    }
    if (!_aceitou) {
      mostrarMensagem(context, 'Para continuar, aceite os termos e a política de privacidade.', erro: true);
      return;
    }
    setState(() => _carregando = true);
    try {
      await ref.read(provedorConta).cadastrar(
            nome: _nome.text,
            telefone: _telefone.text,
            email: _email.text,
            senha: _senha.text,
          );
      // O roteador leva para a tela inicial assim que o login acontece.
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
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LarguraMaxima(
            largura: 480,
            child: Form(
              key: _formulario,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Preencha seus dados. O telefone é usado pela central para '
                      'falar com você sobre a entrega.',
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nome,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nome completo',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: Validacoes.nome,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telefone,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9() \-]')),
                        LengthLimitingTextInputFormatter(16),
                      ],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Celular com DDD',
                        hintText: '(64) 99999-0000',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: Validacoes.celular,
                    ),
                    const SizedBox(height: 16),
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
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Crie uma senha (mínimo 8 caracteres)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _mostrarSenha ? 'Esconder senha' : 'Mostrar senha',
                          icon: Icon(_mostrarSenha ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _mostrarSenha = !_mostrarSenha),
                        ),
                      ),
                      validator: Validacoes.senha,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _aceitou,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (valor) => setState(() => _aceitou = valor ?? false),
                      title: const Text('Li e aceito os termos de uso e a política de privacidade'),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => abrirLink(context, enderecoTermos),
                          child: const Text('Ver termos'),
                        ),
                        TextButton(
                          onPressed: () => abrirLink(context, enderecoPrivacidade),
                          child: const Text('Ver privacidade'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    BotaoPrincipal(
                      rotulo: 'Criar conta',
                      icone: Icons.check,
                      carregando: _carregando,
                      aoPressionar: _cadastrar,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
