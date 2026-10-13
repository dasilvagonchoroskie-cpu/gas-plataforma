/// Configuração pública de identidade visual de uma empresa.
///
/// Esta configuração pode ser incluída em uma variante do aplicativo. Ela não
/// concede acesso aos dados da empresa: a autorização continua sendo validada
/// pelo backend e pelas políticas RLS.
final class ConfiguracaoMarcaEmpresa {
  ConfiguracaoMarcaEmpresa({
    required String empresaId,
    required String nomeAplicativo,
    required String corPrimariaHex,
    required String urlLogo,
  })  : empresaId = _textoObrigatorio(
          empresaId,
          campo: 'empresa_id',
          limite: 128,
        ),
        nomeAplicativo = _textoObrigatorio(
          nomeAplicativo,
          campo: 'nome_aplicativo',
          limite: 80,
        ),
        corPrimariaHex = _validarCor(corPrimariaHex),
        urlLogo = _validarUrlLogo(urlLogo);

  /// Identificador público usado para selecionar a configuração da empresa.
  /// Não é uma credencial e não deve ser usado como autorização.
  final String empresaId;

  /// Nome apresentado na identidade visual do aplicativo.
  final String nomeAplicativo;

  /// Cor principal no formato hexadecimal `#RRGGBB`.
  final String corPrimariaHex;

  /// Endereço HTTPS público do logo, sem credenciais de acesso.
  final String urlLogo;

  /// Cria a configuração a partir de campos em formato `snake_case`.
  factory ConfiguracaoMarcaEmpresa.fromJson(Map<String, Object?> json) {
    return ConfiguracaoMarcaEmpresa(
      empresaId: _campoTexto(json, 'empresa_id'),
      nomeAplicativo: _campoTexto(json, 'nome_aplicativo'),
      corPrimariaHex: _campoTexto(json, 'cor_primaria_hex'),
      urlLogo: _campoTexto(json, 'url_logo'),
    );
  }

  /// Converte a configuração para os nomes de campo compartilhados com o backend.
  Map<String, Object> toJson() => {
        'empresa_id': empresaId,
        'nome_aplicativo': nomeAplicativo,
        'cor_primaria_hex': corPrimariaHex,
        'url_logo': urlLogo,
      };
}

String _campoTexto(Map<String, Object?> json, String campo) {
  final valor = json[campo];
  if (valor is! String) {
    throw FormatException('O campo "$campo" precisa ser um texto.');
  }
  return valor;
}

String _textoObrigatorio(
  String valor, {
  required String campo,
  required int limite,
}) {
  final normalizado = valor.trim();
  if (normalizado.isEmpty) {
    throw FormatException('O campo "$campo" não pode ficar vazio.');
  }
  if (normalizado.length > limite) {
    throw FormatException('O campo "$campo" excede o limite permitido.');
  }
  return normalizado;
}

String _validarCor(String valor) {
  final normalizado = valor.trim();
  if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(normalizado)) {
    throw const FormatException(
      'A cor principal precisa estar no formato hexadecimal #RRGGBB.',
    );
  }
  return normalizado.toUpperCase();
}

String _validarUrlLogo(String valor) {
  final normalizado = valor.trim();
  if (normalizado.length > 2048) {
    throw const FormatException('O endereço do logo é longo demais.');
  }

  final uri = Uri.tryParse(normalizado);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException(
      'O logo precisa usar um endereço HTTPS público, sem usuário ou senha.',
    );
  }
  return uri.toString();
}
