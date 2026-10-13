import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

void main() => runApp(const AplicativoCliente());

class AplicativoCliente extends StatelessWidget {
  const AplicativoCliente({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pedidos de gás e água',
      theme: criarTemaPlataforma(),
      home: const TelaInicialCliente(),
    );
  }
}

class TelaInicialCliente extends StatefulWidget {
  const TelaInicialCliente({super.key});

  @override
  State<TelaInicialCliente> createState() => _TelaInicialClienteState();
}

class _TelaInicialClienteState extends State<TelaInicialCliente> {
  int _indiceSelecionado = 0;

  static const _titulos = ['Início', 'Pedidos', 'Perfil'];
  static const _icones = [
    Icons.home_outlined,
    Icons.receipt_long_outlined,
    Icons.person_outline,
  ];

  static const _telas = [
    EstadoModuloEmPreparacao(
      titulo: 'Solicite gás e água',
      descricao:
          'A autenticação, o endereço e o catálogo serão conectados após a revisão do backend e das permissões.',
    ),
    EstadoModuloEmPreparacao(
      titulo: 'Seus pedidos',
      descricao:
          'O acompanhamento será habilitado com as transições de pedido e os acessos aprovados.',
    ),
    EstadoModuloEmPreparacao(
      titulo: 'Seu perfil',
      descricao:
          'Os dados pessoais só serão exibidos e alterados após a integração segura de autenticação.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos de gás e água')),
      body: _telas[_indiceSelecionado],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceSelecionado,
        onDestinationSelected: (indice) {
          setState(() => _indiceSelecionado = indice);
        },
        destinations: [
          for (var indice = 0; indice < _titulos.length; indice++)
            NavigationDestination(
              icon: Icon(_icones[indice]),
              label: _titulos[indice],
            ),
        ],
      ),
    );
  }
}
