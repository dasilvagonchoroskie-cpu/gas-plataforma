import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:nucleo/nucleo.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> _abrir(BuildContext context, Uri uri, String falha) async {
  final aberto = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!aberto && context.mounted) {
    mostrarMensagem(context, falha, erro: true);
  }
}

Future<void> abrirWhatsapp(BuildContext context, String numero, {String mensagem = ''}) {
  final telefone = Validacoes.whatsappInternacional(numero);
  return _abrir(
    context,
    Uri.https('wa.me', '/$telefone', mensagem.isEmpty ? null : {'text': mensagem}),
    'Não foi possível abrir o WhatsApp.',
  );
}

Future<void> ligar(BuildContext context, String numero) => _abrir(
      context,
      Uri(scheme: 'tel', path: Validacoes.somenteDigitos(numero)),
      'Não foi possível abrir o telefone.',
    );

/// Abre a rota até o endereço no Google Maps (ou no app de mapas do celular).
Future<void> abrirMapa(BuildContext context, double latitude, double longitude) => _abrir(
      context,
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '$latitude,$longitude',
      }),
      'Não foi possível abrir o mapa.',
    );
