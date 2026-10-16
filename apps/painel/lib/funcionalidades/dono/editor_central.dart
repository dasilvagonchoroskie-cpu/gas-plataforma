import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

/// Criar ou editar uma central: dados, localização no mapa e faixas de entrega
/// (até quantos km entrega e com qual taxa).
class EditorCentral extends ConsumerStatefulWidget {
  const EditorCentral({this.central, super.key});

  final Central? central;

  @override
  ConsumerState<EditorCentral> createState() => _EditorCentralState();
}

class _LinhaFaixa {
  _LinhaFaixa(String km, String taxa)
      : km = TextEditingController(text: km),
        taxa = TextEditingController(text: taxa);

  final TextEditingController km;
  final TextEditingController taxa;

  void dispose() {
    km.dispose();
    taxa.dispose();
  }
}

class _EditorCentralState extends ConsumerState<EditorCentral> {
  final _formulario = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.central?.nome ?? '');
  late final _cidade =
      TextEditingController(text: widget.central?.cidade ?? '');
  late final _uf = TextEditingController(text: widget.central?.uf ?? 'GO');
  late final _endereco =
      TextEditingController(text: widget.central?.endereco ?? '');
  late final _whatsapp = TextEditingController(
      text: Validacoes.formatarTelefone(widget.central?.whatsapp ?? ''));
  late bool _ativa = widget.central?.ativa ?? false;
  LatLng? _ponto;
  String? _modeloId;
  final List<_LinhaFaixa> _faixas = [];
  final _mapa = MapController();
  bool _salvando = false;
  bool _localizando = false;
  bool _carregouFaixas = false;

  bool get _nova => widget.central == null;

  @override
  void initState() {
    super.initState();
    final c = widget.central;
    if (c != null) {
      _ponto = LatLng(c.latitude, c.longitude);
      _carregarFaixas(c.id);
    } else {
      _faixas.add(_LinhaFaixa('8', '0,00'));
      _faixas.add(_LinhaFaixa('20', '5,00'));
      _carregouFaixas = true;
    }
  }

  Future<void> _carregarFaixas(String centralId) async {
    try {
      final faixas = await ref.read(provedorGestao).faixas(centralId);
      if (!mounted) {
        return;
      }
      setState(() {
        for (final f in faixas) {
          _faixas.add(_LinhaFaixa(_km(f.ateKm), f.taxa.formatarParaEdicao()));
        }
        _carregouFaixas = true;
      });
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    }
  }

  static String _km(double valor) => valor == valor.roundToDouble()
      ? valor.toStringAsFixed(0)
      : valor.toStringAsFixed(1).replaceAll('.', ',');

  @override
  void dispose() {
    for (final c in [_nome, _cidade, _uf, _endereco, _whatsapp]) {
      c.dispose();
    }
    for (final f in _faixas) {
      f.dispose();
    }
    super.dispose();
  }

  void _moverPara(LatLng ponto) {
    setState(() => _ponto = ponto);
    try {
      _mapa.move(ponto, 16);
    } catch (_) {
      // O mapa ainda não estava na tela; ele abre já no ponto novo.
    }
  }

  Future<void> _localizarPeloEndereco() async {
    if (_cidade.text.trim().isEmpty || _uf.text.trim().length != 2) {
      mostrarMensagem(context, 'Preencha a cidade e a UF.', erro: true);
      return;
    }
    setState(() => _localizando = true);
    try {
      final partes = _endereco.text.split(',');
      final local = await ref.read(provedorEnderecos).localizar(
            logradouro: partes.first.trim(),
            numero: partes.length > 1 ? partes[1].trim() : '',
            bairro: partes.length > 2 ? partes[2].trim() : '',
            cidade: _cidade.text.trim(),
            uf: _uf.text.trim(),
          );
      if (!mounted) {
        return;
      }
      _moverPara(LatLng(local.latitude, local.longitude));
      mostrarMensagem(
        context,
        local.aproximada
            ? 'Achamos só a cidade. Toque no mapa no ponto exato da central.'
            : 'Localização encontrada. Confira o pino no mapa.',
      );
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    } finally {
      if (mounted) {
        setState(() => _localizando = false);
      }
    }
  }

  Future<void> _usarGps() async {
    setState(() => _localizando = true);
    try {
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }
      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        throw const ErroDeNegocio('Sem permissão de localização.');
      }
      final posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
      );
      if (mounted) {
        _moverPara(LatLng(posicao.latitude, posicao.longitude));
      }
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    } finally {
      if (mounted) {
        setState(() => _localizando = false);
      }
    }
  }

  void _removerFaixa(int indice) {
    final removida = _faixas[indice];
    setState(() => _faixas.removeAt(indice));
    // Libera os campos só depois que a linha sumiu da tela.
    WidgetsBinding.instance.addPostFrameCallback((_) => removida.dispose());
  }

  List<FaixaEntrega>? _lerFaixas() {
    final faixas = <FaixaEntrega>[];
    for (final linha in _faixas) {
      final km = double.tryParse(linha.km.text.trim().replaceAll(',', '.'));
      final taxa = linha.taxa.text.trim().isEmpty
          ? Dinheiro.zero
          : Dinheiro.lerReais(linha.taxa.text);
      if (km == null || km <= 0 || km > 300 || taxa == null) {
        return null;
      }
      faixas.add(FaixaEntrega(ateKm: km, taxa: taxa));
    }
    faixas.sort((a, b) => a.ateKm.compareTo(b.ateKm));
    return faixas;
  }

  Future<void> _salvar() async {
    if (!(_formulario.currentState?.validate() ?? false)) {
      return;
    }
    final ponto = _ponto;
    if (ponto == null) {
      mostrarMensagem(context, 'Marque a localização da central no mapa.',
          erro: true);
      return;
    }
    // Com central modelo, as faixas vêm copiadas dela.
    final copiarDoModelo = _nova && _modeloId != null;
    final faixas = copiarDoModelo ? const <FaixaEntrega>[] : _lerFaixas();
    if (faixas == null || (!copiarDoModelo && faixas.isEmpty)) {
      mostrarMensagem(context,
          'Confira as faixas de entrega (km de 1 a 300 e taxa em reais).',
          erro: true);
      return;
    }
    setState(() => _salvando = true);
    try {
      final gestao = ref.read(provedorGestao);
      var id = widget.central?.id;
      if (id == null) {
        id = await gestao.criarCentral(
          nome: _nome.text,
          cidade: _cidade.text,
          uf: _uf.text,
          endereco: _endereco.text,
          latitude: ponto.latitude,
          longitude: ponto.longitude,
          whatsapp: Validacoes.somenteDigitos(_whatsapp.text),
          ativa: _ativa,
          centralModeloId: _modeloId,
        );
        // Sem modelo, as faixas digitadas substituem a faixa padrão.
        if (!copiarDoModelo) {
          await gestao.salvarFaixas(id, faixas);
        }
      } else {
        await gestao.atualizarCentral(
          Central(
            id: id,
            nome: _nome.text,
            cidade: _cidade.text,
            uf: _uf.text,
            endereco: _endereco.text,
            latitude: ponto.latitude,
            longitude: ponto.longitude,
            whatsapp: Validacoes.somenteDigitos(_whatsapp.text),
            ativa: _ativa,
          ),
        );
        await gestao.salvarFaixas(id, faixas);
      }
      if (mounted) {
        mostrarMensagem(
            context, _nova ? 'Central criada.' : 'Central atualizada.');
        Navigator.of(context).pop(true);
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
    final centrais =
        ref.watch(provedorCentrais).valueOrNull ?? const <Central>[];
    final tema = Theme.of(context);
    final ponto = _ponto;
    return Scaffold(
      appBar:
          AppBar(title: Text(_nova ? 'Nova central' : widget.central!.nome)),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LarguraMaxima(
              largura: 900,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    value: _ativa,
                    onChanged: (v) => setState(() => _ativa = v),
                    title: const Text('Central ativa'),
                    subtitle: const Text(
                        'Ativa: os clientes próximos já podem pedir dela.'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nome,
                    decoration: const InputDecoration(
                        labelText: 'Nome (ex.: Central Goiatuba)'),
                    validator: Validacoes.nome,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _cidade,
                          textCapitalization: TextCapitalization.words,
                          decoration:
                              const InputDecoration(labelText: 'Cidade'),
                          validator: (v) =>
                              Validacoes.obrigatorio(v, campo: 'a cidade'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _uf,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(2)
                          ],
                          decoration: const InputDecoration(labelText: 'UF'),
                          validator: Validacoes.uf,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _endereco,
                    decoration: const InputDecoration(
                      labelText: 'Endereço (rua, número, bairro)',
                      hintText: 'Ex.: Rua 10, 250, Centro',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _whatsapp,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9() \-]'))
                    ],
                    decoration: const InputDecoration(
                        labelText: 'WhatsApp da central (com DDD)'),
                    validator: Validacoes.telefoneOpcional,
                  ),
                  if (_nova) ...[
                    const SizedBox(height: 12),
                    DropdownMenu<String?>(
                      initialSelection: null,
                      label: const Text('Copiar preços e horários de'),
                      expandedInsets: EdgeInsets.zero,
                      onSelected: (id) => setState(() => _modeloId = id),
                      dropdownMenuEntries: [
                        const DropdownMenuEntry<String?>(
                            value: null, label: 'Não copiar (começar do zero)'),
                        for (final c in centrais)
                          DropdownMenuEntry<String?>(
                              value: c.id, label: c.nome),
                      ],
                    ),
                  ],
                  const TituloSecao('Localização da central'),
                  const Text(
                      'A central atende os clientes mais perto deste ponto. Toque no mapa para ajustar.'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _localizando ? null : _localizarPeloEndereco,
                        icon: const Icon(Icons.search),
                        label: const Text('Achar pelo endereço'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _localizando ? null : _usarGps,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Estou na central agora'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_localizando) const LinearProgressIndicator(),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 320,
                      child: FlutterMap(
                        mapController: _mapa,
                        options: MapOptions(
                          initialCenter:
                              ponto ?? const LatLng(-18.0105, -49.3658),
                          initialZoom: ponto == null ? 11 : 16,
                          onTap: (_, posicao) =>
                              setState(() => _ponto = posicao),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'br.com.fortalezadigitalsecurity.gasagua',
                          ),
                          if (ponto != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: ponto,
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.topCenter,
                                  child: Icon(Icons.location_pin,
                                      size: 48, color: tema.colorScheme.error),
                                ),
                              ],
                            ),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution('OpenStreetMap')
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (ponto != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Ponto: ${ponto.latitude.toStringAsFixed(5)}, ${ponto.longitude.toStringAsFixed(5)}',
                        style: tema.textTheme.bodySmall,
                      ),
                    ),
                  TituloSecao(
                    'Faixas de entrega',
                    acao: _nova && _modeloId != null
                        ? null
                        : TextButton.icon(
                            onPressed: () => setState(
                                () => _faixas.add(_LinhaFaixa('', '0,00'))),
                            icon: const Icon(Icons.add),
                            label: const Text('Faixa'),
                          ),
                  ),
                  const Text(
                    'Ex.: até 8 km sem taxa, até 20 km R\$ 5,00. A maior distância é o alcance '
                    'da central: mais longe que isso ela não atende.',
                  ),
                  if (_nova && _modeloId != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'As faixas serão copiadas da central modelo. Depois de criar, '
                        'você pode mudar aqui mesmo.',
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (!_carregouFaixas) const LinearProgressIndicator(),
                  if (!(_nova && _modeloId != null))
                    for (var i = 0; i < _faixas.length; i++)
                      Padding(
                        key: ObjectKey(_faixas[i]),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _faixas[i].km,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Até (km)'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _faixas[i].taxa,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Taxa (R\$)',
                                    prefixText: 'R\$ '),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Tirar esta faixa',
                              onPressed: _faixas.length <= 1
                                  ? null
                                  : () => _removerFaixa(i),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 24),
                  BotaoPrincipal(
                    icone: Icons.check,
                    rotulo: _nova ? 'Criar central' : 'Salvar alterações',
                    carregando: _salvando,
                    aoPressionar: _salvar,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
