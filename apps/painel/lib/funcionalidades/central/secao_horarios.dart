import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

final _provedorJanelas =
    FutureProvider.autoDispose.family<List<JanelaEntrega>, String>(
  (ref, centralId) => ref.watch(provedorGestao).janelas(centralId),
);

final _provedorBloqueios =
    FutureProvider.autoDispose.family<List<BloqueioAgenda>, String>(
  (ref, centralId) => ref.watch(provedorGestao).bloqueios(centralId),
);

String _hora(TimeOfDay hora) =>
    '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}:00';

/// Horários de entrega (por dia da semana, com quantos pedidos cabem) e dias
/// ou horários bloqueados (feriado, falta de entregador...).
class SecaoHorarios extends ConsumerWidget {
  const SecaoHorarios({required this.centralId, super.key});

  final String centralId;

  Future<void> _rodar(BuildContext context, WidgetRef ref,
      Future<void> Function() acao, String ok) async {
    try {
      await acao();
      ref.invalidate(_provedorJanelas(centralId));
      ref.invalidate(_provedorBloqueios(centralId));
      if (context.mounted) {
        mostrarMensagem(context, ok);
      }
    } catch (erro) {
      if (context.mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    }
  }

  Future<void> _novoHorario(BuildContext context, WidgetRef ref) async {
    final dados = await showDialog<_NovoHorario>(
      context: context,
      builder: (_) => const _DialogoNovoHorario(),
    );
    if (dados == null || !context.mounted) {
      return;
    }
    await _rodar(
      context,
      ref,
      () => ref.read(provedorGestao).criarJanela(
            centralId: centralId,
            diasSemana: dados.dias,
            horaInicio: _hora(dados.inicio),
            horaFim: _hora(dados.fim),
            capacidade: dados.capacidade,
          ),
      'Horário criado.',
    );
  }

  Future<void> _mudarCapacidade(
      BuildContext context, WidgetRef ref, JanelaEntrega janela) async {
    final texto = await pedirTexto(
      context,
      titulo: 'Pedidos por horário',
      rotulo: 'Quantos pedidos cabem em ${janela.intervalo}?',
      maximo: 3,
    );
    final capacidade = int.tryParse(texto ?? '');
    if (texto == null || !context.mounted) {
      return;
    }
    if (capacidade == null || capacidade < 1 || capacidade > 500) {
      mostrarMensagem(context, 'Digite um número de 1 a 500.', erro: true);
      return;
    }
    await _rodar(
      context,
      ref,
      () => ref
          .read(provedorGestao)
          .atualizarJanela(janela.id, capacidade: capacidade),
      'Capacidade atualizada.',
    );
  }

  Future<void> _bloquear(
      BuildContext context, WidgetRef ref, List<JanelaEntrega> janelas) async {
    final hoje = Datas.hoje();
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime(hoje.year, hoje.month, hoje.day),
      firstDate: DateTime(hoje.year, hoje.month, hoje.day),
      lastDate: DateTime(hoje.year + 1, hoje.month, hoje.day),
      helpText: 'Dia sem entrega',
    );
    if (data == null || !context.mounted) {
      return;
    }
    final dia = DateTime.utc(data.year, data.month, data.day);
    final doDia = janelas
        .where((j) => j.diaSemana == Datas.diaDaSemana(dia) && j.ativa)
        .toList();
    final janelaId = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Bloquear ${Datas.formatarData(dia)}'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(''),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('O dia inteiro', style: TextStyle(fontSize: 18)),
            ),
          ),
          for (final j in doDia)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(j.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Só ${j.intervalo}',
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
        ],
      ),
    );
    if (janelaId == null || !context.mounted) {
      return;
    }
    final motivo = await pedirTexto(
      context,
      titulo: 'Motivo do bloqueio',
      rotulo: 'Motivo',
      maximo: 200,
      sugestoes: const [
        'Feriado',
        'Sem entregador',
        'Falta de produto',
        'Manutenção'
      ],
    );
    if (motivo == null || !context.mounted) {
      return;
    }
    await _rodar(
      context,
      ref,
      () => ref.read(provedorGestao).bloquear(
            centralId: centralId,
            data: dia,
            motivo: motivo,
            janelaId: janelaId.isEmpty ? null : janelaId,
          ),
      'Bloqueio criado. Os clientes não verão esse horário.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final janelas = ref.watch(_provedorJanelas(centralId));
    final bloqueios = ref.watch(_provedorBloqueios(centralId));
    final lista = janelas.valueOrNull ?? const <JanelaEntrega>[];

    return janelas.when(
      loading: () => const Carregando(),
      error: (erro, _) => EstadoErro(
        mensagem: mensagemDeErro(erro),
        aoTentarNovamente: () => ref.invalidate(_provedorJanelas(centralId)),
      ),
      data: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LarguraMaxima(
            largura: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TituloSecao(
                  'Horários de entrega',
                  acao: FilledButton.icon(
                    onPressed: () => _novoHorario(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Novo horário'),
                  ),
                ),
                const Text(
                    'O cliente só vê horários ativos que ainda têm vaga.'),
                const SizedBox(height: 8),
                for (var dia = 0; dia < 7; dia++) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      Datas.nomeDiaLongo(dia),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (!lista.any((j) => j.diaSemana == dia))
                    const Text('Sem entregas neste dia.')
                  else
                    for (final janela in lista.where((j) => j.diaSemana == dia))
                      Card(
                        child: ListTile(
                          title: Text(janela.intervalo),
                          subtitle: Text('Até ${janela.capacidade} pedidos'),
                          leading: Switch(
                            value: janela.ativa,
                            onChanged: (ativa) => _rodar(
                              context,
                              ref,
                              () => ref
                                  .read(provedorGestao)
                                  .atualizarJanela(janela.id, ativa: ativa),
                              ativa
                                  ? 'Horário ativado.'
                                  : 'Horário desativado.',
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: 'Mudar quantos pedidos cabem',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () =>
                                _mudarCapacidade(context, ref, janela),
                          ),
                        ),
                      ),
                ],
                TituloSecao(
                  'Dias e horários bloqueados',
                  acao: OutlinedButton.icon(
                    onPressed: () => _bloquear(context, ref, lista),
                    icon: const Icon(Icons.block),
                    label: const Text('Bloquear'),
                  ),
                ),
                ...bloqueios.when<List<Widget>>(
                  loading: () => const [LinearProgressIndicator()],
                  error: (erro, _) => [Text(mensagemDeErro(erro))],
                  data: (itens) => itens.isEmpty
                      ? const [Text('Nenhum bloqueio programado.')]
                      : [
                          for (final b in itens)
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.event_busy),
                                title: Text(
                                  '${Datas.formatarData(b.data)} · '
                                  '${b.janelaId == null ? 'dia inteiro' : _intervaloDe(lista, b.janelaId!)}',
                                ),
                                subtitle: Text(b.motivo),
                                trailing: IconButton(
                                  tooltip: 'Tirar o bloqueio',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _rodar(
                                    context,
                                    ref,
                                    () => ref
                                        .read(provedorGestao)
                                        .desbloquear(b.id),
                                    'Bloqueio removido.',
                                  ),
                                ),
                              ),
                            ),
                        ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _intervaloDe(List<JanelaEntrega> janelas, String id) {
    for (final j in janelas) {
      if (j.id == id) {
        return j.intervalo;
      }
    }
    return 'um horário';
  }
}

class _NovoHorario {
  const _NovoHorario(this.dias, this.inicio, this.fim, this.capacidade);

  final List<int> dias;
  final TimeOfDay inicio;
  final TimeOfDay fim;
  final int capacidade;
}

class _DialogoNovoHorario extends StatefulWidget {
  const _DialogoNovoHorario();

  @override
  State<_DialogoNovoHorario> createState() => _DialogoNovoHorarioState();
}

class _DialogoNovoHorarioState extends State<_DialogoNovoHorario> {
  final Set<int> _dias = {1, 2, 3, 4, 5, 6};
  TimeOfDay _inicio = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _fim = const TimeOfDay(hour: 12, minute: 0);
  final _capacidade = TextEditingController(text: '10');
  String? _erro;

  @override
  void dispose() {
    _capacidade.dispose();
    super.dispose();
  }

  Future<void> _escolher(bool inicio) async {
    final hora = await showTimePicker(
        context: context, initialTime: inicio ? _inicio : _fim);
    if (hora == null) {
      return;
    }
    setState(() {
      if (inicio) {
        _inicio = hora;
      } else {
        _fim = hora;
      }
    });
  }

  void _confirmar() {
    final capacidade = int.tryParse(_capacidade.text);
    final minutosInicio = _inicio.hour * 60 + _inicio.minute;
    final minutosFim = _fim.hour * 60 + _fim.minute;
    if (_dias.isEmpty) {
      setState(() => _erro = 'Escolha pelo menos um dia.');
    } else if (minutosFim <= minutosInicio) {
      setState(() => _erro = 'O fim precisa ser depois do início.');
    } else if (capacidade == null || capacidade < 1 || capacidade > 500) {
      setState(() => _erro = 'Pedidos por horário: de 1 a 500.');
    } else {
      Navigator.of(context)
          .pop(_NovoHorario(_dias.toList()..sort(), _inicio, _fim, capacidade));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo horário de entrega'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dias da semana'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var dia = 0; dia < 7; dia++)
                  FilterChip(
                    label: Text(Datas.nomeDiaCurto(dia)),
                    selected: _dias.contains(dia),
                    onSelected: (sim) => setState(() {
                      if (sim) {
                        _dias.add(dia);
                      } else {
                        _dias.remove(dia);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolher(true),
                    child: Text('Início ${_inicio.format(context)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolher(false),
                    child: Text('Fim ${_fim.format(context)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _capacidade,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'Quantos pedidos cabem nesse horário'),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 8),
              Text(_erro!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Voltar')),
        FilledButton(onPressed: _confirmar, child: const Text('Criar')),
      ],
    );
  }
}
