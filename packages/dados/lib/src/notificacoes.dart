import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dados públicos do projeto Firebase (vêm do build, em
/// `config/ambiente_*.json`). Não são segredos: identificam o app no Firebase.
/// A chave secreta de envio fica só no servidor (Vault).
final class ConfiguracaoFirebase {
  const ConfiguracaoFirebase({
    required this.projeto,
    required this.remetente,
    required this.chaveApi,
    required this.appId,
  });

  /// [appId] é o identificador do app no Firebase (um para cada aplicativo:
  /// cliente, Super Central e Central). Cada app passa o seu.
  factory ConfiguracaoFirebase.doAmbiente({required String appId}) =>
      ConfiguracaoFirebase(
        projeto: const String.fromEnvironment('FIREBASE_PROJETO'),
        remetente: const String.fromEnvironment('FIREBASE_REMETENTE'),
        chaveApi: const String.fromEnvironment('FIREBASE_CHAVE_API'),
        appId: appId,
      );

  final String projeto;
  final String remetente;
  final String chaveApi;
  final String appId;

  bool get completa => [projeto, remetente, chaveApi, appId]
      .every((valor) => valor.trim().isNotEmpty);
}

/// Notificações push no aparelho: pede permissão, registra o aparelho no
/// servidor e o desliga quando a pessoa sai da conta.
///
/// Sem a configuração do Firebase (ou no navegador) não faz nada: o app
/// funciona normalmente, só não recebe avisos com ele fechado.
class ServicoNotificacoes {
  ServicoNotificacoes(this._cliente, this._configuracao) {
    _saidas = _cliente.auth.onAuthStateChange.listen((estado) {
      if (estado.event == AuthChangeEvent.signedOut) {
        unawaited(desativar());
      }
    });
  }

  final SupabaseClient _cliente;
  final ConfiguracaoFirebase _configuracao;
  StreamSubscription<AuthState>? _saidas;
  StreamSubscription<String>? _renovacoes;
  bool _iniciado = false;

  /// Só no Android por enquanto (o iPhone precisa da conta Apple).
  bool get disponivel =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      _configuracao.completa;

  Future<void> _iniciarFirebase() async {
    if (_iniciado) {
      return;
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _configuracao.chaveApi,
          appId: _configuracao.appId,
          messagingSenderId: _configuracao.remetente,
          projectId: _configuracao.projeto,
        ),
      );
    }
    _iniciado = true;
  }

  /// Chamar depois do login. Falhas aqui nunca atrapalham o app.
  Future<void> ativar() async {
    if (!disponivel || _cliente.auth.currentUser == null) {
      return;
    }
    try {
      await _iniciarFirebase();
      final mensagens = FirebaseMessaging.instance;
      final permissao = await mensagens.requestPermission();
      if (permissao.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      final token = await mensagens.getToken();
      if (token != null) {
        await _registrar(token);
      }
      _renovacoes ??= mensagens.onTokenRefresh.listen((novo) {
        unawaited(_registrar(novo).catchError((Object _) {}));
      });
    } catch (erro) {
      debugPrint('Notificações indisponíveis: $erro');
    }
  }

  Future<void> _registrar(String token) async {
    if (_cliente.auth.currentUser == null) {
      return;
    }
    await _cliente.rpc('registrar_dispositivo',
        params: {'p_token': token, 'p_plataforma': 'android'});
  }

  /// Ao sair da conta: invalida o identificador deste aparelho, para ele não
  /// receber avisos da conta antiga (o servidor apaga o registro velho).
  Future<void> desativar() async {
    if (!_iniciado) {
      return;
    }
    try {
      await _renovacoes?.cancel();
      _renovacoes = null;
      await FirebaseMessaging.instance.deleteToken();
    } catch (erro) {
      debugPrint('Não foi possível desligar as notificações: $erro');
    }
  }

  void dispose() {
    unawaited(_saidas?.cancel());
    unawaited(_renovacoes?.cancel());
  }
}

/// Situação das notificações vista pelo dono (nunca mostra a chave).
final class SituacaoNotificacoes {
  const SituacaoNotificacoes({required this.configurado, this.projeto});

  factory SituacaoNotificacoes.deJson(Map<String, dynamic> json) =>
      SituacaoNotificacoes(
        configurado: json['configurado'] == true,
        projeto: json['projeto'] as String?,
      );

  final bool configurado;
  final String? projeto;
}

/// Resultado do teste de envio para o próprio aparelho.
final class ResultadoTesteNotificacao {
  const ResultadoTesteNotificacao(
      {required this.enviado, required this.quantidade, this.motivo});

  factory ResultadoTesteNotificacao.deJson(Map<String, dynamic> json) =>
      ResultadoTesteNotificacao(
        enviado: json['enviado'] == true,
        quantidade: (json['quantidade'] as num?)?.toInt() ?? 0,
        motivo: json['motivo'] as String?,
      );

  final bool enviado;
  final int quantidade;
  final String? motivo;

  /// Mensagem em português para mostrar ao dono.
  String get mensagem {
    if (enviado) {
      return quantidade == 1
          ? 'Aviso de teste enviado. Ele deve aparecer neste celular.'
          : 'Aviso de teste enviado para $quantidade aparelhos.';
    }
    return switch (motivo) {
      'sem configuração do Firebase' =>
        'Falta enviar a chave do Firebase (botão acima).',
      'nenhum aparelho registrado' =>
        'Nenhum celular registrado nesta conta. Abra a Super Central pelo '
            'aplicativo no celular, permita as notificações e teste de novo.',
      _ => 'O aviso não foi enviado. Confira a chave e tente de novo.',
    };
  }
}

/// Configuração das notificações pelo dono (função configurar-notificacoes).
class RepositorioNotificacoes {
  RepositorioNotificacoes(this._cliente);

  final SupabaseClient _cliente;

  Future<Map<String, dynamic>> _chamar(Map<String, dynamic> corpo) async {
    final resposta = await _cliente.functions
        .invoke('configurar-notificacoes', body: corpo);
    final dados = resposta.data;
    return dados is Map<String, dynamic> ? dados : const {};
  }

  Future<SituacaoNotificacoes> situacao() async =>
      SituacaoNotificacoes.deJson(await _chamar({'acao': 'situacao'}));

  /// Envia o conteúdo do arquivo .json da conta de serviço. O servidor confere
  /// com o Google antes de guardar.
  Future<SituacaoNotificacoes> enviarChave(String conteudoDoArquivo) async =>
      SituacaoNotificacoes.deJson(await _chamar(
          {'acao': 'guardar', 'arquivo': conteudoDoArquivo.trim()}));

  Future<ResultadoTesteNotificacao> testar() async =>
      ResultadoTesteNotificacao.deJson(await _chamar({'acao': 'testar'}));
}
