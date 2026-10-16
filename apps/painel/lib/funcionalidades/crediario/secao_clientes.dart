import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';
import '../dono/painel_dono.dart';
import 'tela_cliente_credito.dart';

typedef _FiltroFichas = ({StatusFicha? status, String busca});

final _provedorFichas = FutureProvider.autoDispose.family<List<ItemFicha>, _FiltroFichas>(
  (ref, filtro) => ref.watch(provedorCredito).fichas(status: filtro.status, busca: filtro.busca),
);

final _provedorDevedores = FutureProvider.autoDispose.family<List<Devedor>, String?>(
  (ref, centralId) => ref.watch(provedorCredito).devedores(centralId: centralId),
);

/// Clientes e crediário. No painel do dono (Super Central) mostra todas as
/// fichas e as configurações; na central, as fichas dela (se o dono liberar)
/// e quem deve.
class SecaoClientes extends ConsumerStatefulWidget {
  const SecaoClientes({required this.ehDono, super.key});

  final bool ehDono;

  @override
  ConsumerState<SecaoClientes> createState() => _SecaoClientesState();
}

class _SecaoClientesState extends ConsumerState<SecaoClientes> {
  bool _verDevedores = false;
  StatusFicha? _status = StatusFicha.pendente;
  String _busca = '';
  String? _centralDevedores;
  final _campoBusca = TextEditingController();

  @override
  void dispose() {
    _campoBusca.dispose();
    super.dispose();
  }

