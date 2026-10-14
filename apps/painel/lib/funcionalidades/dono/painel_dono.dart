import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Shell de gestão do dono, preservado da prévia anterior.
///
/// As telas permanecem em preparação até a implementação da Fase 2.
class PaginaPainelDono extends StatelessWidget {
  const PaginaPainelDono({super.key});

  @override
  Widget build(BuildContext context) {
    return CascaPainel(
      titulo: 'Painel do dono',
      secoes: const [
        SecaoPainel(
          rotulo: 'Visão geral',
          icone: Icons.dashboard_outlined,
          conteudo: EstadoModuloEmPreparacao(
            titulo: 'Visão geral da empresa',
            descricao:
                'Indicadores e dados reais só serão exibidos após configurar autenticação e isolamento por central.',
          ),
        ),
        SecaoPainel(
          rotulo: 'Centrais',
          icone: Icons.store_outlined,
          conteudo: EstadoModuloEmPreparacao(titulo: 'Centrais da empresa'),
        ),
        SecaoPainel(
          rotulo: 'Produtos',
          icone: Icons.inventory_2_outlined,
          conteudo: EstadoModuloEmPreparacao(titulo: 'Catálogo e preços'),
        ),
        SecaoPainel(
          rotulo: 'Pedidos',
          icone: Icons.receipt_long_outlined,
          conteudo: EstadoModuloEmPreparacao(titulo: 'Pedidos da empresa'),
        ),
        SecaoPainel(
          rotulo: 'Relatórios',
          icone: Icons.analytics_outlined,
          conteudo: EstadoModuloEmPreparacao(titulo: 'Relatórios da empresa'),
        ),
      ],
    );
  }
}
