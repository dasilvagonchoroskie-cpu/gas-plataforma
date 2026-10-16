import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../comum/acoes_externas.dart';
import '../../estado/provedores.dart';

typedef _DadosCliente = ({
  FichaCliente? ficha,
  ResumoCredito resumo,
  List<LancamentoCredito> extrato,
});

final _provedorCliente = FutureProvider.autoDispose
    .family<_DadosCliente, ({String id, bool comFicha})>(
  (ref, chave) async {
    final credito = ref.watch(provedorCredito);
    final resultados = await Future.wait<Object?>([
      chave.comFicha
          ? credito.fichaCompleta(chave.id)
          : Future<Object?>.value(),
      credito.resumo(chave.id),
      credito.extrato(chave.id),
    ]);
    return (
      ficha: resultados[0] as FichaCliente?,
      resumo: resultados[1] as ResumoCredito,
      extrato: resultados[2] as List<LancamentoCredito>,
    );
  },
);

/// Ficha, crediário e extrato de um cliente, com as ações de quem administra.
class TelaClienteCredito extends ConsumerStatefulWidget {
  const TelaClienteCredito({
    required this.clienteId,
    required this.nome,
    required this.podeAnalisar,
    required this.ehDono,
    this.telefone,
    super.key,
  });

  final String clienteId;
  final String nome;
  final String? telefone;

  /// Pode ver a ficha completa e aprovar (dono, ou central liberada).
  final bool podeAnalisar;
  final bool ehDono;

  @override
  ConsumerState<TelaClienteCredito> createState() => _TelaClienteCreditoState();
}

class _TelaClienteCreditoState extends ConsumerState<TelaClienteCredito> {
  ({String id, bool comFicha}) get _chave =>
      (id: widget.clienteId, comFicha: widget.podeAnalisar);

  Future<void> _executar(Future<void> Function() acao, String sucesso) async {
    try {
      await acao();
      if (mounted) {
        mostrarMensagem(context, sucesso);
      }
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    } finally {
      ref
        ..invalidate(_provedorCliente(_chave))
        ..invalidate(provedorFichasPendentes);
    }
  }

  Future<void> _aprovar(FichaCliente ficha) async {
    final teto =
        ref.read(provedorConfiguracoes).valueOrNull?.limiteMaximoCentral;
    final limite = await showDialog<Dinheiro>(
      context: context,
      builder: (_) => _DialogoValor(
        titulo: ficha.status == StatusFicha.aprovada
            ? 'Mudar limite'
            : 'Aprovar ficha',
        rotulo: 'Limite do crediário',
        inicial: ficha.status == StatusFicha.aprovada ? ficha.limite : null,
        ajuda: !widget.ehDono && teto != null
            ? 'A central pode liberar até ${teto.formatarEmReais()}.'
            : null,
        permiteZero: true,
        rotuloConfirmar:
            ficha.status == StatusFicha.aprovada ? 'Salvar limite' : 'Aprovar',
      ),
    );
    if (limite == null) {
      return;
    }
    await _executar(
      () => ref.read(provedorCredito).aprovar(widget.clienteId, limite),
      'Ficha aprovada com limite de ${limite.formatarEmReais()}.',
    );
  }

  Future<void> _recusar() async {
    final motivo = await pedirTexto(
      context,
      titulo: 'Recusar ficha',
      rotulo: 'Motivo (o cliente vai ver)',
      rotuloConfirmar: 'Recusar',
      sugestoes: const [
        'Foto do documento ilegível',
        'Comprovante de endereço inválido',
        'Referências não confirmadas',
        'Dados não conferem',
      ],
    );
    if (motivo == null || motivo.isEmpty) {
      return;
    }
    await _executar(
        () => ref.read(provedorCredito).recusar(widget.clienteId, motivo),
        'Ficha recusada.');
  }

  Future<void> _bloquear(bool bloquear) async {
    String? motivo;
    if (bloquear) {
      motivo = await pedirTexto(
        context,
        titulo: 'Bloquear o fiado',
        rotulo: 'Motivo',
        rotuloConfirmar: 'Bloquear',
        sugestoes: const [
          'Pagamento atrasado',
          'Pedido do cliente',
          'Em análise'
        ],
      );
      if (motivo == null || motivo.isEmpty) {
        return;
      }
    }
    await _executar(
      () => ref.read(provedorCredito).definirBloqueio(widget.clienteId,
          bloqueado: bloquear, motivo: motivo),
      bloquear ? 'Fiado bloqueado.' : 'Fiado liberado.',
    );
  }

