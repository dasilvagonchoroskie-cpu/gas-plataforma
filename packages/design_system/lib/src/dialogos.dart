import 'package:flutter/material.dart';

/// Mostra uma mensagem rápida no rodapé.
void mostrarMensagem(BuildContext context, String texto, {bool erro = false}) {
  final cores = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto, style: const TextStyle(fontSize: 16)),
        backgroundColor: erro ? cores.error : null,
        duration: Duration(seconds: erro ? 6 : 3),
      ),
    );
}

/// Pergunta "tem certeza?". Devolve verdadeiro se a pessoa confirmar.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensagem,
  String rotuloConfirmar = 'Confirmar',
  String rotuloCancelar = 'Voltar',
  bool perigoso = false,
}) async {
  final resultado = await showDialog<bool>(
    context: context,
    builder: (context) {
      final cores = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(rotuloCancelar),
          ),
          FilledButton(
            style: perigoso
                ? FilledButton.styleFrom(
                    backgroundColor: cores.error,
                    foregroundColor: cores.onError,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(rotuloConfirmar),
          ),
        ],
      );
    },
  );
  return resultado ?? false;
}

/// Pede um texto (por exemplo, o motivo de um cancelamento).
Future<String?> pedirTexto(
  BuildContext context, {
  required String titulo,
  required String rotulo,
  String? mensagem,
  String rotuloConfirmar = 'Confirmar',
  bool obrigatorio = true,
  int maximo = 300,
  List<String> sugestoes = const [],
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _DialogoTexto(
      titulo: titulo,
      rotulo: rotulo,
      mensagem: mensagem,
      rotuloConfirmar: rotuloConfirmar,
      obrigatorio: obrigatorio,
      maximo: maximo,
      sugestoes: sugestoes,
    ),
  );
}

class _DialogoTexto extends StatefulWidget {
  const _DialogoTexto({
    required this.titulo,
    required this.rotulo,
    required this.rotuloConfirmar,
    required this.obrigatorio,
    required this.maximo,
    required this.sugestoes,
    this.mensagem,
  });

  final String titulo;
  final String rotulo;
  final String? mensagem;
  final String rotuloConfirmar;
  final bool obrigatorio;
  final int maximo;
  final List<String> sugestoes;

  @override
  State<_DialogoTexto> createState() => _DialogoTextoState();
}

class _DialogoTextoState extends State<_DialogoTexto> {
  final _controle = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  void _confirmar() {
    final texto = _controle.text.trim();
    if (widget.obrigatorio && texto.isEmpty) {
      setState(() => _erro = 'Preencha este campo.');
      return;
    }
    Navigator.of(context).pop(texto);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.mensagem != null) ...[
              Text(widget.mensagem!),
              const SizedBox(height: 12),
            ],
            if (widget.sugestoes.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sugestao in widget.sugestoes)
                    ActionChip(
                      label: Text(sugestao),
                      onPressed: () => setState(() {
                        _controle.text = sugestao;
                        _erro = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _controle,
              autofocus: widget.sugestoes.isEmpty,
              maxLength: widget.maximo,
              maxLines: 3,
              minLines: 1,
              decoration:
                  InputDecoration(labelText: widget.rotulo, errorText: _erro),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
        FilledButton(
            onPressed: _confirmar, child: Text(widget.rotuloConfirmar)),
      ],
    );
  }
}
