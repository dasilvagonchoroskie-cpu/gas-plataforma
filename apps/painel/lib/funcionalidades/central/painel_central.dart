import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';
import '../pedidos/fila_pedidos.dart';
import 'secao_disponibilidade.dart';
import 'secao_entregadores.dart';
import 'secao_estoque.dart';
import 'secao_horarios.dart';
import 'secao_resumo.dart';

/// Painel do operador de central.
class PainelCentral extends ConsumerStatefulWidget {
  const PainelCentral({required this.perfil, required this.centralId, super.key});

  final Perfil perfil;
  final String centralId;

  @override
  ConsumerState<PainelCentral> createState() => _PainelCentralState();
}

class _PainelCentralState extends ConsumerState<PainelCentral> {
  int _novos = 0;

  @override
  Widget build(BuildContext context) {
    final centrais = ref.watch(provedorCentrais).valueOrNull ?? const <Central>[];
    String? nomeCentral;
    for (final c in centrais) {
      if (c.id == widget.centralId) {
        nomeCentral = c.nome;
      }
    }
    return CascaPainel(
      titulo: nomeCentral ?? 'Central',
      subtitulo: widget.perfil.primeiroNome,
      acoes: [
        IconButton(
          tooltip: 'Sair',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            final certeza = await confirmar(
              context,
              titulo: 'Sair do painel?',
              mensagem: 'Pedidos novos não vão tocar aviso enquanto ninguém estiver no painel.',
              rotuloConfirmar: 'Sair',
            );
            if (certeza) {
              await ref.read(provedorConta).sair();
            }
          },
        ),
      ],
      secoes: [
        SecaoPainel(
          rotulo: 'Pedidos',
          icone: Icons.receipt_long_outlined,
          contador: _novos,
          conteudo: FilaPedidos(
            centralId: widget.centralId,
            aoMudarNovos: (quantidade) {
              if (quantidade != _novos && mounted) {
                setState(() => _novos = quantidade);
              }
            },
          ),
        ),
        SecaoPainel(
          rotulo: 'Horários',
          icone: Icons.calendar_month_outlined,
          conteudo: SecaoHorarios(centralId: widget.centralId),
        ),
        SecaoPainel(
          rotulo: 'Estoque',
          icone: Icons.inventory_2_outlined,
          conteudo: SecaoEstoque(centralId: widget.centralId),
        ),
        SecaoPainel(
          rotulo: 'Produtos',
          icone: Icons.sell_outlined,
          conteudo: SecaoDisponibilidade(centralId: widget.centralId),
        ),
        SecaoPainel(
          rotulo: 'Entregadores',
          icone: Icons.delivery_dining_outlined,
          conteudo: SecaoEntregadores(centralId: widget.centralId),
        ),
        SecaoPainel(
          rotulo: 'Resumo',
          icone: Icons.insights_outlined,
          conteudo: SecaoResumo(centralId: widget.centralId),
        ),
      ],
    );
  }
}
