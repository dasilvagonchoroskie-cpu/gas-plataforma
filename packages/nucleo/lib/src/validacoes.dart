import 'dart:math';

/// Validações e formatações usadas nos formulários. Cada validador devolve a
/// mensagem de erro em português ou nulo quando o valor está certo.
abstract final class Validacoes {
  static String somenteDigitos(String? texto) =>
      (texto ?? '').replaceAll(RegExp(r'[^0-9]'), '');

  static String? nome(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.length < 2) {
      return 'Informe o nome.';
    }
    if (texto.length > 80) {
      return 'Nome muito longo (máximo 80 letras).';
    }
    return null;
  }

  static String? celular(String? valor) {
    final digitos = somenteDigitos(valor);
    if (digitos.length < 10 || digitos.length > 11) {
      return 'Informe o número com DDD, por exemplo (64) 99999-0000.';
    }
    return null;
  }

  /// Telefone opcional (vazio é aceito).
  static String? telefoneOpcional(String? valor) {
    final digitos = somenteDigitos(valor);
    if (digitos.isEmpty) {
      return null;
    }
    if (digitos.length < 10 || digitos.length > 13) {
      return 'Telefone com DDD, só números.';
    }
    return null;
  }

  static String? email(String? valor) {
    final texto = (valor ?? '').trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(texto)) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  static String? senha(String? valor) {
    final texto = valor ?? '';
    if (texto.length < 8) {
      return 'A senha precisa ter pelo menos 8 caracteres.';
    }
    if (texto.length > 72) {
      return 'Senha muito longa.';
    }
    return null;
  }

  static String? cep(String? valor) {
    if (somenteDigitos(valor).length != 8) {
      return 'O CEP tem 8 números.';
    }
    return null;
  }

  static String? obrigatorio(String? valor, {String campo = 'este campo'}) {
    if ((valor ?? '').trim().isEmpty) {
      return 'Preencha $campo.';
    }
    return null;
  }

  static String? uf(String? valor) {
    if (!RegExp(r'^[A-Za-z]{2}$').hasMatch((valor ?? '').trim())) {
      return 'UF com 2 letras.';
    }
    return null;
  }

  /// "64999990000" → "(64) 99999-0000".
  static String formatarTelefone(String? valor) {
    var digitos = somenteDigitos(valor);
    if (digitos.length > 11 && digitos.startsWith('55')) {
      digitos = digitos.substring(2);
    }
    if (digitos.length == 11) {
      return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 7)}-${digitos.substring(7)}';
    }
    if (digitos.length == 10) {
      return '(${digitos.substring(0, 2)}) ${digitos.substring(2, 6)}-${digitos.substring(6)}';
    }
    return digitos;
  }

  /// "75600000" → "75600-000".
  static String formatarCep(String? valor) {
    final digitos = somenteDigitos(valor);
    if (digitos.length != 8) {
      return digitos;
    }
    return '${digitos.substring(0, 5)}-${digitos.substring(5)}';
  }

  /// Número para abrir o WhatsApp (com 55 na frente).
  static String whatsappInternacional(String? valor) {
    final digitos = somenteDigitos(valor);
    if (digitos.isEmpty) {
      return '';
    }
    return digitos.startsWith('55') && digitos.length >= 12
        ? digitos
        : '55$digitos';
  }
}

/// Gera um identificador único (UUID versão 4) para o pedido não ser
/// duplicado se o app precisar reenviar por falta de internet.
String gerarIdentificadorUnico([Random? gerador]) {
  final aleatorio = gerador ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => aleatorio.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
