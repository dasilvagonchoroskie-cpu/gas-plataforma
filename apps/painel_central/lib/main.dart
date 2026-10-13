import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

void main() => runApp(const PainelCentralApp());

class PainelCentralApp extends StatelessWidget {
  const PainelCentralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Painel da central',
      theme: criarTemaPlataforma(),
      home: const PaginaPainelCentral(),
    );
  }
}

class PaginaPainelCentral extends StatelessWidget {
  const PaginaPainelCentral({super.key});

  @override
  Widget build(BuildContext context) {
    return CascaPainel(
      titulo: 'Painel da central',
      secoes: const [
        SecaoPainel(
          rotulo: 'Pedidos',
          icone: Icons.receipt_long_outlined,
          conteudo: EstadoModuloEmPreparacao(
            titulo: 'Fila de pedidos',
            descricao:
                'A central só poderá consultar pedidos atribuídos a ela após a validação de identidade e permissões no servidor.',
          ),
        ),
        SecaoPainel(
          rotulo: 'Estoque',
          icone: Icons.inventory_2_outlined,
          conteudo: EstadoModuloEmPreparacao(titulo: 'Estoque da central'),
        ),
        SecaoPainel(
          rotulo: 'Horários',
          icone: Icons.calendar_month_outlined,
          conteudo: EstadoModuloEmPreparacao(titulo: 'Capacidade e horários'),
        ),
        SecaoPainel(
          rotulo: 'Entregas',
          icone: Icons.local_shipping_outlined,
          conteudo: EstadoModuloEmPreparacao(titulo: 'Operação de entregas'),
        ),
      ],
    );
  }
}
