import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

final _provedorAuditoria = FutureProvider.autoDispose.family<List<RegistroAuditoria>, String?>(
  (ref, tabela) => ref.watch(provedorGestao).auditoria(tabela: tabela),
);

const _tabelas = <String?, String>{
  null: 'Tudo',
  'centrais': 'Centrais',
  'precos_central': 'Preços',
  'produtos': 'Produtos',
  'faixas_entrega': 'Faixas de entrega',
  'janelas_entrega': 'Horários',
  'bloqueios_agenda': 'Bloqueios',
  'entregadores': 'Entregadores',
  'usuarios': 'Usuários',
  'perfis': 'Papéis',
  'operadores_central': 'Operadores',
  'fichas_cliente': 'Fichas',
  'lancamentos_credito': 'Crediário',
  'configuracoes': 'Configurações',
};

const _acoes = {
  'insert': 'criou',
  'update': 'alterou',
  'delete': 'apagou',
  'criar_usuario': 'criou usuário',
  'mudar_papel': 'mudou o papel',
  'ativar_usuario': 'reativou o acesso',
  'desativar_usuario': 'desativou o acesso',
  'redefinir_senha': 'criou senha nova',
  'analisar_ficha': 'analisou a ficha',
  'bloquear_credito': 'bloqueou o fiado',
  'liberar_credito': 'liberou o fiado',
  'ajustar_credito': 'ajustou o crediário',
};

const _campos = {
  'nome': 'nome',
  'ativa': 'ativa',
  'ativo': 'ativo',
  'papel': 'papel',
  'preco_centavos': 'preço',
  'disponivel': 'disponível',
  'taxa_entrega_centavos': 'taxa',
  'ate_km': 'até km',
  'capacidade': 'vagas',
  'hora_inicio': 'início',
  'hora_fim': 'fim',
  'dia_semana': 'dia',
  'whatsapp': 'WhatsApp',
  'latitude': 'latitude',
  'longitude': 'longitude',
  'cidade': 'cidade',
  'uf': 'UF',
  'endereco': 'endereço',
  'telefone': 'telefone',
  'troca_vasilhame': 'troca',
  'foto_url': 'foto',
  'descricao': 'descrição',
  'ordem': 'posição',
  'motivo': 'motivo',
  'data': 'data',
  'central_id': 'central',
  'status': 'situação',
  'limite_centavos': 'limite',
  'credito_bloqueado': 'fiado bloqueado',
  'valor_centavos': 'valor',
  'centrais_aprovam_credito': 'centrais aprovam fichas',
  'limite_maximo_central_centavos': 'teto da central',
};

/// Texto curto de um valor guardado na auditoria.
String descreverValorAuditoria(String campo, Object? valor) {
  if (valor == null) {
    return '(vazio)';
  }
  if (valor is bool) {
    return valor ? 'sim' : 'não';
  }
  if (campo.endsWith('_centavos') && valor is num) {
    return Dinheiro(valor.toInt()).formatarEmReais();
  }
  if (campo == 'dia_semana' && valor is num) {
    return Datas.nomeDiaLongo(valor.toInt());
  }
  if (campo == 'papel' && valor is String) {
    return PapelPerfil.values.where((p) => p.valor == valor).map((p) => p.rotulo).firstOrNull ?? valor;
  }
  final texto = '$valor';
  return texto.length > 60 ? '${texto.substring(0, 57)}...' : texto;
}

/// Histórico de quem mudou o quê (centrais, preços, usuários...). Só o dono vê.
class SecaoAuditoria extends ConsumerStatefulWidget {
  const SecaoAuditoria({super.key});

  @override
  ConsumerState<SecaoAuditoria> createState() => _SecaoAuditoriaState();
}

class _SecaoAuditoriaState extends ConsumerState<SecaoAuditoria> {
  String? _tabela;

  @override
  Widget build(BuildContext context) {
    final registros = ref.watch(_provedorAuditoria(_tabela));
    final centrais = {
      for (final c in ref.watch(provedorCentrais).valueOrNull ?? const <Central>[]) c.id: c.nome,
    };
    return Column(
      children: [
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            children: [
              for (final t in _tabelas.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t.value),
                    selected: _tabela == t.key,
                    onSelected: (_) => setState(() => _tabela = t.key),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: registros.when(
            loading: () => const Carregando(),
            error: (erro, _) => EstadoErro(
              mensagem: mensagemDeErro(erro),
              aoTentarNovamente: () => ref.invalidate(_provedorAuditoria(_tabela)),
            ),
            data: (lista) {
              if (lista.isEmpty) {
                return const EstadoVazio(icone: Icons.history, titulo: 'Nada registrado ainda');
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(_provedorAuditoria(_tabela).future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: lista.length + 1,
                  itemBuilder: (context, i) {
                    if (i == lista.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Mostrando os 200 registros mais recentes.', textAlign: TextAlign.center),
                      );
                    }
                    return _ItemAuditoria(registro: lista[i], centrais: centrais);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ItemAuditoria extends StatelessWidget {
  const _ItemAuditoria({required this.registro, required this.centrais});

  final RegistroAuditoria registro;
  final Map<String, String> centrais;

  @override
  Widget build(BuildContext context) {
    final r = registro;
    final quem = r.quem ?? 'Sistema';
    final acao = _acoes[r.acao] ?? r.acao;
    final onde = _tabelas[r.tabela] ?? r.tabela;
    final dados = r.depois ?? r.antes ?? const <String, dynamic>{};
    final Object? nome = dados['nome'] ?? centrais['${dados['central_id']}'] ?? centrais[r.registroId];
    final alterados = [
      for (final campo in r.camposAlterados)
        if (_campos.containsKey(campo)) campo,
    ];
    String valor(String campo, Object? v) =>
        campo == 'central_id' ? (centrais['$v'] ?? '-') : descreverValorAuditoria(campo, v);
    final detalhes = r.acao == 'update' && alterados.isNotEmpty
        ? [
            for (final campo in alterados)
              '${_campos[campo]}: ${valor(campo, r.antes?[campo])} → ${valor(campo, r.depois?[campo])}',
          ]
        : [
            for (final e in dados.entries)
              if (_campos.containsKey(e.key)) '${_campos[e.key]}: ${valor(e.key, e.value)}',
          ];
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        title: Text('$quem $acao · $onde${nome == null ? '' : ' · $nome'}'),
        subtitle: Text(Datas.formatarDataHora(r.criadoEm)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detalhes.isEmpty) const Text('Sem detalhes.'),
          for (final linha in detalhes) Text(linha),
        ],
      ),
    );
  }
}
