import 'package:supabase_flutter/supabase_flutter.dart';

/// Endereço do backend e chave pública (anon/publishable).
///
/// Os valores entram na compilação com `--dart-define-from-file`, nunca no
/// código. A chave pública pode ficar no app: quem protege os dados são as
/// regras do banco (RLS). A chave service_role NUNCA vai para os apps.
final class ConfiguracaoBackend {
  const ConfiguracaoBackend({required this.url, required this.chavePublica});

  factory ConfiguracaoBackend.doAmbiente() => const ConfiguracaoBackend(
        url: String.fromEnvironment('SUPABASE_URL'),
        chavePublica: String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

  final String url;
  final String chavePublica;

  bool get completa => url.startsWith('https://') && chavePublica.length > 20;
}

/// Liga o app ao backend. Chamar uma vez, antes de `runApp`.
Future<void> iniciarBackend(ConfiguracaoBackend configuracao) async {
  await Supabase.initialize(
    url: configuracao.url,
    publishableKey: configuracao.chavePublica,
  );
}

SupabaseClient get clienteBackend => Supabase.instance.client;
