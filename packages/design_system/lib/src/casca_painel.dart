import 'package:flutter/material.dart';

/// Item de navegação de um dos painéis web.
class SecaoPainel {
  const SecaoPainel({
    required this.rotulo,
    required this.icone,
    required this.conteudo,
  });

  final String rotulo;
  final IconData icone;
  final Widget conteudo;
}

/// Casca responsiva compartilhada pelos painéis de gestão e de central.
class CascaPainel extends StatefulWidget {
  const CascaPainel({
    required this.titulo,
    required this.secoes,
    super.key,
  });

  final String titulo;
  final List<SecaoPainel> secoes;

  @override
  State<CascaPainel> createState() => _CascaPainelState();
}

class _CascaPainelState extends State<CascaPainel> {
  int _indiceSelecionado = 0;

  void _selecionarSecao(int indice) {
    if (indice == _indiceSelecionado) {
      return;
    }
    setState(() => _indiceSelecionado = indice);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.secoes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.titulo)),
        body: const Center(child: Text('Nenhuma seção configurada.')),
      );
    }

    final indiceSeguro =
        _indiceSelecionado.clamp(0, widget.secoes.length - 1).toInt();
    final conteudo = IndexedStack(
      index: indiceSeguro,
      children: [for (final secao in widget.secoes) secao.conteudo],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.titulo)),
            body: conteudo,
            bottomNavigationBar: NavigationBar(
              selectedIndex: indiceSeguro,
              onDestinationSelected: _selecionarSecao,
              destinations: [
                for (final secao in widget.secoes)
                  NavigationDestination(
                    icon: Icon(secao.icone),
                    label: secao.rotulo,
                  ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(widget.titulo)),
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: indiceSeguro,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: _selecionarSecao,
                destinations: [
                  for (final secao in widget.secoes)
                    NavigationRailDestination(
                      icon: Icon(secao.icone),
                      label: Text(secao.rotulo),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: conteudo),
            ],
          ),
        );
      },
    );
  }
}
