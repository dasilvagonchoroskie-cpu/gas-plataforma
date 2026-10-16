import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../estado/provedores.dart';
import 'catalogo/aba_inicio.dart';
import 'historico/aba_pedidos.dart';
import 'perfil/aba_perfil.dart';

/// Tela principal com as três abas: Início, Pedidos e Perfil.
class TelaPrincipal extends ConsumerStatefulWidget {
  const TelaPrincipal({super.key});

  @override
  ConsumerState<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends ConsumerState<TelaPrincipal> {
  int _aba = 0;

  @override
  void initState() {
    super.initState();
    // Logado: liga os avisos de pedido (pede permissão na primeira vez).
    unawaited(ref.read(provedorNotificacoes).ativar());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _aba,
        children: [
          AbaInicio(aoVerPedidos: () => setState(() => _aba = 1)),
          const AbaPedidos(),
          const AbaPerfil(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (indice) => setState(() => _aba = indice),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
