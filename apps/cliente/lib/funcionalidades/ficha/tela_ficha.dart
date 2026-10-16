import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

/// Ficha de cadastro do cliente (obrigatória para pedir; libera o crediário).
class TelaFicha extends ConsumerWidget {
  const TelaFicha({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ficha = ref.watch(provedorMinhaFicha);
    return Scaffold(
      appBar: AppBar(title: const Text('Ficha de cadastro')),
      body: ficha.when(
        loading: () => const Carregando(),
        error: (erro, _) => EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () => ref.invalidate(provedorMinhaFicha),
        ),
        data: (atual) => atual != null && atual.status == StatusFicha.aprovada
            ? _FichaAprovada(ficha: atual)
            : _FormularioFicha(atual: atual),
      ),
    );
  }
}

class _FichaAprovada extends StatelessWidget {
  const _FichaAprovada({required this.ficha});

  final FichaCliente ficha;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LarguraMaxima(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.verified, size: 36),
                  title: const Text('Ficha aprovada'),
                  subtitle: Text(
                    ficha.creditoBloqueado
                        ? 'Seu crediário está bloqueado. Fale com a loja.'
                        : 'Limite do crediário: ${ficha.limite.formatarEmReais()}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LinhaValor(
                  rotulo: 'CPF', valor: Validacoes.cpfMascarado(ficha.cpf)),
              LinhaValor(
                  rotulo: 'Nascimento',
                  valor: Datas.formatarData(ficha.dataNascimento)),
              LinhaValor(
                  rotulo: 'Trabalho',
                  valor: '${ficha.profissao} · ${ficha.empresa}'),
              LinhaValor(
                  rotulo: 'Referências',
                  valor: '${ficha.referencia1Nome}, ${ficha.referencia2Nome}'),
              const SizedBox(height: 12),
              const Text('Para mudar algum dado, fale com a loja.'),
              const SizedBox(height: 20),
              BotaoPrincipal(
                icone: Icons.account_balance_wallet_outlined,
                rotulo: 'Ver meu crediário',
                aoPressionar: () => context.push('/crediario'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Coloca as barras enquanto a pessoa digita a data ("16101980" → "16/10/1980").
class _MascaraData extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue antigo, TextEditingValue novo) {
    final digitos = novo.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limitado = digitos.length > 8 ? digitos.substring(0, 8) : digitos;
    final texto = StringBuffer();
    for (var i = 0; i < limitado.length; i++) {
      if (i == 2 || i == 4) {
        texto.write('/');
      }
      texto.write(limitado[i]);
    }
    final resultado = texto.toString();
    return TextEditingValue(
      text: resultado,
      selection: TextSelection.collapsed(offset: resultado.length),
    );
  }
}

class _Foto {
  _Foto({this.bytes, this.tipo = 'image/jpeg', this.caminho});

  final Uint8List? bytes;
  final String tipo;

  /// Caminho já enviado (ficha anterior).
  final String? caminho;

  bool get tem => bytes != null || caminho != null;
}

class _FormularioFicha extends ConsumerStatefulWidget {
  const _FormularioFicha({this.atual});

  final FichaCliente? atual;

  @override
  ConsumerState<_FormularioFicha> createState() => _FormularioFichaState();
}

class _FormularioFichaState extends ConsumerState<_FormularioFicha> {
  static const _tamanhoMaximo = 5 * 1024 * 1024;
  static const _relacoes = [
    'Pai/Mãe',
    'Irmão(ã)',
    'Filho(a)',
    'Vizinho(a)',
    'Amigo(a)',
    'Patrão'
  ];

  final _formulario = GlobalKey<FormState>();
  late final TextEditingController _cpf;
  late final TextEditingController _rg;
  late final TextEditingController _nascimento;
  late final TextEditingController _mae;
  late final TextEditingController _empresa;
  late final TextEditingController _profissao;
  late final TextEditingController _telTrabalho;
  late final TextEditingController _renda;
  late final TextEditingController _ref1Nome;
  late final TextEditingController _ref1Tel;
  late final TextEditingController _ref1Rel;
  late final TextEditingController _ref2Nome;
  late final TextEditingController _ref2Tel;
  late final TextEditingController _ref2Rel;
  String? _enderecoId;
  late _Foto _documento;
  late _Foto _comprovante;
  bool _autorizo = false;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    final f = widget.atual;
    TextEditingController campo(String texto) =>
        TextEditingController(text: texto);
    _cpf = campo(f == null ? '' : Validacoes.formatarCpf(f.cpf));
    _rg = campo(f?.rg ?? '');
    _nascimento = campo(f == null ? '' : Datas.formatarData(f.dataNascimento));
    _mae = campo(f?.nomeMae ?? '');
    _empresa = campo(f?.empresa ?? '');
    _profissao = campo(f?.profissao ?? '');
    _telTrabalho =
        campo(Validacoes.formatarTelefone(f?.telefoneTrabalho ?? ''));
    _renda = campo(f == null ? '' : f.rendaMensal.formatarParaEdicao());
    _ref1Nome = campo(f?.referencia1Nome ?? '');
    _ref1Tel = campo(Validacoes.formatarTelefone(f?.referencia1Telefone ?? ''));
    _ref1Rel = campo(f?.referencia1Relacao ?? '');
    _ref2Nome = campo(f?.referencia2Nome ?? '');
    _ref2Tel = campo(Validacoes.formatarTelefone(f?.referencia2Telefone ?? ''));
    _ref2Rel = campo(f?.referencia2Relacao ?? '');
    _enderecoId = f?.enderecoId;
    _documento = _Foto(caminho: f?.documentoCaminho);
    _comprovante = _Foto(caminho: f?.comprovanteCaminho);
  }

