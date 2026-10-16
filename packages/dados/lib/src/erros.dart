import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Transforma qualquer erro em uma frase simples em português para mostrar na
/// tela. Detalhes técnicos não aparecem para o usuário.
String mensagemDeErro(Object erro) {
  if (erro is ErroDeNegocio) {
    return erro.mensagem;
  }

  if (erro is AuthException) {
    final texto = erro.message.toLowerCase();
    if (texto.contains('invalid login') ||
        texto.contains('invalid_credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (texto.contains('banned')) {
      return 'Seu acesso está desativado. Fale com o responsável pela revenda.';
    }
    if (texto.contains('rate limit') || texto.contains('too many')) {
      return 'Muitas tentativas seguidas. Espere alguns minutos e tente de novo.';
    }
    if (texto.contains('email not confirmed')) {
      return 'Seu e-mail ainda não foi confirmado.';
    }
    if (texto.contains('jwt') ||
        texto.contains('session') ||
        texto.contains('refresh')) {
      return 'Sua sessão expirou. Entre de novo.';
    }
    return 'Não foi possível entrar agora. Tente de novo.';
  }

  if (erro is FunctionException) {
    final detalhes = erro.details;
    if (detalhes is Map && detalhes['erro'] is String) {
      return detalhes['erro'] as String;
    }
    if (erro.status == 401) {
      return 'Sua sessão expirou. Entre de novo.';
    }
    return 'O servidor não respondeu como esperado. Tente de novo.';
  }

  if (erro is PostgrestException) {
    final codigo = erro.code ?? '';
    // Mensagens escritas por nós nas funções do banco (já em português).
    if (const {'P0001', 'P0002', '22023'}.contains(codigo) ||
        (codigo == '42501' && _pareceNossa(erro.message))) {
      return erro.message;
    }
    if (codigo == '42501') {
      return 'Você não tem permissão para fazer isso.';
    }
    if (codigo == '23505') {
      return 'Já existe um cadastro igual a este.';
    }
    if (codigo == '23514' && _pareceNossa(erro.message)) {
      return erro.message;
    }
    if (codigo == '23514' || codigo == '23502' || codigo == '22P02') {
      return 'Algum dado ficou inválido. Confira o formulário.';
    }
    if (codigo == 'PGRST301' || codigo == 'PGRST303') {
      return 'Sua sessão expirou. Entre de novo.';
    }
    return 'Não foi possível concluir. Tente de novo.';
  }

  if (erro is StorageException) {
    return 'Não foi possível enviar a foto. Use uma imagem JPG, PNG ou WEBP de até 2 MB.';
  }

  if (erro is TimeoutException) {
    return 'A internet está lenta. Tente de novo.';
  }

  final texto = erro.toString().toLowerCase();
  if (texto.contains('socket') ||
      texto.contains('failed host lookup') ||
      texto.contains('network') ||
      texto.contains('clientexception') ||
      texto.contains('connection')) {
    return 'Sem internet no momento. Confira a conexão e tente de novo.';
  }
  return 'Algo deu errado. Tente de novo.';
}

/// Nossas mensagens são frases em português que terminam com ponto.
bool _pareceNossa(String mensagem) =>
    mensagem.endsWith('.') &&
    !RegExp(r'permission|denied|violates|policy|relation|column|function',
            caseSensitive: false)
        .hasMatch(mensagem);

/// Erro de regra conhecida, já com a frase para o usuário.
final class ErroDeNegocio implements Exception {
  const ErroDeNegocio(this.mensagem);

  final String mensagem;

  @override
  String toString() => mensagem;
}
