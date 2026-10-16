import 'package:flutter/material.dart';
import 'package:nucleo/nucleo.dart';

/// Botão principal de largura total, com indicador de carregamento.
class BotaoPrincipal extends StatelessWidget {
  const BotaoPrincipal({
    required this.rotulo,
    required this.aoPressionar,
    this.icone,
    this.carregando = false,
    this.secundario = false,
    super.key,
  });

  final String rotulo;
  final VoidCallback? aoPressionar;
  final IconData? icone;
  final bool carregando;
  final bool secundario;

  @override
  Widget build(BuildContext context) {
    final conteudo = carregando
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icone != null) ...[Icon(icone), const SizedBox(width: 10)],
              Flexible(child: Text(rotulo, textAlign: TextAlign.center)),
            ],
          );
    final acao = carregando ? null : aoPressionar;
    return SizedBox(
      width: double.infinity,
      child: secundario
          ? OutlinedButton(onPressed: acao, child: conteudo)
          : FilledButton(onPressed: acao, child: conteudo),
    );
  }
}

/// Tela de "nada por aqui" com uma ação opcional.
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    required this.titulo,
    this.mensagem,
    this.icone = Icons.inbox_outlined,
    this.rotuloAcao,
    this.aoAcionar,
    super.key,
  });

  final String titulo;
  final String? mensagem;
  final IconData icone;
  final String? rotuloAcao;
  final VoidCallback? aoAcionar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 56, color: tema.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: tema.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (mensagem != null) ...[
                const SizedBox(height: 8),
                Text(mensagem!, textAlign: TextAlign.center),
              ],
              if (rotuloAcao != null && aoAcionar != null) ...[
                const SizedBox(height: 20),
                BotaoPrincipal(rotulo: rotuloAcao!, aoPressionar: aoAcionar),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tela de erro com botão para tentar de novo.
class EstadoErro extends StatelessWidget {
  const EstadoErro({required this.mensagem, this.aoTentarNovamente, super.key});

  final String mensagem;
  final VoidCallback? aoTentarNovamente;

  @override
  Widget build(BuildContext context) {
    return EstadoVazio(
      icone: Icons.wifi_off_rounded,
      titulo: 'Algo deu errado',
      mensagem: mensagem,
      rotuloAcao: aoTentarNovamente == null ? null : 'Tentar de novo',
      aoAcionar: aoTentarNovamente,
    );
  }
}

class Carregando extends StatelessWidget {
  const Carregando({this.mensagem, super.key});

  final String? mensagem;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (mensagem != null) ...[
            const SizedBox(height: 16),
            Text(mensagem!),
          ],
        ],
      ),
    );
  }
}

/// Cores dos status, iguais no app do cliente e nos painéis.
Color corDoStatus(StatusPedido status, ColorScheme cores) => switch (status) {
      StatusPedido.novo => const Color(0xFFB45309),
      StatusPedido.confirmado => cores.primary,
      StatusPedido.emRota => const Color(0xFF6D28D9),
      StatusPedido.entregue => const Color(0xFF15803D),
      StatusPedido.cancelado => cores.error,
    };

/// Etiqueta colorida com o status do pedido.
class SeloStatus extends StatelessWidget {
  const SeloStatus({required this.status, this.paraCentral = false, super.key});

  final StatusPedido status;
  final bool paraCentral;

  @override
  Widget build(BuildContext context) {
    final cor = corDoStatus(status, Theme.of(context).colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Text(
        paraCentral ? status.rotuloCentral : status.rotuloCliente,
        style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 14),
      ),
    );
  }
}

/// Linha "rótulo .... valor" usada em resumos.
class LinhaValor extends StatelessWidget {
  const LinhaValor({
    required this.rotulo,
    required this.valor,
    this.destaque = false,
    super.key,
  });

  final String rotulo;
  final String valor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final estilo = destaque
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(rotulo, style: estilo)),
          const SizedBox(width: 12),
          Text(valor, style: estilo, textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

/// Título de seção dentro de listas.
class TituloSecao extends StatelessWidget {
  const TituloSecao(this.texto, {this.acao, super.key});

  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (acao != null) acao!,
        ],
      ),
    );
  }
}

/// Limita a largura do conteúdo em telas grandes (web).
class LarguraMaxima extends StatelessWidget {
  const LarguraMaxima({required this.child, this.largura = 720, super.key});

  final Widget child;
  final double largura;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largura),
        child: child,
      ),
    );
  }
}
