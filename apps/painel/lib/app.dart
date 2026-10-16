import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import 'estado/provedores.dart';
import 'funcionalidades/autenticacao/tela_login.dart';
import 'funcionalidades/central/painel_central.dart';
import 'funcionalidades/dono/painel_dono.dart';

ThemeData _tema() => criarTemaPlataforma();

class AplicativoPainel extends StatelessWidget {
  const AplicativoPainel({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Painel Gás e Água',
      debugShowCheckedModeBanner: false,
      theme: _tema(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const RaizPainel(),
    );
  }
}

/// Decide o que mostrar: login, painel do dono, painel da central ou aviso de
/// "sem acesso". Quem decide o que cada um pode fazer é o banco; esta tela só
/// escolhe a interface certa.
class RaizPainel extends ConsumerWidget {
  const RaizPainel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final login = ref.watch(provedorEstadoDeLogin);
    if (!login.logado) {
      return const TelaLogin();
    }
    final perfil = ref.watch(provedorPerfil);
    return perfil.when(
      loading: () =>
          const Scaffold(body: Carregando(mensagem: 'Abrindo o painel...')),
      error: (erro, _) => Scaffold(
        body: EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () => ref.invalidate(provedorPerfil),
        ),
      ),
      data: (p) {
        if (p == null) {
          return const TelaLogin();
        }
        if (p.ativo && p.papel == PapelPerfil.dono) {
          return PainelDono(perfil: p);
        }
        if (p.ativo &&
            p.papel == PapelPerfil.operadorCentral &&
            p.centralId != null) {
          return PainelCentral(perfil: p, centralId: p.centralId!);
        }
        return _SemAcesso(perfil: p);
      },
    );
  }
}

class _SemAcesso extends ConsumerWidget {
  const _SemAcesso({required this.perfil});

  final Perfil perfil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mensagem = perfil.papel == PapelPerfil.cliente
        ? 'Esta conta é de cliente. Para pedir, use o aplicativo de pedidos. '
            'O painel é só para o dono e as centrais.'
        : 'Sua conta ainda não está ligada a uma central, ou foi desativada. '
            'Fale com o dono da revenda.';
    return Scaffold(
      body: EstadoVazio(
        icone: Icons.lock_outline,
        titulo: 'Acesso não liberado',
        mensagem: mensagem,
        rotuloAcao: 'Sair',
        aoAcionar: () => ref.read(provedorConta).sair(),
      ),
    );
  }
}

class PainelSemConfiguracao extends StatelessWidget {
  const PainelSemConfiguracao({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Painel Gás e Água',
      debugShowCheckedModeBanner: false,
      theme: _tema(),
      home: const Scaffold(
        body: EstadoVazio(
          icone: Icons.settings_outlined,
          titulo: 'Painel sem configuração',
          mensagem: 'Esta versão foi gerada sem o endereço do servidor.',
        ),
      ),
    );
  }
}
