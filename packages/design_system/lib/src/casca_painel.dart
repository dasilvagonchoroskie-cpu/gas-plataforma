import 'package:flutter/material.dart';

/// Item de navegação do painel.
class SecaoPainel {
  const SecaoPainel({
    required this.rotulo,
    required this.icone,
    required this.conteudo,
    this.contador = 0,
  });

  final String rotulo;
  final IconData icone;
  final Widget conteudo;

  /// Número mostrado em destaque no ícone (por exemplo, pedidos novos).
  final int contador;
}

/// Casca responsiva dos painéis: barra lateral no computador e barra
/// inferior no celular.
class CascaPainel extends StatefulWidget {
  const CascaPainel({
    required this.titulo,
    required this.secoes,
    this.subtitulo,
    this.acoes = const [],
    super.key,
  });

  final String titulo;
  final String? subtitulo;
  final List<SecaoPainel> secoes;
  final List<Widget> acoes;

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

  Widget _icone(SecaoPainel secao) {
    final icone = Icon(secao.icone);
    if (secao.contador <= 0) {
      return icone;
    }
    return Badge(label: Text('${secao.contador}'), child: icone);
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.subtitulo == null
        ? Text(widget.titulo)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.titulo),
              Text(
                widget.subtitulo!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );

    if (widget.secoes.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: titulo, actions: widget.acoes),
        body: const Center(child: Text('Nenhuma seção disponível.')),
      );
    }

    final indiceSeguro =
        _indiceSelecionado.clamp(0, widget.secoes.length - 1).toInt();
    final conteudo = IndexedStack(
      index: indiceSeguro,
      children: [for (final secao in widget.secoes) secao.conteudo],
    );

    return LayoutBuilder(
      builder: (context, restricoes) {
        final celular = restricoes.maxWidth < 760;
        // No celular, com muitas seções, a barra inferior mostra só ícones.
        if (celular && widget.secoes.length <= 5) {
          return Scaffold(
            appBar: AppBar(title: titulo, actions: widget.acoes),
            body: conteudo,
            bottomNavigationBar: NavigationBar(
              selectedIndex: indiceSeguro,
              onDestinationSelected: _selecionarSecao,
              destinations: [
                for (final secao in widget.secoes)
                  NavigationDestination(
                    icon: _icone(secao),
                    label: secao.rotulo,
                  ),
              ],
            ),
          );
        }

        if (celular) {
          return Scaffold(
            appBar: AppBar(title: titulo, actions: widget.acoes),
            drawer: NavigationDrawer(
              selectedIndex: indiceSeguro,
              onDestinationSelected: (indice) {
                _selecionarSecao(indice);
                Navigator.of(context).pop();
              },
              children: [
                const SizedBox(height: 16),
                for (final secao in widget.secoes)
                  NavigationDrawerDestination(
                    icon: _icone(secao),
                    label: Text(secao.rotulo),
                  ),
              ],
            ),
            body: conteudo,
          );
        }

        return Scaffold(
          appBar: AppBar(title: titulo, actions: widget.acoes),
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: indiceSeguro,
                labelType: NavigationRailLabelType.all,
                onDestinationSelected: _selecionarSecao,
                destinations: [
                  for (final secao in widget.secoes)
                    NavigationRailDestination(
                      icon: _icone(secao),
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
