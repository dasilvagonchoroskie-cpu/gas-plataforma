import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

void main() => runApp(const AplicativoPainel());

class AplicativoPainel extends StatelessWidget {
  const AplicativoPainel({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Painel de pedidos de gás e água',
      theme: criarTemaPlataforma(),
      home: const PaginaInicialPainel(),
    );
  }
}

class PaginaInicialPainel extends StatelessWidget {
  const PaginaInicialPainel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Painel de pedidos de gás e água')),
      body: const EstadoModuloEmPreparacao(
        titulo: 'Painel unificado',
        descricao:
            'O acesso por perfil e os fluxos de gestão serão habilitados nas fases 2 e 3, após a preparação segura do backend.',
      ),
    );
  }
}
