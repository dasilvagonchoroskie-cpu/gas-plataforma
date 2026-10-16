import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';
import 'mapa_endereco.dart';

/// Cadastro e edição de endereço: CEP preenche rua/bairro/cidade, o GPS
/// preenche tudo, e o mapa mostra onde o pino ficou (dá para ajustar tocando).
class TelaEditarEndereco extends ConsumerStatefulWidget {
  const TelaEditarEndereco({this.enderecoId, super.key});

  final String? enderecoId;

  @override
  ConsumerState<TelaEditarEndereco> createState() => _TelaEditarEnderecoState();
}

class _TelaEditarEnderecoState extends ConsumerState<TelaEditarEndereco> {
  final _formulario = GlobalKey<FormState>();
  final _apelido = TextEditingController(text: 'Casa');
  final _cep = TextEditingController();
  final _logradouro = TextEditingController();
  final _numero = TextEditingController();
  final _bairro = TextEditingController();
  final _cidade = TextEditingController();
  final _uf = TextEditingController(text: 'GO');
  final _complemento = TextEditingController();
  final _referencia = TextEditingController();

  Localizacao? _localizacao;
  double _zoomMapa = 17;
  bool _pinoAjustadoAMao = false;
  bool _buscandoCep = false;
  bool _usandoGps = false;
  bool _salvando = false;
  bool _carregou = false;

