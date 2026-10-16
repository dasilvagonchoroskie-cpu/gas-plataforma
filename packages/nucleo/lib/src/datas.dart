/// Datas e horas no fuso da operação (America/Sao_Paulo).
///
/// O Brasil não tem horário de verão desde 2019, então o fuso é fixo em
/// UTC-3. Os horários vêm do banco em UTC e são convertidos aqui só para exibir.
abstract final class Datas {
  static const Duration fuso = Duration(hours: -3);

  static const _diasCurtos = ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'];
  static const _diasLongos = [
    'domingo',
    'segunda-feira',
    'terça-feira',
    'quarta-feira',
    'quinta-feira',
    'sexta-feira',
    'sábado',
  ];

  /// Converte um instante (qualquer fuso) para a hora local da operação.
  static DateTime paraLocal(DateTime instante) => instante.toUtc().add(fuso);

  /// Lê um texto ISO do banco (`timestamptz`) e devolve a hora local.
  static DateTime? lerInstante(Object? valor) {
    if (valor is! String || valor.isEmpty) {
      return null;
    }
    final lido = DateTime.tryParse(valor);
    return lido == null ? null : paraLocal(lido);
  }

  /// Lê uma data simples do banco ("2026-10-16").
  static DateTime? lerData(Object? valor) {
    if (valor is! String || valor.length < 10) {
      return null;
    }
    final partes = valor.substring(0, 10).split('-');
    if (partes.length != 3) {
      return null;
    }
    return DateTime.utc(
      int.parse(partes[0]),
      int.parse(partes[1]),
      int.parse(partes[2]),
    );
  }

  /// Data para enviar ao banco ("2026-10-16").
  static String paraBanco(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';

  /// Hoje, no fuso da operação, sem horas.
  static DateTime hoje([DateTime? agora]) {
    final local = paraLocal(agora ?? DateTime.now());
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// Lê uma data digitada ("16/10/1980" ou "16101980"). Nulo se inválida.
  static DateTime? lerDataDigitada(String texto) {
    final d = texto.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length != 8) {
      return null;
    }
    final dia = int.parse(d.substring(0, 2));
    final mes = int.parse(d.substring(2, 4));
    final ano = int.parse(d.substring(4));
    final data = DateTime.utc(ano, mes, dia);
    if (data.day != dia || data.month != mes || data.year != ano) {
      return null;
    }
    return data;
  }

  /// Idade em anos completos na data de hoje (fuso da operação).
  static int idade(DateTime nascimento, {DateTime? agora}) {
    final h = hoje(agora);
    var anos = h.year - nascimento.year;
    if (h.month < nascimento.month ||
        (h.month == nascimento.month && h.day < nascimento.day)) {
      anos--;
    }
    return anos;
  }

  /// "16/10/2026".
  static String formatarData(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/'
      '${data.year}';

  /// "16/10".
  static String formatarDiaMes(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}';

  /// "16/10/2026 às 14:05".
  static String formatarDataHora(DateTime data) =>
      '${formatarData(data)} às ${formatarHoraDe(data)}';

  /// "14:05".
  static String formatarHoraDe(DateTime data) =>
      '${data.hour.toString().padLeft(2, '0')}:'
      '${data.minute.toString().padLeft(2, '0')}';

  /// "08:00:00" → "8h"; "13:30:00" → "13h30".
  static String formatarHora(String horaBanco) {
    final partes = horaBanco.split(':');
    if (partes.length < 2) {
      return horaBanco;
    }
    final hora = int.tryParse(partes[0]) ?? 0;
    final minuto = int.tryParse(partes[1]) ?? 0;
    return minuto == 0
        ? '${hora}h'
        : '${hora}h${minuto.toString().padLeft(2, '0')}';
  }

  /// "8h às 12h".
  static String formatarIntervalo(String inicio, String fim) =>
      '${formatarHora(inicio)} às ${formatarHora(fim)}';

  /// 0 = domingo ... 6 = sábado (igual ao banco).
  static int diaDaSemana(DateTime data) => data.weekday % 7;

  static String nomeDiaCurto(int diaSemana) => _diasCurtos[diaSemana % 7];

  static String nomeDiaLongo(int diaSemana) => _diasLongos[diaSemana % 7];

  /// "Hoje", "Amanhã" ou "Sex 17/10".
  static String rotuloDia(DateTime data, {DateTime? agora}) {
    final hojeLocal = hoje(agora);
    final dia = DateTime.utc(data.year, data.month, data.day);
    final diferenca = dia.difference(hojeLocal).inDays;
    if (diferenca == 0) {
      return 'Hoje';
    }
    if (diferenca == 1) {
      return 'Amanhã';
    }
    final nome = nomeDiaCurto(diaDaSemana(dia));
    return '${nome[0].toUpperCase()}${nome.substring(1)} ${formatarDiaMes(dia)}';
  }
}
