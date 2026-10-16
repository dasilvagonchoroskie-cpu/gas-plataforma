import 'package:dados/dados.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nucleo/nucleo.dart';

import '../../estado/provedores.dart';

/// Catálogo único da revenda. O preço de cada produto é definido por central,
/// na seção "Preços".
class SecaoProdutos extends ConsumerWidget {
  const SecaoProdutos({super.key});

  Future<void> _abrir(BuildContext context, WidgetRef ref,
      [Produto? produto]) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditorProduto(produto: produto)),
    );
    if (salvou == true) {
      ref.invalidate(provedorProdutos);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final produtos = ref.watch(provedorProdutos);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrir(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Novo produto'),
      ),
      body: produtos.when(
        loading: () => const Carregando(),
        error: (erro, _) => EstadoErro(
          mensagem: mensagemDeErro(erro),
          aoTentarNovamente: () => ref.invalidate(provedorProdutos),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return EstadoVazio(
              icone: Icons.inventory_2_outlined,
              titulo: 'Nenhum produto',
              mensagem: 'Cadastre o gás e a água que a revenda vende.',
              rotuloAcao: 'Cadastrar produto',
              aoAcionar: () => _abrir(context, ref),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              const Text(
                'Depois de cadastrar, defina o preço do produto em cada central na seção "Preços".',
              ),
              const SizedBox(height: 12),
              for (final p in lista)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    child: ListTile(
                      leading:
                          _Miniatura(url: p.fotoUrl, categoria: p.categoria),
                      title: Text(p.nome),
                      subtitle: Text(
                        '${p.categoria.rotulo} · '
                        '${p.trocaVasilhame ? 'troca (cliente devolve o vazio)' : 'com vasilhame ou avulso'}'
                        '${p.ativo ? '' : ' · DESATIVADO'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _abrir(context, ref, p),
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

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.url, required this.categoria});

  final String? url;
  final CategoriaProduto categoria;

  @override
  Widget build(BuildContext context) {
    final icone = Icon(
      categoria == CategoriaProduto.gas
          ? Icons.propane_tank_outlined
          : Icons.water_drop_outlined,
      size: 32,
    );
    final endereco = url;
    if (endereco == null) {
      return SizedBox(width: 56, height: 56, child: Center(child: icone));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        endereco,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            SizedBox(width: 56, height: 56, child: Center(child: icone)),
      ),
    );
  }
}

/// Formulário de produto com foto opcional.
class EditorProduto extends ConsumerStatefulWidget {
  const EditorProduto({this.produto, super.key});

  final Produto? produto;

  @override
  ConsumerState<EditorProduto> createState() => _EditorProdutoState();
}

class _EditorProdutoState extends ConsumerState<EditorProduto> {
  static const _tamanhoMaximo = 2 * 1024 * 1024;

  final _formulario = GlobalKey<FormState>();
  late final _nome = TextEditingController(text: widget.produto?.nome ?? '');
  late final _descricao =
      TextEditingController(text: widget.produto?.descricao ?? '');
  late final _ordem =
      TextEditingController(text: '${widget.produto?.ordem ?? 0}');
  late CategoriaProduto _categoria =
      widget.produto?.categoria ?? CategoriaProduto.gas;
  late bool _troca = widget.produto?.trocaVasilhame ?? true;
  late bool _ativo = widget.produto?.ativo ?? true;
  late String? _fotoUrl = widget.produto?.fotoUrl;
  Uint8List? _fotoNova;
  String _tipoFoto = 'image/jpeg';
  bool _salvando = false;

  bool get _novo => widget.produto == null;

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    _ordem.dispose();
    super.dispose();
  }

  Future<void> _escolherFoto() async {
    try {
      final arquivo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (arquivo == null) {
        return;
      }
      final bytes = await arquivo.readAsBytes();
      if (bytes.length > _tamanhoMaximo) {
        if (mounted) {
          mostrarMensagem(context, 'A foto passa de 2 MB. Escolha uma menor.',
              erro: true);
        }
        return;
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
        return;
      }
      setState(() {
        _fotoNova = bytes;
        _tipoFoto = tipo;
      });
    } catch (erro) {
      if (mounted) {
        mostrarMensagem(context, 'Não foi possível abrir a foto.', erro: true);
      }
    }
  }

  Future<void> _salvar() async {
    if (!(_formulario.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _salvando = true);
    try {
      final gestao = ref.read(provedorGestao);
      var foto = _fotoUrl;
      final novaFoto = _fotoNova;
      if (novaFoto != null) {
        foto = await gestao.enviarFotoProduto(novaFoto, _tipoFoto);
      }
      await gestao.salvarProduto(
        id: widget.produto?.id,
        nome: _nome.text,
        categoria: _categoria,
        trocaVasilhame: _troca,
        ativo: _ativo,
        descricao: _descricao.text,
        fotoUrl: foto,
        ordem: int.tryParse(_ordem.text.trim()) ?? 0,
      );
      if (mounted) {
        mostrarMensagem(
            context, _novo ? 'Produto cadastrado.' : 'Produto atualizado.');
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
    final fotoNova = _fotoNova;
    final fotoUrl = _fotoUrl;
    Widget foto;
    if (fotoNova != null) {
      foto = Image.memory(fotoNova, height: 180, fit: BoxFit.contain);
    } else if (fotoUrl != null) {
      foto = Image.network(
        fotoUrl,
        height: 180,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox(
            height: 180, child: Icon(Icons.broken_image, size: 48)),
      );
    } else {
      foto =
          const SizedBox(height: 120, child: Center(child: Text('Sem foto')));
    }
    return Scaffold(
      appBar:
          AppBar(title: Text(_novo ? 'Novo produto' : widget.produto!.nome)),
      body: Form(
        key: _formulario,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LarguraMaxima(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          foto,
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _salvando ? null : _escolherFoto,
                                icon: const Icon(Icons.photo_library_outlined),
                                label: Text(fotoNova == null && fotoUrl == null
                                    ? 'Escolher foto'
                                    : 'Trocar foto'),
                              ),
                              if (fotoNova != null || fotoUrl != null)
                                TextButton(
                                  onPressed: _salvando
                                      ? null
                                      : () => setState(() {
                                            _fotoNova = null;
                                            _fotoUrl = null;
                                          }),
                                  child: const Text('Tirar foto'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nome,
                    decoration: const InputDecoration(
                        labelText: 'Nome (ex.: Gás P13 - troca)'),
                    validator: Validacoes.nome,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<CategoriaProduto>(
                    segments: [
                      for (final c in CategoriaProduto.values)
                        ButtonSegment(value: c, label: Text(c.rotulo)),
                    ],
                    selected: {_categoria},
                    onSelectionChanged: (s) =>
                        setState(() => _categoria = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descricao,
                    maxLines: 3,
                    minLines: 1,
                    maxLength: 300,
                    decoration: const InputDecoration(
                        labelText: 'Descrição (opcional)'),
                  ),
                  SwitchListTile(
                    value: _troca,
                    onChanged: (v) => setState(() => _troca = v),
                    title: const Text('É troca de vasilhame'),
                    subtitle: const Text(
                      'Ligado: o cliente entrega o botijão ou galão vazio na hora. '
                      'Desligado: vai com vasilhame novo ou é produto avulso.',
                    ),
                  ),
                  SwitchListTile(
                    value: _ativo,
                    onChanged: (v) => setState(() => _ativo = v),
                    title: const Text('Produto ativo'),
                    subtitle: const Text(
                        'Desligado: some do aplicativo de todas as centrais.'),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _ordem,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3)
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Posição na lista',
                      helperText:
                          'Número menor aparece primeiro no aplicativo.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  BotaoPrincipal(
                    icone: Icons.check,
                    rotulo: _novo ? 'Cadastrar produto' : 'Salvar alterações',
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