  Future<void> _abrir({
    required String clienteId,
    required String nome,
    required bool podeAnalisar,
    String? telefone,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TelaClienteCredito(
          clienteId: clienteId,
          nome: nome,
          telefone: telefone,
          podeAnalisar: podeAnalisar,
          ehDono: widget.ehDono,
        ),
      ),
    );
    ref
      ..invalidate(_provedorFichas)
      ..invalidate(_provedorDevedores)
      ..invalidate(provedorFichasPendentes);
  }

  @override
  Widget build(BuildContext context) {
    final configuracoes = ref.watch(provedorConfiguracoes);
    final centralAprova = configuracoes.valueOrNull?.centraisAprovamCredito ?? false;
    final verFichas = widget.ehDono || centralAprova;
    final mostrarDevedores = _verDevedores || !verFichas;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: [
                    if (verFichas) const ButtonSegment(value: false, icon: Icon(Icons.badge_outlined), label: Text('Fichas')),
                    const ButtonSegment(value: true, icon: Icon(Icons.payments_outlined), label: Text('Quem deve')),
                  ],
                  selected: {mostrarDevedores},
                  onSelectionChanged: (s) => setState(() => _verDevedores = s.first),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: mostrarDevedores
              ? _listaDevedores(podeAnalisar: verFichas)
              : _listaFichas(configuracoes.valueOrNull),
        ),
      ],
    );
  }

  Widget _listaFichas(Configuracoes? configuracoes) {
    final filtro = (status: _status, busca: _busca);
    final fichas = ref.watch(_provedorFichas(filtro));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(_provedorFichas(filtro).future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (widget.ehDono && configuracoes != null) _CartaoConfiguracoes(atual: configuracoes),
          TextField(
            controller: _campoBusca,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Buscar por nome, CPF ou telefone',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _busca.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _campoBusca.clear();
                        _busca = '';
                      }),
                    ),
            ),
            onSubmitted: (t) => setState(() => _busca = t.trim()),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opcao in <(String, StatusFicha?)>[
                ('Em análise', StatusFicha.pendente),
                ('Aprovadas', StatusFicha.aprovada),
                ('Recusadas', StatusFicha.recusada),
                ('Todas', null),
              ])
                ChoiceChip(
                  label: Text(opcao.$1),
                  selected: _status == opcao.$2,
                  onSelected: (_) => setState(() => _status = opcao.$2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...fichas.when<List<Widget>>(
            loading: () => const [Padding(padding: EdgeInsets.all(32), child: Carregando())],
            error: (erro, _) => [
              EstadoErro(
                mensagem: mensagemDeErro(erro),
                aoTentarNovamente: () => ref.invalidate(_provedorFichas(filtro)),
              ),
            ],
            data: (lista) => lista.isEmpty
                ? [
                    EstadoVazio(
                      icone: Icons.badge_outlined,
                      titulo: _status == StatusFicha.pendente ? 'Nenhuma ficha esperando' : 'Nenhuma ficha aqui',
                    ),
                  ]
                : [
                    for (final f in lista)
                      Card(
                        child: ListTile(
                          leading: Icon(switch (f.status) {
                            StatusFicha.pendente => Icons.hourglass_top,
                            StatusFicha.aprovada => f.creditoBloqueado ? Icons.lock_outline : Icons.verified_outlined,
                            StatusFicha.recusada => Icons.block,
                          }),
                          title: Text(f.nome),
                          subtitle: Text(
                            [
                              '${f.status.rotulo}${f.creditoBloqueado ? ' · fiado bloqueado' : ''}',
                              'CPF ${Validacoes.cpfMascarado(f.cpf)} · ${Validacoes.formatarTelefone(f.telefone)}',
                              if (f.status == StatusFicha.aprovada)
                                'Limite ${f.limite.formatarEmReais()} · deve ${f.devido.formatarEmReais()}',
                              if (widget.ehDono) f.centralNome ?? 'Fora da área das centrais',
                            ].join('\n'),
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _abrir(
                            clienteId: f.clienteId,
                            nome: f.nome,
                            telefone: f.telefone,
                            podeAnalisar: true,
                          ),
                        ),
                      ),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _listaDevedores({required bool podeAnalisar}) {
    final devedores = ref.watch(_provedorDevedores(_centralDevedores));
    return Column(
      children: [
        if (widget.ehDono)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SeletorCentral(
                selecionada: _centralDevedores,
                permitirTodas: true,
                aoEscolher: (id) => setState(() => _centralDevedores = id),
              ),
            ),
          ),
        Expanded(
          child: devedores.when(
            loading: () => const Carregando(),
            error: (erro, _) => EstadoErro(
              mensagem: mensagemDeErro(erro),
              aoTentarNovamente: () => ref.invalidate(_provedorDevedores(_centralDevedores)),
            ),
            data: (lista) {
              if (lista.isEmpty) {
                return const EstadoVazio(icone: Icons.check_circle_outline, titulo: 'Ninguém devendo no fiado');
              }
              final total = lista.fold(Dinheiro.zero, (s, d) => s + d.devido);
              return RefreshIndicator(
                onRefresh: () => ref.refresh(_provedorDevedores(_centralDevedores).future),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text(
                      '${lista.length} ${lista.length == 1 ? 'cliente deve' : 'clientes devem'} '
                      '${total.formatarEmReais()} no total',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final d in lista)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(d.nome),
                          subtitle: Text(
                            '${Validacoes.formatarTelefone(d.telefone)}'
                            '${d.ultimaCompra == null ? '' : ' · última compra ${Datas.formatarData(d.ultimaCompra!)}'}',
                          ),
                          trailing: Text(
                            d.devido.formatarEmReais(),
                            style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.error),
                          ),
                          onTap: () => _abrir(
                            clienteId: d.clienteId,
                            nome: d.nome,
                            telefone: d.telefone,
                            podeAnalisar: podeAnalisar,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Configuração do dono: as centrais podem aprovar fichas? Até quanto?
class _CartaoConfiguracoes extends ConsumerStatefulWidget {
  const _CartaoConfiguracoes({required this.atual});

  final Configuracoes atual;

  @override
  ConsumerState<_CartaoConfiguracoes> createState() => _CartaoConfiguracoesState();
}

class _CartaoConfiguracoesState extends ConsumerState<_CartaoConfiguracoes> {
  late bool _liberado = widget.atual.centraisAprovamCredito;
  late final _teto = TextEditingController(text: widget.atual.limiteMaximoCentral?.formatarParaEdicao() ?? '');
  bool _salvando = false;
  bool _aberto = false;

  @override
  void dispose() {
    _teto.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final textoTeto = _teto.text.trim();
    final teto = textoTeto.isEmpty ? null : Dinheiro.lerReais(textoTeto);
    if (textoTeto.isNotEmpty && teto == null) {
      mostrarMensagem(context, 'Digite o limite máximo em reais, ex.: 300,00 (ou deixe vazio).', erro: true);
      return;
    }
    setState(() => _salvando = true);
    try {
      await ref.read(provedorCredito).salvarConfiguracoes(
            Configuracoes(centraisAprovamCredito: _liberado, limiteMaximoCentral: teto),
          );
      ref.invalidate(provedorConfiguracoes);
      if (mounted) {
        mostrarMensagem(context, 'Configuração salva.');
      }
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final atual = widget.atual;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Quem aprova as fichas'),
            subtitle: Text(
              atual.centraisAprovamCredito
                  ? 'Você e as centrais'
                      '${atual.limiteMaximoCentral == null ? '' : ' (até ${atual.limiteMaximoCentral!.formatarEmReais()})'}'
                  : 'Só você (Super Central)',
            ),
            trailing: Icon(_aberto ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _aberto = !_aberto),
          ),
          if (_aberto)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    value: _liberado,
                    onChanged: (v) => setState(() => _liberado = v),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('As centrais também podem aprovar'),
                    subtitle: const Text('Cada central aprova os clientes da região dela e vê a ficha completa.'),
                  ),
                  if (_liberado)
                    TextField(
                      controller: _teto,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: const InputDecoration(
                        labelText: 'Maior limite que a central pode liberar',
                        helperText: 'Deixe vazio para não ter teto.',
                        prefixText: 'R\$ ',
                      ),
                    ),
                  const SizedBox(height: 12),
                  BotaoPrincipal(rotulo: 'Salvar', carregando: _salvando, aoPressionar: _salvar),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
