import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

final _provedorAgenda = FutureProvider.autoDispose<List<HorarioDisponivel>>((ref) async {
  final atendimento = await ref.watch(provedorAtendimento.future);
  if (atendimento == null) {
    return const [];
  }
  return ref.watch(provedorRepositorioPedidos).agenda(atendimento.centralId);
});

/// Escolha do dia e do horário. Tocar num horário já leva para o resumo.
class TelaHorario extends ConsumerStatefulWidget {
  const TelaHorario({super.key});

  @override
  ConsumerState<TelaHorario> createState() => _TelaHorarioState();
}

class _TelaHorarioState extends ConsumerState<TelaHorario> {
  DateTime? _dia;

  @override
  Widget build(BuildContext context) {
    final agenda = ref.watch(_provedorAgenda);
    final escolhido = ref.watch(provedorFinalizacao).horario;

    return Scaffold(
      appBar: AppBar(title: const Text('Quando entregar?')),
      body: agenda.when(
        loading: () => const Carregando(mensagem: 'Buscando horários livres...'),
        error: (erro, _) => EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () => ref.invalidate(_provedorAgenda),
        ),
        data: (horarios) {
          if (horarios.isEmpty) {
            return EstadoVazio(
              icone: Icons.event_busy_outlined,
              titulo: 'Sem horários livres',
              mensagem: 'A central não tem horários disponíveis nos próximos dias. '
                  'Fale com ela pelo WhatsApp.',
              rotuloAcao: 'Tentar de novo',
              aoAcionar: () => ref.invalidate(_provedorAgenda),
            );
          }
          final dias = <DateTime>[];
          for (final h in horarios) {
            if (!dias.contains(h.data)) {
              dias.add(h.data);
            }
          }
          final dia = _dia != null && dias.contains(_dia) ? _dia! : dias.first;
          final doDia = horarios.where((h) => h.data == dia).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Dia', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: dias.length,
                  separatorBuilder: (context, indice) => const SizedBox(width: 8),
                  itemBuilder: (context, indice) {
                    final d = dias[indice];
                    return ChoiceChip(
                      label: Text(Datas.rotuloDia(d)),
                      selected: d == dia,
                      onSelected: (_) => setState(() => _dia = d),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Text('Horário', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final horario in doDia)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        escolhido?.janelaId == horario.janelaId && escolhido?.data == horario.data
                            ? Icons.radio_button_checked
                            : Icons.schedule,
                      ),
                      title: Text(horario.intervalo, style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text(
                        horario.vagas <= 3
                            ? 'Últimas ${horario.vagas} vagas'
                            : 'Horário disponível',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ref.read(provedorFinalizacao.notifier).escolherHorario(horario);
                        context.push('/finalizar');
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
