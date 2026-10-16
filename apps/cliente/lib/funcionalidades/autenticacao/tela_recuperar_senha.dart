import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

class TelaRecuperarSenha extends ConsumerStatefulWidget {
  const TelaRecuperarSenha({super.key});

  @override
  ConsumerState<TelaRecuperarSenha> createState() => _TelaRecuperarSenhaState();
}

class _TelaRecuperarSenhaState extends ConsumerState<TelaRecuperarSenha> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _carregando = false;
  bool _enviado = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!(_formulario.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _carregando = true);
    try {
      await ref.read(provedorConta).recuperarSenha(_email.text);
      if (mounted) {
        setState(() => _enviado = true);
      }
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
      appBar: AppBar(title: const Text('Esqueci minha senha')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LarguraMaxima(
            largura: 480,
            child: _enviado
                ? const EstadoVazio(
                    icone: Icons.mark_email_read_outlined,
                    titulo: 'Pronto!',
                    mensagem:
                        'Se o e-mail estiver cadastrado, você vai receber um link para '
                        'criar uma senha nova. Se não chegar em alguns minutos, olhe o lixo '
                        'eletrônico ou ligue para a central: ela pode criar uma senha nova para você.',
                  )
                : Form(
                    key: _formulario,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                            'Digite o e-mail da sua conta. Vamos mandar um link para você criar uma senha nova.'),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: Validacoes.email,
                        ),
                        const SizedBox(height: 24),
                        BotaoPrincipal(
                          rotulo: 'Enviar link',
                          icone: Icons.send,
                          carregando: _carregando,
                          aoPressionar: _enviar,
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
