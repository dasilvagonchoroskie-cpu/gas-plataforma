import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';
import '../relatorios/cartoes_resumo.dart';
import 'painel_dono.dart';

typedef _Consulta = ({DateTime inicio, DateTime fim, String? centralId});

typedef RelatorioPeriodo = ({
  List<ResumoCentral> centrais,
  List<VendaProduto> produtos,
  List<VendaDia> dias,
});

final _provedorRelatorio = FutureProvider.autoDispose.family<RelatorioPeriodo, _Consulta>((ref, c) async {
  final gestao = ref.watch(provedorGestao);
  final resultados = await Future.wait<Object>([
    gestao.resumoCentrais(c.inicio, c.fim, centralId: c.centralId),
    gestao.vendasPorProduto(c.inicio, c.fim, centralId: c.centralId),
    gestao.vendasPorDia(c.inicio, c.fim, centralId: c.centralId),
  ]);
  return (
    centrais: resultados[0] as List<ResumoCentral>,
    produtos: resultados[1] as List<VendaProduto>,
    dias: resultados[2] as List<VendaDia>,
  );
});

/// Soma o resumo de várias centrais num só.
ResumoCentral somarResumos(List<ResumoCentral> centrais) {
  final pedidos = centrais.fold(0, (s, c) => s + c.pedidos);
  final entregues = centrais.fold(0, (s, c) => s + c.entregues);
  final faturamento = centrais.fold(Dinheiro.zero, (s, c) => s + c.faturamento);
  return ResumoCentral(
    centralId: '',
    centralNome: 'Total',
    cidade: '',
    ativa: true,
    pedidos: pedidos,
    entregues: entregues,
    cancelados: centrais.fold(0, (s, c) => s + c.cancelados),
    emAberto: centrais.fold(0, (s, c) => s + c.emAberto),
    faturamento: faturamento,
    ticketMedio: entregues == 0 ? Dinheiro.zero : Dinheiro(faturamento.centavos ~/ entregues),
  );
}

/// Monta o relatório em CSV (separado por ponto e vírgula, como o Excel em
/// português abre direto).
String relatorioEmCsv(RelatorioPeriodo r, String periodo) {
  String valor(Dinheiro d) => d.formatarParaEdicao();
  // Nomes digitados não podem quebrar colunas nem virar fórmula na planilha.
  String celula(String texto) {
    final limpo = texto.replaceAll(RegExp(r'[;\r\n"]'), ' ').trim();
    return RegExp(r'^[=+\-@]').hasMatch(limpo) ? "'$limpo" : limpo;
  }

  final linhas = <String>[
    'Relatório;$periodo',
    '',
    'Central;Cidade;Pedidos;Entregues;Cancelados;Em aberto;Faturamento (R\$);Ticket médio (R\$)',
    for (final c in r.centrais)
      '${celula(c.centralNome)};${celula(c.cidade)};${c.pedidos};${c.entregues};${c.cancelados};'
          '${c.emAberto};${valor(c.faturamento)};${valor(c.ticketMedio)}',
    '',
    'Produto;Quantidade entregue;Valor (R\$)',
    for (final p in r.produtos) '${celula(p.produtoNome)};${p.quantidade};${valor(p.valor)}',
    '',
    'Dia;Pedidos;Entregues;Cancelados;Faturamento (R\$)',
    for (final d in r.dias)
      '${Datas.formatarData(d.dia)};${d.pedidos};${d.entregues};${d.cancelados};${valor(d.faturamento)}',
  ];
  return linhas.join('\n');
}

enum _Periodo {
  hoje('Hoje'),
  ontem('Ontem'),
  seteDias('Últimos 7 dias'),
  esteMes('Este mês'),
  mesPassado('Mês passado'),
  outro('Escolher datas');

  const _Periodo(this.rotulo);

  final String rotulo;
}

class SecaoRelatorios extends ConsumerStatefulWidget {
  const SecaoRelatorios({super.key});

  @override
  ConsumerState<SecaoRelatorios> createState() => _SecaoRelatoriosState();
}

class _SecaoRelatoriosState extends ConsumerState<SecaoRelatorios> {
  _Periodo _periodo = _Periodo.hoje;
  late DateTime _inicio = Datas.hoje();
  late DateTime _fim = Datas.hoje();
  String? _centralId;

  String get _textoPeriodo => _inicio == _fim
      ? Datas.formatarData(_inicio)
      : '${Datas.formatarData(_inicio)} a ${Datas.formatarData(_fim)}';

