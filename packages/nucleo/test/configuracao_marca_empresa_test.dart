import 'package:flutter_test/flutter_test.dart';
import 'package:nucleo/nucleo.dart';

void main() {
  group('ConfiguracaoMarcaEmpresa', () {
    test('normaliza textos e cor', () {
      final configuracao = ConfiguracaoMarcaEmpresa(
        empresaId: '  empresa-123  ',
        nomeAplicativo: '  Gás Goiatuba  ',
        corPrimariaHex: ' #a1b2c3 ',
        urlLogo: ' https://imagens.exemplo.com/logo.png ',
      );

      expect(configuracao.empresaId, 'empresa-123');
      expect(configuracao.nomeAplicativo, 'Gás Goiatuba');
      expect(configuracao.corPrimariaHex, '#A1B2C3');
      expect(configuracao.urlLogo, 'https://imagens.exemplo.com/logo.png');
    });

    test('converte os campos para nomes snake_case', () {
      final configuracao = _configuracaoValida();

      expect(configuracao.toJson(), {
        'empresa_id': 'empresa-123',
        'nome_aplicativo': 'Gás Goiatuba',
        'cor_primaria_hex': '#A1B2C3',
        'url_logo': 'https://imagens.exemplo.com/logo.png',
      });
    });

    test('lê os campos do formato compartilhado com o backend', () {
      final configuracao = ConfiguracaoMarcaEmpresa.fromJson({
        'empresa_id': 'empresa-123',
        'nome_aplicativo': 'Gás Goiatuba',
        'cor_primaria_hex': '#a1b2c3',
        'url_logo': 'https://imagens.exemplo.com/logo.png',
      });

      expect(configuracao, isA<ConfiguracaoMarcaEmpresa>());
      expect(configuracao.corPrimariaHex, '#A1B2C3');
    });

    test('rejeita identificador vazio', () {
      expect(
        () => ConfiguracaoMarcaEmpresa(
          empresaId: ' ',
          nomeAplicativo: 'Gás Goiatuba',
          corPrimariaHex: '#A1B2C3',
          urlLogo: 'https://imagens.exemplo.com/logo.png',
        ),
        throwsFormatException,
      );
    });

    test('rejeita nome vazio ou longo demais', () {
      expect(
        () => ConfiguracaoMarcaEmpresa(
          empresaId: 'empresa-123',
          nomeAplicativo: ' ',
          corPrimariaHex: '#A1B2C3',
          urlLogo: 'https://imagens.exemplo.com/logo.png',
        ),
        throwsFormatException,
      );
      expect(
        () => ConfiguracaoMarcaEmpresa(
          empresaId: 'empresa-123',
          nomeAplicativo: 'a' * 81,
          corPrimariaHex: '#A1B2C3',
          urlLogo: 'https://imagens.exemplo.com/logo.png',
        ),
        throwsFormatException,
      );
    });

    test('rejeita cor fora do formato #RRGGBB', () {
      expect(
        () => ConfiguracaoMarcaEmpresa(
          empresaId: 'empresa-123',
          nomeAplicativo: 'Gás Goiatuba',
          corPrimariaHex: 'blue',
          urlLogo: 'https://imagens.exemplo.com/logo.png',
        ),
        throwsFormatException,
      );
    });

    test('aceita somente logo HTTPS sem credenciais', () {
      for (final url in [
        'http://imagens.exemplo.com/logo.png',
        'https:///logo.png',
        'https://usuario:senha@imagens.exemplo.com/logo.png',
      ]) {
        expect(
          () => ConfiguracaoMarcaEmpresa(
            empresaId: 'empresa-123',
            nomeAplicativo: 'Gás Goiatuba',
            corPrimariaHex: '#A1B2C3',
            urlLogo: url,
          ),
          throwsFormatException,
          reason: 'O endereço $url deveria ser rejeitado.',
        );
      }
    });

    test('rejeita campos JSON ausentes ou de tipo incorreto', () {
      expect(
        () => ConfiguracaoMarcaEmpresa.fromJson({
          'empresa_id': 123,
          'nome_aplicativo': 'Gás Goiatuba',
          'cor_primaria_hex': '#A1B2C3',
          'url_logo': 'https://imagens.exemplo.com/logo.png',
        }),
        throwsFormatException,
      );
      expect(
        () => ConfiguracaoMarcaEmpresa.fromJson({
          'empresa_id': 'empresa-123',
        }),
        throwsFormatException,
      );
    });
  });
}

ConfiguracaoMarcaEmpresa _configuracaoValida() {
  return ConfiguracaoMarcaEmpresa(
    empresaId: 'empresa-123',
    nomeAplicativo: 'Gás Goiatuba',
    corPrimariaHex: '#A1B2C3',
    urlLogo: 'https://imagens.exemplo.com/logo.png',
  );
}
