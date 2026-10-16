import 'dart:async';

import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'estado/provedores.dart';
import 'funcionalidades/autenticacao/tela_login.dart';
import 'funcionalidades/central/painel_central.dart';
import 'funcionalidades/dono/painel_dono.dart';
import 'tipo_painel.dart';

ThemeData _tema() => criarTemaPlataforma();

class AplicativoPainel extends ConsumerWidget {
  const AplicativoPainel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: ref.watch(provedorTipoPainel).nome,
      debugShowCheckedModeBanner: false,
      theme: _tema(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const RaizPainel(),
    );
  }
}

/// Decide o que mostrar: login, Super Central (dono), Central (loja) ou aviso de
/// "sem acesso". Cada aplicativo aceita só o seu tipo de conta. Quem decide o
/// que cada um pode fazer é o banco; esta tela só escolhe a interface certa.
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
        final tipo = ref.watch(provedorTipoPainel);
        final motivo = tipo.motivoSemAcesso(p);
        final centralId = p.centralId;
        if (motivo != null) {
          return _SemAcesso(mensagem: motivo);
        }
        if (tipo == TipoPainel.superCentral) {
          return _ComNotificacoes(child: PainelDono(perfil: p));
        }
        if (centralId != null) {
          return _ComNotificacoes(
              child: PainelCentral(perfil: p, centralId: centralId));
        }
        return const _SemAcesso(
            mensagem: 'Sua conta ainda não está ligada a uma loja.');
      },
    );
  }
}

/// Liga os avisos de pedido neste aparelho assim que o acesso é liberado.
class _ComNotificacoes extends ConsumerStatefulWidget {
  const _ComNotificacoes({required this.child});

  final Widget child;

  @override
  ConsumerState<_ComNotificacoes> createState() => _ComNotificacoesState();
}

class _ComNotificacoesState extends ConsumerState<_ComNotificacoes> {
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(provedorNotificacoes).ativar());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SemAcesso extends ConsumerWidget {
  const _SemAcesso({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      title: TipoPainel.doBuild.nome,
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
