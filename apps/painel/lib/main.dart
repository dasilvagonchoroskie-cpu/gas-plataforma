import 'package:dados/dados.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configuracao = ConfiguracaoBackend.doAmbiente();
  if (!configuracao.completa) {
    runApp(const PainelSemConfiguracao());
    return;
  }
  await iniciarBackend(configuracao);
  runApp(const ProviderScope(child: AplicativoPainel()));
}
