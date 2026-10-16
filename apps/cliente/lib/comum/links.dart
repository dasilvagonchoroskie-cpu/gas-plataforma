import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:nucleo/nucleo.dart';
import 'package:url_launcher/url_launcher.dart';

/// Páginas públicas com os termos de uso e a política de privacidade.
const String enderecoTermos = String.fromEnvironment(
  'URL_TERMOS',
  defaultValue: 'https://fortalezadigitalsecurity.com.br/gas-agua/termos.html',
);
const String enderecoPrivacidade = String.fromEnvironment(
  'URL_PRIVACIDADE',
  defaultValue: 'https://fortalezadigitalsecurity.com.br/gas-agua/privacidade.html',
);

Future<void> abrirLink(BuildContext context, String endereco) async {
  final aberto = await launchUrl(
    Uri.parse(endereco),
    mode: LaunchMode.externalApplication,
  );
  if (!aberto && context.mounted) {
    mostrarMensagem(context, 'Não foi possível abrir o link.', erro: true);
  }
}

/// Abre a conversa no WhatsApp com uma mensagem pronta.
Future<void> abrirWhatsapp(
  BuildContext context, {
  required String? numero,
  String mensagem = '',
}) async {
  final telefone = Validacoes.whatsappInternacional(numero);
  if (telefone.isEmpty) {
    mostrarMensagem(context, 'Esta central ainda não cadastrou o WhatsApp.', erro: true);
    return;
  }
  final uri = Uri.https(
    'wa.me',
    '/$telefone',
    mensagem.isEmpty ? null : {'text': mensagem},
  );
  final aberto = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!aberto && context.mounted) {
    mostrarMensagem(context, 'Não foi possível abrir o WhatsApp.', erro: true);
  }
}

/// Liga para um telefone.
Future<void> ligar(BuildContext context, String numero) async {
  final digitos = Validacoes.somenteDigitos(numero);
  if (digitos.isEmpty) {
    return;
  }
  final aberto = await launchUrl(Uri(scheme: 'tel', path: digitos));
  if (!aberto && context.mounted) {
    mostrarMensagem(context, 'Não foi possível abrir o telefone.', erro: true);
  }
}