  RepositorioEnderecos get _repositorio =>
      ref.read(provedorRepositorioEnderecos);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_carregou && widget.enderecoId != null) {
      _carregou = true;
      final lista =
          ref.read(provedorEnderecos).valueOrNull ?? const <Endereco>[];
      for (final e in lista) {
        if (e.id == widget.enderecoId) {
          _apelido.text = e.apelido;
          _cep.text = Validacoes.formatarCep(e.cep);
          _logradouro.text = e.logradouro;
          _numero.text = e.numero;
          _bairro.text = e.bairro;
          _cidade.text = e.cidade;
          _uf.text = e.uf;
          _complemento.text = e.complemento ?? '';
          _referencia.text = e.referencia ?? '';
          _localizacao =
              Localizacao(latitude: e.latitude, longitude: e.longitude);
          _pinoAjustadoAMao = true;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controle in [
      _apelido,
      _cep,
      _logradouro,
      _numero,
      _bairro,
      _cidade,
      _uf,
      _complemento,
      _referencia,
    ]) {
      controle.dispose();
    }
    super.dispose();
  }

  void _erro(Object erro) {
    if (mounted) {
      mostrarMensagem(context, mensagemDeErro(erro), erro: true);
    }
  }

  Future<void> _buscarCep() async {
    if (Validacoes.cep(_cep.text) != null) {
      return;
    }
    setState(() => _buscandoCep = true);
    try {
      final dados = await _repositorio.buscarCep(_cep.text);
      if (!mounted) {
        return;
      }
      setState(() {
        if (dados.logradouro.isNotEmpty) {
          _logradouro.text = dados.logradouro;
        }
        if (dados.bairro.isNotEmpty) {
          _bairro.text = dados.bairro;
        }
        _cidade.text = dados.cidade;
        _uf.text = dados.uf;
        if (!_pinoAjustadoAMao) {
          _localizacao = null;
        }
      });
    } catch (erro) {
      _erro(erro);
    } finally {
      if (mounted) {
        setState(() => _buscandoCep = false);
      }
    }
  }

  Future<void> _usarGps() async {
    setState(() => _usandoGps = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const ErroDeNegocio(
            'Ligue a localização (GPS) do celular e tente de novo.');
      }
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }
      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        throw const ErroDeNegocio(
          'Sem permissão de localização. Você pode digitar o endereço pelo CEP.',
        );
      }
      final posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      // O ponto do GPS vale mesmo se o serviço não achar o nome da rua: a
      // pessoa completa o endereço à mão.
      final achado = await _repositorio
          .enderecoDoGps(posicao.latitude, posicao.longitude)
          .then<EnderecoDoGps?>((e) => e, onError: (Object _) => null);
      if (!mounted) {
        return;
      }
      setState(() {
        _localizacao = Localizacao(
            latitude: posicao.latitude, longitude: posicao.longitude);
        _zoomMapa = 17;
        _pinoAjustadoAMao = true;
        if (achado != null) {
          _preencherDoGps(achado);
        }
      });
      mostrarMensagem(
        context,
        achado == null || achado.logradouro.isEmpty
            ? 'Marcamos sua localização no mapa. Preencha a rua, o número e o '
                'bairro.'
            : 'Localização encontrada. Confira o número e o pino no mapa.',
      );
    } catch (erro) {
      _erro(erro);
    } finally {
      if (mounted) {
        setState(() => _usandoGps = false);
      }
    }
  }

  /// Preenche os campos com o que o serviço achou (chamar dentro de setState).
  void _preencherDoGps(EnderecoDoGps achado) {
    if (achado.cep.length == 8) {
      _cep.text = Validacoes.formatarCep(achado.cep);
    }
    if (achado.logradouro.isNotEmpty) {
      _logradouro.text = achado.logradouro;
    }
    if (achado.numero.isNotEmpty && _numero.text.isEmpty) {
      _numero.text = achado.numero;
    }
    if (achado.bairro.isNotEmpty) {
      _bairro.text = achado.bairro;
    }
    if (achado.cidade.isNotEmpty) {
      _cidade.text = achado.cidade;
    }
    if (achado.uf.length == 2) {
      _uf.text = achado.uf;
    }
  }

  Future<void> _salvar() async {
    if (!(_formulario.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _salvando = true);
    try {
      var localizacao = _localizacao;
      if (localizacao == null) {
        try {
          localizacao = await _repositorio.localizar(
            logradouro: _logradouro.text,
            numero: _numero.text,
            bairro: _bairro.text,
            cidade: _cidade.text,
            uf: _uf.text,
            cep: _cep.text,
          );
        } catch (_) {
          throw const ErroDeNegocio(
            'Não conseguimos achar o endereço no mapa agora. Toque em "Usar '
            'minha localização agora" ou tente de novo em instantes.',
          );
        }
        if (!mounted) {
          return;
        }
        final achada = localizacao;
        setState(() {
          _localizacao = achada;
          _zoomMapa = switch (achada.precisao) {
            'cidade' => 14,
            'rua' => 16,
            _ => 17,
          };
        });
        if (achada.precisaConferir) {
          // Mostra o pino para a pessoa conferir antes de salvar: com mais de
          // uma loja na cidade, o ponto certo decide quem entrega.
          mostrarMensagem(
            context,
            achada.aproximada
                ? 'Achamos só a cidade. Toque no mapa no lugar da sua casa e '
                    'toque em Salvar de novo.'
                : 'Achamos a rua. Se o pino não estiver na sua casa, toque no '
                    'lugar certo do mapa. Depois toque em Salvar de novo.',
          );
          return;
        }
      }
      final endereco = Endereco(
        id: widget.enderecoId,
        apelido: _apelido.text,
        cep: Validacoes.somenteDigitos(_cep.text),
        logradouro: _logradouro.text,
        numero: _numero.text,
        bairro: _bairro.text,
        cidade: _cidade.text,
        uf: _uf.text,
        complemento:
            _complemento.text.trim().isEmpty ? null : _complemento.text.trim(),
        referencia:
            _referencia.text.trim().isEmpty ? null : _referencia.text.trim(),
        latitude: localizacao.latitude,
        longitude: localizacao.longitude,
      );
      final salvo = await _repositorio.salvar(endereco);
      await ref.read(provedorIdEnderecoEscolhido.notifier).escolher(salvo.id);
      ref.invalidate(provedorEnderecos);
      if (mounted) {
        mostrarMensagem(context, 'Endereço salvo.');
        context.pop();
      }
    } catch (erro) {
      _erro(erro);
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizacao = _localizacao;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.enderecoId == null ? 'Novo endereço' : 'Editar endereço'),
      ),
      body: SafeArea(
        child: Form(
          key: _formulario,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              BotaoPrincipal(
                icone: Icons.my_location,
                rotulo: 'Usar minha localização agora',
                secundario: true,
                carregando: _usandoGps,
                aoPressionar: _usarGps,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Use o botão acima quando estiver em casa, ou digite o CEP.',
                  textAlign: TextAlign.center,
                ),
              ),
              TextFormField(
                controller: _apelido,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nome do endereço (ex.: Casa, Trabalho)',
                ),
                validator: (v) =>
                    Validacoes.obrigatorio(v, campo: 'o nome do endereço'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cep,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                  LengthLimitingTextInputFormatter(9),
                ],
                onChanged: (valor) {
                  if (Validacoes.somenteDigitos(valor).length == 8) {
                    _buscarCep();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'CEP',
                  suffixIcon: _buscandoCep
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Buscar CEP',
                          icon: const Icon(Icons.search),
                          onPressed: _buscarCep,
                        ),
                ),
                validator: Validacoes.cep,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _logradouro,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) {
                  if (!_pinoAjustadoAMao) {
                    _localizacao = null;
                  }
                },
                decoration: const InputDecoration(labelText: 'Rua / avenida'),
                validator: (v) => Validacoes.obrigatorio(v, campo: 'a rua'),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _numero,
                      onChanged: (_) {
                        if (!_pinoAjustadoAMao) {
                          _localizacao = null;
                        }
                      },
                      decoration: const InputDecoration(labelText: 'Número'),
                      validator: (v) => Validacoes.obrigatorio(v,
                          campo: 'o número (ou "s/n")'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _complemento,
                      decoration: const InputDecoration(
                          labelText: 'Complemento (opcional)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bairro,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Bairro'),
                validator: (v) => Validacoes.obrigatorio(v, campo: 'o bairro'),
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
                      decoration: const InputDecoration(labelText: 'Cidade'),
                      validator: (v) =>
                          Validacoes.obrigatorio(v, campo: 'a cidade'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _uf,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(2)],
                      decoration: const InputDecoration(labelText: 'UF'),
                      validator: Validacoes.uf,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _referencia,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Ponto de referência (opcional)',
                  hintText: 'Ex.: casa de muro azul, perto da praça',
                ),
              ),
              if (localizacao != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Confira o pino. Se não estiver na sua casa, toque no lugar certo do mapa.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                MapaEndereco(
                  latitude: localizacao.latitude,
                  longitude: localizacao.longitude,
                  zoom: _zoomMapa,
                  aoMover: (lat, lon) => setState(() {
                    _localizacao = Localizacao(latitude: lat, longitude: lon);
                    _pinoAjustadoAMao = true;
                  }),
                ),
              ],
              const SizedBox(height: 24),
              BotaoPrincipal(
                icone: Icons.check,
                rotulo: 'Salvar endereço',
                carregando: _salvando,
                aoPressionar: _salvar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