  Future<void> _receber(ResumoCredito resumo) async {
    final pagamento = await showDialog<
        ({Dinheiro valor, FormaPagamento forma, String observacao})>(
      context: context,
      builder: (_) => _DialogoPagamento(devido: resumo.devido),
    );
    if (pagamento == null) {
      return;
    }
    await _executar(
      () => ref.read(provedorCredito).registrarPagamento(
            clienteId: widget.clienteId,
            valor: pagamento.valor,
            forma: pagamento.forma,
            observacao: pagamento.observacao,
          ),
      'Pagamento de ${pagamento.valor.formatarEmReais()} registrado.',
    );
  }

  Future<void> _ajustar() async {
    final ajuste = await showDialog<({Dinheiro valor, String motivo})>(
      context: context,
      builder: (_) => const _DialogoAjuste(),
    );
    if (ajuste == null) {
      return;
    }
    await _executar(
      () => ref.read(provedorCredito).ajustar(
          clienteId: widget.clienteId,
          valor: ajuste.valor,
          motivo: ajuste.motivo),
      'Ajuste registrado.',
    );
  }

  Future<void> _verFoto(String titulo, String caminho) async {
    try {
      final link = await ref.read(provedorCredito).linkDaFoto(caminho);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (contexto) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(titulo),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                      onPressed: () => Navigator.of(contexto).pop(),
                      icon: const Icon(Icons.close)),
                ],
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    link,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, filho, progresso) => progresso == null
                        ? filho
                        : const Padding(
                            padding: EdgeInsets.all(40), child: Carregando()),
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('Não foi possível abrir a foto.'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dados = ref.watch(_provedorCliente(_chave));
    return Scaffold(
      appBar: AppBar(title: Text(widget.nome)),
      body: dados.when(
        loading: () => const Carregando(),
        error: (erro, _) => EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () => ref.invalidate(_provedorCliente(_chave)),
        ),
        data: (d) => RefreshIndicator(
          onRefresh: () => ref.refresh(_provedorCliente(_chave).future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LarguraMaxima(
                largura: 860,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _conteudo(d),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _conteudo(_DadosCliente d) {
    final tema = Theme.of(context);
    final ficha = d.ficha;
    final resumo = d.resumo;
    final telefone = ficha?.telefone ?? widget.telefone;
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (telefone != null && telefone.isNotEmpty) ...[
            OutlinedButton.icon(
              onPressed: () => ligar(context, telefone),
              icon: const Icon(Icons.call_outlined),
              label: Text(Validacoes.formatarTelefone(telefone)),
            ),
            OutlinedButton.icon(
              onPressed: () => abrirWhatsapp(context, telefone),
              icon: const Icon(Icons.chat_outlined),
              label: const Text('WhatsApp'),
            ),
          ],
        ],
      ),
      const TituloSecao('Crediário'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      resumo.status == null
                          ? 'Sem ficha'
                          : resumo.bloqueado
                              ? 'Fiado bloqueado'
                              : resumo.status!.rotulo,
                      style: tema.textTheme.titleMedium,
                    ),
                  ),
                  Text('Deve ${resumo.devido.formatarEmReais()}',
                      style: tema.textTheme.titleMedium?.copyWith(
                          color: resumo.devido.ehZero
                              ? null
                              : tema.colorScheme.error)),
                ],
              ),
              const Divider(),
              LinhaValor(
                  rotulo: 'Limite', valor: resumo.limite.formatarEmReais()),
              LinhaValor(
                  rotulo: 'Pedidos fiado a caminho',
                  valor: resumo.reservado.formatarEmReais()),
              LinhaValor(
                  rotulo: 'Livre para comprar',
                  valor: resumo.disponivel.formatarEmReais(),
                  destaque: true),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (resumo.devido.centavos > 0)
                    FilledButton.icon(
                      onPressed: () => _receber(resumo),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Registrar pagamento'),
                    ),
                  if (widget.ehDono)
                    OutlinedButton.icon(
                      onPressed: _ajustar,
                      icon: const Icon(Icons.tune),
                      label: const Text('Ajuste'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      if (ficha != null) ..._ficha(ficha),
      if (ficha == null && widget.podeAnalisar)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text('Este cliente ainda não enviou a ficha.'),
        ),
      if (!widget.podeAnalisar)
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: Text(
              'Os dados da ficha (CPF, renda, fotos) ficam só com a Super Central.'),
        ),
      const TituloSecao('Extrato'),
      if (d.extrato.isEmpty) const Text('Nenhum lançamento ainda.'),
      for (final l in d.extrato) LinhaLancamento(lancamento: l),
    ];
  }

  List<Widget> _ficha(FichaCliente f) {
    return [
      TituloSecao(
        'Ficha de cadastro',
        acao: Chip(
            label: Text(f.status.rotulo), visualDensity: VisualDensity.compact),
      ),
      if (f.motivo != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Observação: ${f.motivo}'),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (f.status != StatusFicha.aprovada)
            FilledButton.icon(
              onPressed: () => _aprovar(f),
              icon: const Icon(Icons.check),
              label: const Text('Aprovar'),
            ),
          if (f.status == StatusFicha.aprovada)
            FilledButton.tonalIcon(
              onPressed: () => _aprovar(f),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Mudar limite'),
            ),
          if (f.status != StatusFicha.recusada)
            OutlinedButton.icon(
              onPressed: _recusar,
              icon: const Icon(Icons.block),
              label: const Text('Recusar'),
            ),
          if (f.status == StatusFicha.aprovada)
            OutlinedButton.icon(
              onPressed: () => _bloquear(!f.creditoBloqueado),
              icon: Icon(
                  f.creditoBloqueado ? Icons.lock_open : Icons.lock_outline),
              label:
                  Text(f.creditoBloqueado ? 'Liberar fiado' : 'Bloquear fiado'),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinhaValor(rotulo: 'CPF', valor: Validacoes.formatarCpf(f.cpf)),
              LinhaValor(rotulo: 'RG', valor: f.rg),
              LinhaValor(
                rotulo: 'Nascimento',
                valor:
                    '${Datas.formatarData(f.dataNascimento)} (${Datas.idade(f.dataNascimento)} anos)',
              ),
              LinhaValor(rotulo: 'Mãe', valor: f.nomeMae),
              if (f.email != null)
                LinhaValor(rotulo: 'E-mail', valor: f.email!),
              LinhaValor(rotulo: 'Mora em', valor: f.enderecoTexto ?? '-'),
              LinhaValor(
                  rotulo: 'Central da região',
                  valor: f.centralNome ?? 'Nenhuma atende'),
              const Divider(),
              LinhaValor(
                  rotulo: 'Trabalho', valor: '${f.profissao} · ${f.empresa}'),
              if (f.telefoneTrabalho.isNotEmpty)
                LinhaValor(
                    rotulo: 'Telefone do trabalho',
                    valor: Validacoes.formatarTelefone(f.telefoneTrabalho)),
              LinhaValor(
                  rotulo: 'Renda por mês',
                  valor: f.rendaMensal.formatarEmReais()),
              const Divider(),
              _Referencia(
                  nome: f.referencia1Nome,
                  telefone: f.referencia1Telefone,
                  relacao: f.referencia1Relacao),
              _Referencia(
                  nome: f.referencia2Nome,
                  telefone: f.referencia2Telefone,
                  relacao: f.referencia2Relacao),
              const Divider(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _verFoto('Documento', f.documentoCaminho),
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Ver documento'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _verFoto(
                        'Comprovante de endereço', f.comprovanteCaminho),
                    icon: const Icon(Icons.receipt_outlined),
                    label: const Text('Ver comprovante'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Enviada em ${Datas.formatarDataHora(f.enviadoEm)}'
                '${f.analisadoEm == null ? '' : ' · analisada em ${Datas.formatarDataHora(f.analisadoEm!)}'}'
                '${f.analisadoPorNome == null ? '' : ' por ${f.analisadoPorNome}'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _Referencia extends StatelessWidget {
  const _Referencia(
      {required this.nome, required this.telefone, required this.relacao});

  final String nome;
  final String telefone;
  final String relacao;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_outline),
      title: Text('$nome ($relacao)'),
      subtitle: Text(Validacoes.formatarTelefone(telefone)),
      trailing: IconButton(
        tooltip: 'Ligar para a referência',
        onPressed: () => ligar(context, telefone),
        icon: const Icon(Icons.call_outlined),
      ),
    );
  }
}

/// Pede um valor em reais.
class _DialogoValor extends StatefulWidget {
  const _DialogoValor({
    required this.titulo,
    required this.rotulo,
    required this.rotuloConfirmar,
    this.inicial,
    this.ajuda,
    this.permiteZero = false,
  });

  final String titulo;
  final String rotulo;
  final String rotuloConfirmar;
  final Dinheiro? inicial;
  final String? ajuda;
  final bool permiteZero;

  @override
  State<_DialogoValor> createState() => _DialogoValorState();
}

class _DialogoValorState extends State<_DialogoValor> {
  late final _valor =
      TextEditingController(text: widget.inicial?.formatarParaEdicao() ?? '');
  String? _erro;

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  void _confirmar() {
    final valor = Dinheiro.lerReais(_valor.text);
    if (valor == null || (!widget.permiteZero && valor.ehZero)) {
      setState(() => _erro = 'Digite o valor em reais, ex.: 300,00');
      return;
    }
    Navigator.of(context).pop(valor);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _valor,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
            ],
            decoration: InputDecoration(
                labelText: widget.rotulo, prefixText: 'R\$ ', errorText: _erro),
            onSubmitted: (_) => _confirmar(),
          ),
          if (widget.ajuda != null) ...[
            const SizedBox(height: 8),
            Text(widget.ajuda!),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Voltar')),
        FilledButton(
            onPressed: _confirmar, child: Text(widget.rotuloConfirmar)),
      ],
    );
  }
}

