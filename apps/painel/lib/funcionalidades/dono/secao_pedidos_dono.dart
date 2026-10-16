import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';
import '../pedidos/fila_pedidos.dart';
import 'painel_dono.dart';

/// O dono escolhe uma central e vê (e opera) a fila dela.
class SecaoPedidosDono extends ConsumerStatefulWidget {
  const SecaoPedidosDono({super.key});

  @override
  ConsumerState<SecaoPedidosDono> createState() => _SecaoPedidosDonoState();
}

class _SecaoPedidosDonoState extends ConsumerState<SecaoPedidosDono> {
  String? _centralId;

  @override
  Widget build(BuildContext context) {
    final centrais =
        ref.watch(provedorCentrais).valueOrNull ?? const <Central>[];
    final centralId =
        _centralId ?? (centrais.isEmpty ? null : centrais.first.id);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SeletorCentral(
              selecionada: centralId,
              aoEscolher: (id) => setState(() => _centralId = id),
            ),
          ),
        ),
        Expanded(
          child: centralId == null
              ? const EstadoVazio(titulo: 'Nenhuma central cadastrada')
              : FilaPedidos(
                  key: ValueKey(centralId),
                  centralId: centralId,
                  tocarSom: false),
        ),
      ],
    );
  }
}
