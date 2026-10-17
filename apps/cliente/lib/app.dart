import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'estado/provedores.dart';
import 'funcionalidades/acompanhamento/tela_acompanhar_pedido.dart';
import 'funcionalidades/autenticacao/tela_cadastro.dart';
import 'funcionalidades/autenticacao/tela_entrar.dart';
import 'funcionalidades/autenticacao/tela_recuperar_senha.dart';
import 'funcionalidades/carrinho/tela_carrinho.dart';
import 'funcionalidades/enderecos/tela_editar_endereco.dart';
import 'funcionalidades/enderecos/tela_enderecos.dart';
import 'funcionalidades/ficha/tela_crediario.dart';
import 'funcionalidades/ficha/tela_ficha.dart';
import 'funcionalidades/pedido/tela_finalizar.dart';
import 'funcionalidades/pedido/tela_horario.dart';
import 'funcionalidades/tela_principal.dart';

/// Nome que aparece no app: vem da marca da revenda (marca/marca.json).
const String nomeDoApp = Marca.nome;

const _rotasSemLogin = {'/entrar', '/cadastro', '/recuperar-senha'};

final provedorRoteador = Provider<GoRouter>((ref) {
  // .notifier: o roteador é criado uma vez e só reavalia o redirecionamento.
  final login = ref.watch(provedorEstadoDeLogin.notifier);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: login,
    redirect: (context, estado) {
      final caminho = estado.matchedLocation;
      final semLogin = _rotasSemLogin.contains(caminho);
      if (!login.logado && !semLogin) {
        return '/entrar';
      }
      if (login.logado && semLogin) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, estado) => const TelaPrincipal()),
      GoRoute(
          path: '/entrar', builder: (context, estado) => const TelaEntrar()),
      GoRoute(
          path: '/cadastro',
          builder: (context, estado) => const TelaCadastro()),
      GoRoute(
        path: '/recuperar-senha',
        builder: (context, estado) => const TelaRecuperarSenha(),
      ),
      GoRoute(
          path: '/enderecos',
          builder: (context, estado) => const TelaEnderecos()),
      GoRoute(
        path: '/enderecos/novo',
        builder: (context, estado) => const TelaEditarEndereco(),
      ),
      GoRoute(
        path: '/enderecos/:id',
        builder: (context, estado) =>
            TelaEditarEndereco(enderecoId: estado.pathParameters['id']),
      ),
      GoRoute(path: '/ficha', builder: (context, estado) => const TelaFicha()),
      GoRoute(
          path: '/crediario',
          builder: (context, estado) => const TelaCrediario()),
      GoRoute(
          path: '/carrinho',
          builder: (context, estado) => const TelaCarrinho()),
      GoRoute(
          path: '/horario', builder: (context, estado) => const TelaHorario()),
      GoRoute(
          path: '/finalizar',
          builder: (context, estado) => const TelaFinalizar()),
      GoRoute(
        path: '/pedido/:id',
        builder: (context, estado) =>
            TelaAcompanharPedido(pedidoId: estado.pathParameters['id']!),
      ),
    ],
  );
});

class AplicativoCliente extends ConsumerWidget {
  const AplicativoCliente({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: nomeDoApp,
      debugShowCheckedModeBanner: false,
      theme: criarTemaPlataforma(),
      routerConfig: ref.watch(provedorRoteador),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

/// Mostrado só quando o app foi compilado sem o endereço do servidor.
class AplicativoSemConfiguracao extends StatelessWidget {
  const AplicativoSemConfiguracao({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: nomeDoApp,
      debugShowCheckedModeBanner: false,
      theme: criarTemaPlataforma(),
      home: const Scaffold(
        body: EstadoVazio(
          icone: Icons.settings_outlined,
          titulo: 'Aplicativo sem configuração',
          mensagem: 'Esta versão foi gerada sem o endereço do servidor. '
              'Baixe a versão oficial com a revenda.',
        ),
      ),
    );
  }
}