class _DialogoPagamento extends StatefulWidget {
  const _DialogoPagamento({required this.devido});

  final Dinheiro devido;

  @override
  State<_DialogoPagamento> createState() => _DialogoPagamentoState();
}

class _DialogoPagamentoState extends State<_DialogoPagamento> {
  final _valor = TextEditingController();
  final _observacao = TextEditingController();
  FormaPagamento _forma = FormaPagamento.dinheiro;
  String? _erro;

  @override
  void dispose() {
    _valor.dispose();
    _observacao.dispose();
    super.dispose();
  }

  void _confirmar() {
    final valor = Dinheiro.lerReais(_valor.text);
    if (valor == null || valor.ehZero) {
      setState(() => _erro = 'Digite o valor recebido.');
      return;
    }
    if (valor > widget.devido) {
      setState(
          () => _erro = 'O cliente deve ${widget.devido.formatarEmReais()}.');
      return;
    }
    Navigator.of(context)
        .pop((valor: valor, forma: _forma, observacao: _observacao.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Registrar pagamento'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Deve ${widget.devido.formatarEmReais()}'),
            const SizedBox(height: 8),
            TextField(
              controller: _valor,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              decoration: InputDecoration(
                  labelText: 'Valor recebido',
                  prefixText: 'R\$ ',
                  errorText: _erro),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(
                    () => _valor.text = widget.devido.formatarParaEdicao()),
                child: const Text('Pagou tudo'),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in FormaPagamento.paraReceber)
                  ChoiceChip(
                    label: Text(f.rotulo),
                    selected: _forma == f,
                    onSelected: (_) => setState(() => _forma = f),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _observacao,
              maxLength: 300,
              decoration:
                  const InputDecoration(labelText: 'Observação (opcional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Voltar')),
        FilledButton(onPressed: _confirmar, child: const Text('Registrar')),
      ],
    );
  }
}

