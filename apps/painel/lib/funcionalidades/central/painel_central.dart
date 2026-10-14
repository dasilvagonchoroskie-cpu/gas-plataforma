import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Shell operacional da central, preservado da prévia anterior.
///
/// As telas permanecem em preparação até a implementação da Fase 3.
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
