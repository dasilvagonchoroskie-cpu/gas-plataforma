import 'dart:async';

import 'package:dados/dados.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Mensagens de erro em português', () {
    test('mostra a mensagem escrita pelas funções do banco', () {
      final erro = PostgrestException(
        message: 'Esse horário acabou de lotar. Escolha outro horário.',
        code: 'P0001',
      );
      expect(mensagemDeErro(erro), 'Esse horário acabou de lotar. Escolha outro horário.');
    });

    test('esconde mensagens técnicas do banco', () {
      final erro = PostgrestException(
        message: 'permission denied for table pedidos',
        code: '42501',
      );
      expect(mensagemDeErro(erro), 'Você não tem permissão para fazer isso.');
    });

    test('traduz login inválido', () {
      final erro = AuthException('Invalid login credentials');
      expect(mensagemDeErro(erro), 'E-mail ou senha incorretos.');
    });

    test('usa o texto devolvido pelas funções do servidor', () {
      final erro = FunctionException(
        status: 409,
        details: {'erro': 'Este e-mail já tem cadastro. Entre com sua senha.'},
      );
      expect(mensagemDeErro(erro), 'Este e-mail já tem cadastro. Entre com sua senha.');
    });

    test('avisa quando falta internet', () {
      expect(
        mensagemDeErro(Exception('SocketException: Failed host lookup')),
        'Sem internet no momento. Confira a conexão e tente de novo.',
      );
      expect(mensagemDeErro(TimeoutException('x')), 'A internet está lenta. Tente de novo.');
    });

    test('configuração sem endereço não é considerada completa', () {
      expect(const ConfiguracaoBackend(url: '', chavePublica: '').completa, isFalse);
      expect(
        const ConfiguracaoBackend(
          url: 'https://exemplo.supabase.co',
          chavePublica: 'sb_publishable_1234567890abcdef',
        ).completa,
        isTrue,
      );
    });
  });
}