class _DialogoAjuste extends StatefulWidget {
  const _DialogoAjuste();

  @override
  State<_DialogoAjuste> createState() => _DialogoAjusteState();
}

class _DialogoAjusteState extends State<_DialogoAjuste> {
  final _valor = TextEditingController();
  final _motivo = TextEditingController();
  bool _aumenta = false;
  String? _erro;

  @override
  void dispose() {
    _valor.dispose();
    _motivo.dispose();
    super.dispose();
  }

  void _confirmar() {
    final valor = Dinheiro.lerReais(_valor.text);
    if (valor == null || valor.ehZero) {
      setState(() => _erro = 'Digite o valor.');
      return;
    }
    if (_motivo.text.trim().isEmpty) {
      setState(() => _erro = 'Informe o motivo.');
      return;
    }
    Navigator.of(context).pop((
      valor: _aumenta ? valor : Dinheiro(-valor.centavos),
      motivo: _motivo.text
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajuste no crediário'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Diminuir a dívida')),
                ButtonSegment(value: true, label: Text('Aumentar a dívida')),
              ],
              selected: {_aumenta},
              onSelectionChanged: (s) => setState(() => _aumenta = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valor,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              decoration:
                  const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _motivo,
              maxLength: 300,
              decoration: InputDecoration(
                  labelText: 'Motivo (fica na auditoria)', errorText: _erro),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Voltar')),
        FilledButton(
            onPressed: _confirmar, child: const Text('Registrar ajuste')),
      ],
    );
  }
}