  List<TextEditingController> get _controles => [
        _cpf,
        _rg,
        _nascimento,
        _mae,
        _empresa,
        _profissao,
        _telTrabalho,
        _renda,
        _ref1Nome,
        _ref1Tel,
        _ref1Rel,
        _ref2Nome,
        _ref2Tel,
        _ref2Rel,
      ];

  @override
  void dispose() {
    for (final c in _controles) {
      c.dispose();
    }
    super.dispose();
  }

  Future<_Foto?> _escolherFoto(ImageSource origem) async {
    try {
      final arquivo = await ImagePicker().pickImage(
        source: origem,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (arquivo == null) {
        return null;
      }
      final bytes = await arquivo.readAsBytes();
      if (bytes.length > _tamanhoMaximo) {
        if (mounted) {
          mostrarMensagem(context, 'A foto ficou muito grande. Tente de novo.',
              erro: true);
        }
        return null;
      }
      final nome = arquivo.name.toLowerCase();
      final tipo = arquivo.mimeType ??
          (nome.endsWith('.png')
              ? 'image/png'
              : nome.endsWith('.webp')
                  ? 'image/webp'
                  : 'image/jpeg');
      if (!const {'image/jpeg', 'image/png', 'image/webp'}.contains(tipo)) {
        if (mounted) {
          mostrarMensagem(context, 'Use uma foto JPG, PNG ou WEBP.',
              erro: true);
        }
        return null;
      }
      return _Foto(bytes: bytes, tipo: tipo);
    } catch (_) {
      if (mounted) {
        mostrarMensagem(
            context, 'Não foi possível abrir a câmera ou a galeria.',
            erro: true);
      }
      return null;
    }
  }

  String? _validarNascimento(String? valor) {
    final data = Datas.lerDataDigitada(valor ?? '');
    if (data == null) {
      return 'Digite a data assim: 16/10/1980.';
    }
    final idade = Datas.idade(data);
    if (idade < 18) {
      return 'O cadastro é só para maiores de 18 anos.';
    }
    if (idade > 120) {
      return 'Confira o ano.';
    }
    return null;
  }

  Future<void> _enviar() async {
    final valido = _formulario.currentState?.validate() ?? false;
    if (!valido) {
      mostrarMensagem(context, 'Confira os campos marcados em vermelho.',
          erro: true);
      return;
    }
    if (_enderecoId == null) {
      mostrarMensagem(context, 'Escolha o endereço onde você mora.',
          erro: true);
      return;
    }
    if (!_documento.tem || !_comprovante.tem) {
      mostrarMensagem(
          context, 'Envie a foto do documento e a do comprovante de endereço.',
          erro: true);
      return;
    }
    if (!_autorizo) {
      mostrarMensagem(
          context, 'Marque a autorização para a loja analisar seus dados.',
          erro: true);
      return;
    }
    setState(() => _enviando = true);
    final repositorio = ref.read(provedorRepositorioCredito);
    try {
      Future<String> caminhoDe(_Foto foto, String nome) async {
        final bytes = foto.bytes;
        if (bytes != null) {
          return repositorio.enviarFoto(bytes, foto.tipo, nome: nome);
        }
        return foto.caminho!;
      }

      final documento = await caminhoDe(_documento, 'documento');
      final comprovante = await caminhoDe(_comprovante, 'comprovante');
      await repositorio.enviarFicha(
        DadosFicha(
          cpf: Validacoes.somenteDigitos(_cpf.text),
          rg: _rg.text,
          dataNascimento: Datas.lerDataDigitada(_nascimento.text)!,
          nomeMae: _mae.text,
          enderecoId: _enderecoId!,
          empresa: _empresa.text,
          profissao: _profissao.text,
          telefoneTrabalho: Validacoes.somenteDigitos(_telTrabalho.text),
          rendaMensal: Dinheiro.lerReais(_renda.text) ?? Dinheiro.zero,
          referencia1Nome: _ref1Nome.text,
          referencia1Telefone: Validacoes.somenteDigitos(_ref1Tel.text),
          referencia1Relacao: _ref1Rel.text,
          referencia2Nome: _ref2Nome.text,
          referencia2Telefone: Validacoes.somenteDigitos(_ref2Tel.text),
          referencia2Relacao: _ref2Rel.text,
          documentoCaminho: documento,
          comprovanteCaminho: comprovante,
        ),
      );
      ref.invalidate(provedorMinhaFicha);
      if (mounted) {
        mostrarMensagem(context,
            'Ficha enviada! Você já pode fazer pedidos pagando na entrega.');
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, mensagemDeErro(erro), erro: true);
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  Widget _campo(
    TextEditingController controle,
    String rotulo, {
    String? Function(String?)? validador,
    TextInputType? teclado,
    List<TextInputFormatter>? formatadores,
    String? dica,
    TextCapitalization maiusculas = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controle,
        keyboardType: teclado,
        inputFormatters: formatadores,
        textCapitalization: maiusculas,
        validator: validador,
        decoration: InputDecoration(labelText: rotulo, hintText: dica),
      ),
    );
  }

  Widget _relacao(TextEditingController controle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: controle,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v ?? '').trim().length < 2
                ? 'Diga quem é (ex.: irmão, vizinho).'
                : null,
            decoration: const InputDecoration(labelText: 'Quem é para você?'),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in _relacoes)
                ActionChip(
                    label: Text(r),
                    onPressed: () => setState(() => controle.text = r)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cartaoFoto({
    required String titulo,
    required String explicacao,
    required _Foto foto,
    required ValueChanged<_Foto> aoEscolher,
  }) {
    final bytes = foto.bytes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(explicacao),
            const SizedBox(height: 10),
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(bytes, height: 160, fit: BoxFit.cover),
              )
            else if (foto.caminho != null)
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text('Foto já enviada. Troque só se precisar.')),
                ],
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _enviando
                      ? null
                      : () async {
                          final nova = await _escolherFoto(ImageSource.camera);
                          if (nova != null) {
                            aoEscolher(nova);
                          }
                        },
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Tirar foto'),
                ),
                OutlinedButton.icon(
                  onPressed: _enviando
                      ? null
                      : () async {
                          final nova = await _escolherFoto(ImageSource.gallery);
                          if (nova != null) {
                            aoEscolher(nova);
                          }
                        },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Da galeria'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enderecos =
        ref.watch(provedorEnderecos).valueOrNull ?? const <Endereco>[];
    final atual = widget.atual;
    final telefone = [FilteringTextInputFormatter.allow(RegExp(r'[0-9() \-]'))];
    return Form(
      key: _formulario,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LarguraMaxima(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (atual == null)
                  const Text(
                    'Preencha uma vez só. Com a ficha, você pode fazer pedidos e, depois da '
                    'aprovação da loja, comprar no crediário (fiado).',
                  )
                else
                  Card(
                    color: atual.status == StatusFicha.recusada
                        ? Theme.of(context).colorScheme.errorContainer
                        : null,
                    child: ListTile(
                      leading: Icon(
                        atual.status == StatusFicha.recusada
                            ? Icons.error_outline
                            : Icons.hourglass_top,
                      ),
                      title: Text(
                        atual.status == StatusFicha.recusada
                            ? 'Ficha não aprovada'
                            : 'Ficha em análise',
                      ),
                      subtitle: Text(
                        atual.status == StatusFicha.recusada
                            ? '${atual.motivo ?? 'Confira os dados.'} Corrija e envie de novo.'
                            : 'Enviada em ${Datas.formatarDataHora(atual.enviadoEm)}. '
                                'Enquanto isso, você já pode pedir pagando na entrega.',
                      ),
                    ),
                  ),
                const TituloSecao('Seus documentos'),
                _campo(
                  _cpf,
                  'CPF',
                  teclado: TextInputType.number,
                  formatadores: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                    LengthLimitingTextInputFormatter(14),
                  ],
                  validador: Validacoes.cpf,
                ),
                _campo(
                  _rg,
                  'RG',
                  validador: (v) =>
                      (v ?? '').trim().length < 3 ? 'Informe o RG.' : null,
                ),
                _campo(
                  _nascimento,
                  'Data de nascimento',
                  dica: 'dia/mês/ano',
                  teclado: TextInputType.number,
                  formatadores: [_MascaraData()],
                  validador: _validarNascimento,
                ),
                _campo(
                  _mae,
                  'Nome completo da mãe',
                  maiusculas: TextCapitalization.words,
                  validador: (v) => (v ?? '').trim().length < 3
                      ? 'Informe o nome da mãe.'
                      : null,
                ),
                const TituloSecao('Onde você mora'),
                if (enderecos.isEmpty)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/enderecos/novo'),
                    icon: const Icon(Icons.add_home_outlined),
                    label: const Text('Cadastrar meu endereço'),
                  )
                else
                  DropdownMenu<String>(
                    initialSelection: enderecos.any((e) => e.id == _enderecoId)
                        ? _enderecoId
                        : null,
                    label: const Text('Endereço de moradia'),
                    expandedInsets: EdgeInsets.zero,
                    onSelected: (id) => setState(() => _enderecoId = id),
                    dropdownMenuEntries: [
                      for (final e in enderecos)
                        if (e.id != null)
                          DropdownMenuEntry(
                              value: e.id!,
                              label: '${e.apelido} · ${e.linhaPrincipal}'),
                    ],
                  ),
                const TituloSecao('Trabalho e renda'),
                _campo(
                  _empresa,
                  'Onde trabalha',
                  dica: 'Nome da empresa ou "autônomo"',
                  maiusculas: TextCapitalization.words,
                  validador: (v) => (v ?? '').trim().length < 2
                      ? 'Informe onde trabalha.'
                      : null,
                ),
                _campo(
                  _profissao,
                  'Profissão',
                  maiusculas: TextCapitalization.sentences,
                  validador: (v) => (v ?? '').trim().length < 2
                      ? 'Informe a profissão.'
                      : null,
                ),
                _campo(
                  _telTrabalho,
                  'Telefone do trabalho (opcional)',
                  teclado: TextInputType.phone,
                  formatadores: telefone,
                  validador: Validacoes.telefoneOpcional,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _renda,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                    ],
                    validator: (v) => Dinheiro.lerReais(v ?? '') == null
                        ? 'Informe a renda por mês, ex.: 2.500,00'
                        : null,
                    decoration: const InputDecoration(
                        labelText: 'Renda por mês', prefixText: 'R\$ '),
                  ),
                ),
                const TituloSecao('Primeira referência'),
                _campo(
                  _ref1Nome,
                  'Nome',
                  maiusculas: TextCapitalization.words,
                  validador: (v) =>
                      (v ?? '').trim().length < 3 ? 'Informe o nome.' : null,
                ),
                _campo(_ref1Tel, 'Telefone com DDD',
                    teclado: TextInputType.phone,
                    formatadores: telefone,
                    validador: Validacoes.celular),
                _relacao(_ref1Rel),
                const TituloSecao('Segunda referência'),
                _campo(
                  _ref2Nome,
                  'Nome',
                  maiusculas: TextCapitalization.words,
                  validador: (v) =>
                      (v ?? '').trim().length < 3 ? 'Informe o nome.' : null,
                ),
                _campo(
                  _ref2Tel,
                  'Telefone com DDD',
                  teclado: TextInputType.phone,
                  formatadores: telefone,
                  validador: (v) {
                    final erro = Validacoes.celular(v);
                    if (erro != null) {
                      return erro;
                    }
                    return Validacoes.somenteDigitos(v) ==
                            Validacoes.somenteDigitos(_ref1Tel.text)
                        ? 'Use um telefone diferente da primeira referência.'
                        : null;
                  },
                ),
                _relacao(_ref2Rel),
                const TituloSecao('Fotos'),
                _cartaoFoto(
                  titulo: 'Documento com foto',
                  explicacao: 'RG ou CNH, aberto e legível.',
                  foto: _documento,
                  aoEscolher: (f) => setState(() => _documento = f),
                ),
                const SizedBox(height: 8),
                _cartaoFoto(
                  titulo: 'Comprovante de endereço',
                  explicacao:
                      'Conta de luz, água ou telefone recente, no seu nome ou de alguém da casa.',
                  foto: _comprovante,
                  aoEscolher: (f) => setState(() => _comprovante = f),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _autorizo,
                  onChanged: (v) => setState(() => _autorizo = v ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    'Autorizo a loja a usar estes dados só para o meu cadastro e a análise do '
                    'crediário. Posso pedir para apagar quando excluir minha conta.',
                  ),
                ),
                const SizedBox(height: 16),
                BotaoPrincipal(
                  icone: Icons.send_outlined,
                  rotulo: atual == null ? 'Enviar ficha' : 'Enviar de novo',
                  carregando: _enviando,
                  aoPressionar: _enviar,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
