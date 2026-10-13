import 'package:flutter/material.dart';

/// Estado explícito para uma área ainda sem integração de dados.
class EstadoModuloEmPreparacao extends StatelessWidget {
  const EstadoModuloEmPreparacao({
    required this.titulo,
    this.descricao =
        'Esta área será conectada após a aprovação das regras e do acesso aos dados.',
    super.key,
  });

  final String titulo;
  final String descricao;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 40,
                color: colors.primary,
                semanticLabel: 'Área protegida em preparação',
              ),
              const SizedBox(height: 16),
              Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(descricao, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
