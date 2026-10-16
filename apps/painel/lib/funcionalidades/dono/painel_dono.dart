import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';
import 'secao_auditoria.dart';
import 'secao_centrais.dart';
import 'secao_pedidos_dono.dart';
import 'secao_precos.dart';
import 'secao_produtos.dart';
import 'secao_relatorios.dart';
import 'secao_usuarios.dart';
import 'secao_visao_geral.dart';

/// Painel do dono (super administrador): vê e controla todas as centrais.
class PainelDono extends ConsumerWidget {
  const PainelDono({required this.perfil, super.key});

  final Perfil perfil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CascaPainel(
      titulo: 'Painel do dono',
      subtitulo: perfil.primeiroNome,
      acoes: [
        IconButton(
          tooltip: 'Sair',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            final certeza = await confirmar(
              context,
              titulo: 'Sair do painel?',
              mensagem: 'Você vai precisar do e-mail e da senha para entrar de novo.',
              rotuloConfirmar: 'Sair',
            );
            if (certeza) {
              await ref.read(provedorConta).sair();
            }
          },
        ),
      ],
      secoes: const [
        SecaoPainel(rotulo: 'Visão geral', icone: Icons.dashboard_outlined, conteudo: SecaoVisaoGeral()),
        SecaoPainel(rotulo: 'Pedidos', icone: Icons.receipt_long_outlined, conteudo: SecaoPedidosDono()),
        SecaoPainel(rotulo: 'Centrais', icone: Icons.store_outlined, conteudo: SecaoCentrais()),
        SecaoPainel(rotulo: 'Produtos', icone: Icons.inventory_2_outlined, conteudo: SecaoProdutos()),
        SecaoPainel(rotulo: 'Preços', icone: Icons.sell_outlined, conteudo: SecaoPrecos()),
        SecaoPainel(rotulo: 'Usuários', icone: Icons.group_outlined, conteudo: SecaoUsuarios()),
        SecaoPainel(rotulo: 'Relatórios', icone: Icons.insights_outlined, conteudo: SecaoRelatorios()),
        SecaoPainel(rotulo: 'Auditoria', icone: Icons.history, conteudo: SecaoAuditoria()),
      ],
    );
  }
}

/// Lista suspensa para escolher uma central (usada em várias seções do dono).
class SeletorCentral extends ConsumerWidget {
  const SeletorCentral({
    required this.selecionada,
    required this.aoEscolher,
    this.permitirTodas = false,
    super.key,
  });

  final String? selecionada;
  final ValueChanged<String?> aoEscolher;
  final bool permitirTodas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final centrais = ref.watch(provedorCentrais).valueOrNull ?? const <Central>[];
    return DropdownMenu<String?>(
      key: ValueKey('seletor-${selecionada ?? 'todas'}-${centrais.length}'),
      initialSelection: selecionada,
      label: const Text('Central'),
      width: 320,
      onSelected: aoEscolher,
      dropdownMenuEntries: [
        if (permitirTodas) const DropdownMenuEntry<String?>(value: null, label: 'Todas as centrais'),
        for (final c in centrais)
          DropdownMenuEntry<String?>(
            value: c.id,
            label: '${c.nome}${c.ativa ? '' : ' (desativada)'}',
          ),
      ],
    );
  }
}