  Future<void> _escolher(_Periodo periodo) async {
    final hoje = Datas.hoje();
    DateTime inicio;
    DateTime fim;
    switch (periodo) {
      case _Periodo.hoje:
        inicio = hoje;
        fim = hoje;
      case _Periodo.ontem:
        inicio = hoje.subtract(const Duration(days: 1));
        fim = inicio;
      case _Periodo.seteDias:
        inicio = hoje.subtract(const Duration(days: 6));
        fim = hoje;
      case _Periodo.esteMes:
        inicio = DateTime.utc(hoje.year, hoje.month);
        fim = hoje;
      case _Periodo.mesPassado:
        inicio = DateTime.utc(hoje.year, hoje.month - 1);
        fim = DateTime.utc(hoje.year, hoje.month, 0);
      case _Periodo.outro:
        final escolhido = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2025),
          lastDate: DateTime(hoje.year, hoje.month, hoje.day),
          initialDateRange: DateTimeRange(
            start: DateTime(_inicio.year, _inicio.month, _inicio.day),
            end: DateTime(_fim.year, _fim.month, _fim.day),
          ),
          helpText: 'Escolha o período',
          saveText: 'Usar',
        );
        if (escolhido == null) {
          return;
        }
        inicio = DateTime.utc(escolhido.start.year, escolhido.start.month, escolhido.start.day);
        fim = DateTime.utc(escolhido.end.year, escolhido.end.month, escolhido.end.day);
        if (fim.difference(inicio).inDays > 366) {
          if (mounted) {
            mostrarMensagem(context, 'Escolha um período de até um ano.', erro: true);
          }
          return;
        }
    }
    setState(() {
      _periodo = periodo;
      _inicio = inicio;
      _fim = fim;
    });
  }

  @override
  Widget build(BuildContext context) {
    final consulta = (inicio: _inicio, fim: _fim, centralId: _centralId);
    final relatorio = ref.watch(_provedorRelatorio(consulta));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(_provedorRelatorio(consulta).future),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in _Periodo.values)
                ChoiceChip(
                  label: Text(p.rotulo),
                  selected: _periodo == p,
                  onSelected: (_) => _escolher(p),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SeletorCentral(
                selecionada: _centralId,
                permitirTodas: true,
                aoEscolher: (id) => setState(() => _centralId = id),
              ),
              if (relatorio.hasValue)
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: relatorioEmCsv(relatorio.requireValue, _textoPeriodo)));
                    if (context.mounted) {
                      mostrarMensagem(context, 'Relatório copiado. Cole numa planilha (Excel ou Google Planilhas).');
                    }
                  },
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('Copiar para planilha'),
                ),
            ],
          ),
          TituloSecao('Período: $_textoPeriodo'),
          relatorio.when(
            loading: () => const Padding(padding: EdgeInsets.all(32), child: Carregando()),
            error: (erro, _) => EstadoErro(
              mensagem: mensagemDeErro(erro),
              aoTentarNovamente: () => ref.invalidate(_provedorRelatorio(consulta)),
            ),
            data: (r) => _Conteudo(relatorio: r, mostrarCentrais: _centralId == null),
          ),
        ],
      ),
    );
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.relatorio, required this.mostrarCentrais});

  final RelatorioPeriodo relatorio;
  final bool mostrarCentrais;

  @override
  Widget build(BuildContext context) {
    final total = somarResumos(relatorio.centrais);
    final maiorDia = relatorio.dias.fold(0, (m, d) => d.faturamento.centavos > m ? d.faturamento.centavos : m);
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CartoesResumo(resumo: total),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Faturamento conta só os pedidos entregues.'),
        ),
        if (mostrarCentrais && relatorio.centrais.length > 1) ...[
          const TituloSecao('Por central'),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Central')),
                  DataColumn(label: Text('Pedidos'), numeric: true),
                  DataColumn(label: Text('Entregues'), numeric: true),
                  DataColumn(label: Text('Cancelados'), numeric: true),
                  DataColumn(label: Text('Faturamento'), numeric: true),
                ],
                rows: [
                  for (final c in relatorio.centrais)
                    DataRow(cells: [
                      DataCell(Text(c.centralNome)),
                      DataCell(Text('${c.pedidos}')),
                      DataCell(Text('${c.entregues}')),
                      DataCell(Text('${c.cancelados}')),
                      DataCell(Text(c.faturamento.formatarEmReais())),
                    ]),
                ],
              ),
            ),
          ),
        ],
        const TituloSecao('Produtos entregues'),
        if (relatorio.produtos.isEmpty) const Text('Nenhuma entrega concluída no período.'),
        for (final p in relatorio.produtos)
          LinhaValor(rotulo: '${p.quantidade}x ${p.produtoNome}', valor: p.valor.formatarEmReais()),
        if (relatorio.dias.length > 1) ...[
          const TituloSecao('Dia a dia'),
          for (final d in relatorio.dias)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 92, child: Text(Datas.rotuloDia(d.dia))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 14,
                        value: maiorDia == 0 ? 0 : d.faturamento.centavos / maiorDia,
                        backgroundColor: tema.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: Text(
                      '${d.faturamento.formatarEmReais()} · ${d.entregues}',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Cada linha: faturamento do dia · entregas feitas.'),
          ),
        ],
      ],
    );
  }
}
