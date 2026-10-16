import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../estado/provedores.dart';

final _provedorSituacao = FutureProvider.autoDispose<SituacaoNotificacoes>(
    (ref) => ref.watch(provedorNotificacoesConfig).situacao());

/// Passos para pegar a chave no Firebase (nomes da tela em inglês, com a
/// tradução, porque o console do Firebase pode estar em inglês).
const passosDaChave = [
  'No Firebase, toque na engrenagem e em Project settings '
      '("Configurações do projeto").',
  'Abra a aba Service accounts ("Contas de serviço").',
  'Toque em Generate new private key ("Gerar nova chave privada") e '
      'confirme em Generate key ("Gerar chave"). O celular baixa um arquivo '
      '.json.',
  'Volte aqui, toque em "Enviar chave do Firebase" e escolha esse arquivo.',
];

/// Super Central → Notificações: o dono envia a chave do Firebase direto para
/// o cofre do servidor e testa o aviso no próprio celular. A chave nunca
/// aparece na tela nem passa por mensagem.
class SecaoNotificacoes extends ConsumerStatefulWidget {
  const SecaoNotificacoes({super.key});

  @override
  ConsumerState<SecaoNotificacoes> createState() => _SecaoNotificacoesState();
}

class _SecaoNotificacoesState extends ConsumerState<SecaoNotificacoes> {
  bool _enviando = false;
  bool _testando = false;

  Future<void> _enviarChave() async {
    final arquivo = await openFile();
    if (arquivo == null || !mounted) {
      return;
    }
    setState(() => _enviando = true);
    try {
      if (await arquivo.length() > 20000) {
        throw const ErroDeNegocio(
            'Este arquivo é grande demais para ser a chave do Firebase.');
      }
      final conteudo = await arquivo.readAsString();
      final situacao =
          await ref.read(provedorNotificacoesConfig).enviarChave(conteudo);
      ref.invalidate(_provedorSituacao);
      if (mounted) {
        mostrarMensagem(
          context,
          situacao.configurado
              ? 'Chave guardada no servidor. Agora toque em "Enviar aviso de '
                  'teste".'
              : 'A chave não foi guardada. Tente de novo.',
          erro: !situacao.configurado,
        );
      }
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  Future<void> _testar() async {
    setState(() => _testando = true);
    try {
      // Garante que este celular está registrado antes do teste.
      await ref.read(provedorNotificacoes).ativar();
      final resultado = await ref.read(provedorNotificacoesConfig).testar();
      if (mounted) {
        mostrarMensagem(context, resultado.mensagem, erro: !resultado.enviado);
      }
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    } finally {
      if (mounted) {
        setState(() => _testando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final situacao = ref.watch(_provedorSituacao);
    final tema = Theme.of(context);
    return RefreshIndicator(
      onRefresh: () => ref.refresh(_provedorSituacao.future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LarguraMaxima(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                situacao.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.all(24), child: Carregando()),
                  error: (erro, _) => EstadoErro(
                    mensagem: mensagemDeErro(erro),
                    aoTentarNovamente: () => ref.invalidate(_provedorSituacao),
                  ),
                  data: (s) => Card(
                    child: ListTile(
                      leading: Icon(
                        s.configurado
                            ? Icons.notifications_active
                            : Icons.notifications_off_outlined,
                        color: s.configurado
                            ? tema.colorScheme.primary
                            : tema.colorScheme.error,
                        size: 36,
                      ),
                      title: Text(s.configurado
                          ? 'Notificações ligadas'
                          : 'Notificações ainda não configuradas'),
                      subtitle: Text(s.configurado
                          ? 'Projeto do Firebase: ${s.projeto}'
                          : 'Os pedidos chegam normalmente, mas o celular só '
                              'avisa com o aplicativo aberto.'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                BotaoPrincipal(
                  icone: Icons.upload_file,
                  rotulo: 'Enviar chave do Firebase',
                  carregando: _enviando,
                  aoPressionar: _enviarChave,
                ),
                const SizedBox(height: 12),
                BotaoPrincipal(
                  icone: Icons.notifications_outlined,
                  rotulo: 'Enviar aviso de teste para este celular',
                  secundario: true,
                  carregando: _testando,
                  aoPressionar: _testar,
                ),
                const TituloSecao('Como pegar a chave no Firebase'),
                for (final (indice, passo) in passosDaChave.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(radius: 14, child: Text('${indice + 1}')),
                        const SizedBox(width: 12),
                        Expanded(child: Text(passo)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'A chave vai direto para o cofre do servidor: ela não aparece '
                  'aqui de novo e não deve ser enviada por WhatsApp ou e-mail. '
                  'Depois de enviar, pode apagar o arquivo do celular.',
                  style: tema.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
