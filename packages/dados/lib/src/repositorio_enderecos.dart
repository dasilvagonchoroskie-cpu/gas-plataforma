import 'package:nucleo/nucleo.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'erros.dart';

/// Resultado da busca de CEP.
final class DadosCep {
  const DadosCep({
    required this.cep,
    required this.logradouro,
    required this.bairro,
    required this.cidade,
    required this.uf,
  });

  final String cep;
  final String logradouro;
  final String bairro;
  final String cidade;
  final String uf;
}

/// Localização encontrada no mapa.
final class Localizacao {
  const Localizacao({
    required this.latitude,
    required this.longitude,
    this.precisao = 'endereco',
  });

  final double latitude;
  final double longitude;

  /// "endereco", "rua" ou "cidade" (aproximada).
  final String precisao;

  bool get aproximada => precisao == 'cidade';
}

/// Endereço preenchido a partir do GPS.
final class EnderecoDoGps {
  const EnderecoDoGps({
    required this.localizacao,
    required this.cep,
    required this.logradouro,
    required this.numero,
    required this.bairro,
    required this.cidade,
    required this.uf,
  });

  final Localizacao localizacao;
  final String cep;
  final String logradouro;
  final String numero;
  final String bairro;
  final String cidade;
  final String uf;
}

class RepositorioEnderecos {
  RepositorioEnderecos(this._cliente);

  final SupabaseClient _cliente;

  String get _usuarioId {
    final id = _cliente.auth.currentUser?.id;
    if (id == null) {
      throw const ErroDeNegocio('Entre de novo para continuar.');
    }
    return id;
  }

  Future<List<Endereco>> listar() async {
    final linhas = await _cliente
        .from('enderecos')
        .select()
        .eq('cliente_id', _usuarioId)
        .order('criado_em');
    return linhas.map(Endereco.deJson).toList();
  }

  /// Cria ou atualiza. Devolve o endereço salvo (com id).
  Future<Endereco> salvar(Endereco endereco) async {
    final dados = endereco.paraBanco(_usuarioId);
    final Map<String, dynamic> salvo;
    if (endereco.id == null) {
      salvo = await _cliente.from('enderecos').insert(dados).select().single();
    } else {
      dados.remove('cliente_id');
      salvo = await _cliente
          .from('enderecos')
          .update(dados)
          .eq('id', endereco.id!)
          .select()
          .single();
    }
    return Endereco.deJson(salvo);
  }

  Future<void> excluir(String id) async {
    await _cliente.from('enderecos').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> _chamar(Map<String, dynamic> corpo) async {
    final resposta = await _cliente.functions.invoke('endereco', body: corpo);
    final dados = resposta.data;
    if (dados is Map<String, dynamic>) {
      return dados;
    }
    throw const ErroDeNegocio('O serviço de endereços não respondeu. Tente de novo.');
  }

  Future<DadosCep> buscarCep(String cep) async {
    final r = await _chamar({'acao': 'cep', 'cep': Validacoes.somenteDigitos(cep)});
    return DadosCep(
      cep: '${r['cep'] ?? ''}',
      logradouro: '${r['logradouro'] ?? ''}',
      bairro: '${r['bairro'] ?? ''}',
      cidade: '${r['cidade'] ?? ''}',
      uf: '${r['uf'] ?? ''}',
    );
  }

  Future<Localizacao> localizar({
    required String logradouro,
    required String numero,
    required String bairro,
    required String cidade,
    required String uf,
  }) async {
    final r = await _chamar({
      'acao': 'localizar',
      'logradouro': logradouro,
      'numero': numero,
      'bairro': bairro,
      'cidade': cidade,
      'uf': uf,
    });
    return Localizacao(
      latitude: (r['latitude'] as num).toDouble(),
      longitude: (r['longitude'] as num).toDouble(),
      precisao: '${r['precisao'] ?? 'endereco'}',
    );
  }

  Future<EnderecoDoGps> enderecoDoGps(double latitude, double longitude) async {
    final r = await _chamar({
      'acao': 'reverso',
      'latitude': latitude,
      'longitude': longitude,
    });
    return EnderecoDoGps(
      localizacao: Localizacao(latitude: latitude, longitude: longitude),
      cep: '${r['cep'] ?? ''}',
      logradouro: '${r['logradouro'] ?? ''}',
      numero: '${r['numero'] ?? ''}',
      bairro: '${r['bairro'] ?? ''}',
      cidade: '${r['cidade'] ?? ''}',
      uf: '${r['uf'] ?? ''}',
    );
  }
}
