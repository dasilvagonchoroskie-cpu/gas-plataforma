import 'package:nucleo/nucleo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'erros.dart';

/// Login, cadastro, perfil e exclusão de conta.
class RepositorioConta {
  RepositorioConta(this._cliente);

  final SupabaseClient _cliente;

  String? get usuarioId => _cliente.auth.currentUser?.id;

  bool get logado => _cliente.auth.currentSession != null;

  Stream<AuthState> get mudancasDeLogin => _cliente.auth.onAuthStateChange;

  Future<void> entrar({required String email, required String senha}) async {
    await _cliente.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: senha,
    );
  }

  /// Cria a conta de cliente (pelo servidor) e já entra.
  Future<void> cadastrar({
    required String nome,
    required String telefone,
    required String email,
    required String senha,
  }) async {
    await _cliente.functions.invoke(
      'cadastro',
      body: {
        'nome': nome.trim(),
        'telefone': Validacoes.somenteDigitos(telefone),
        'email': email.trim().toLowerCase(),
        'senha': senha,
      },
    );
    await entrar(email: email, senha: senha);
  }

  Future<void> recuperarSenha(String email) async {
    await _cliente.auth.resetPasswordForEmail(email.trim().toLowerCase());
  }

  Future<void> sair() => _cliente.auth.signOut();

  /// Perfil de quem está logado (com a central, se for operador).
  Future<Perfil?> perfilAtual() async {
    final id = usuarioId;
    if (id == null) {
      return null;
    }
    final dados =
        await _cliente.from('perfis').select().eq('id', id).maybeSingle();
    if (dados == null) {
      return null;
    }
    String? centralId;
    if (dados['papel'] == PapelPerfil.operadorCentral.valor) {
      final vinculo = await _cliente
          .from('operadores_central')
          .select('central_id')
          .eq('perfil_id', id)
          .maybeSingle();
      centralId = vinculo?['central_id'] as String?;
    }
    return Perfil.deJson(dados, centralId: centralId);
  }

  Future<void> atualizarPerfil({
    required String nome,
    required String telefone,
  }) async {
    final id = usuarioId;
    if (id == null) {
      throw const ErroDeNegocio('Entre de novo para alterar seus dados.');
    }
    await _cliente.from('perfis').update({
      'nome': nome.trim(),
      'telefone': Validacoes.somenteDigitos(telefone),
    }).eq('id', id);
  }

  Future<void> trocarSenha(String novaSenha) async {
    await _cliente.auth.updateUser(UserAttributes(password: novaSenha));
  }

  /// Apaga a conta do cliente (dados pessoais removidos, pedidos anonimizados).
  Future<void> excluirConta() async {
    await _cliente.functions.invoke('excluir-conta');
    await _cliente.auth.signOut();
  }

  /// Guarda o aparelho para receber notificações.
  Future<void> registrarDispositivo(String token, String plataforma) async {
    await _cliente.rpc(
      'registrar_dispositivo',
      params: {'p_token': token, 'p_plataforma': plataforma},
    );
  }
}
