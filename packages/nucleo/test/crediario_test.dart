import 'package:flutter_test/flutter_test.dart';
import 'package:nucleo/nucleo.dart';

void main() {
  group('CPF', () {
    test('confere os dígitos verificadores', () {
      expect(Validacoes.cpfValido('529.982.247-25'), isTrue);
      expect(Validacoes.cpfValido('52998224724'), isFalse);
      expect(Validacoes.cpfValido('111.111.111-11'), isFalse);
      expect(Validacoes.cpfValido('123'), isFalse);
      expect(Validacoes.cpf('12345678909'), isNull);
      expect(Validacoes.cpf('12345678900'), isNotNull);
    });

    test('formata e esconde o CPF', () {
      expect(Validacoes.formatarCpf('52998224725'), '529.982.247-25');
      expect(Validacoes.cpfMascarado('52998224725'), '529.***.***-25');
    });
  });

  group('Datas da ficha', () {
    test('lê a data digitada', () {
      expect(Datas.lerDataDigitada('16/10/1980'), DateTime.utc(1980, 10, 16));
      expect(Datas.lerDataDigitada('31/02/1980'), isNull);
      expect(Datas.lerDataDigitada('1/1/80'), isNull);
    });

    test('calcula a idade em anos completos', () {
      final agora = DateTime.utc(2026, 10, 16, 15);
      expect(Datas.idade(DateTime.utc(2008, 10, 16), agora: agora), 18);
      expect(Datas.idade(DateTime.utc(2008, 10, 17), agora: agora), 17);
    });
  });

  group('Crediário', () {
    test('forma de pagamento fiado não é paga na entrega', () {
      expect(FormaPagamento.deValor('crediario'), FormaPagamento.crediario);
      expect(FormaPagamento.crediario.naEntrega, isFalse);
      expect(FormaPagamento.paraReceber,
          isNot(contains(FormaPagamento.crediario)));
    });

    test('resumo diz quando o cliente pode comprar fiado', () {
      final resumo = ResumoCredito.deJson({
        'cliente_id': 'c1',
        'status': 'aprovada',
        'bloqueado': false,
        'limite_centavos': 20000,
        'devido_centavos': 5000,
        'reservado_centavos': 5000,
        'disponivel_centavos': 10000,
      });
      expect(resumo.podeComprarFiado, isTrue);
      expect(resumo.disponivel, const Dinheiro(10000));

      final semFicha = ResumoCredito.deJson({
        'cliente_id': 'c1',
        'status': null,
        'bloqueado': false,
        'limite_centavos': 0,
        'devido_centavos': 0,
        'reservado_centavos': 0,
        'disponivel_centavos': 0,
      });
      expect(semFicha.temFicha, isFalse);
      expect(semFicha.podeComprarFiado, isFalse);
    });

    test('lê a ficha completa com o endereço', () {
      final ficha = FichaCliente.deJson({
        'cliente_id': 'c1',
        'cpf': '52998224725',
        'rg': '1234567',
        'data_nascimento': '1980-10-16',
        'nome_mae': 'Maria',
        'empresa': 'Autônomo',
        'profissao': 'Motorista',
        'telefone_trabalho': '',
        'renda_mensal_centavos': 250000,
        'referencia1_nome': 'José',
        'referencia1_telefone': '64999991111',
        'referencia1_relacao': 'Irmão',
        'referencia2_nome': 'Ana',
        'referencia2_telefone': '64999992222',
        'referencia2_relacao': 'Vizinha',
        'documento_caminho': 'c1/documento.jpg',
        'comprovante_caminho': 'c1/comprovante.jpg',
        'status': 'pendente',
        'limite_centavos': 0,
        'credito_bloqueado': false,
        'enviado_em': '2026-10-16T15:00:00Z',
        'nome': 'Cliente',
        'endereco': {
          'logradouro': 'Rua Um',
          'numero': '10',
          'bairro': 'Centro',
          'cidade': 'Goiatuba',
          'uf': 'GO',
          'complemento': null,
        },
      });
      expect(ficha.status, StatusFicha.pendente);
      expect(ficha.rendaMensal, const Dinheiro(250000));
      expect(ficha.enderecoTexto, 'Rua Um, 10 - Centro, Goiatuba/GO');
    });

    test('dados da ficha saem no formato do banco', () {
      final dados = DadosFicha(
        cpf: '52998224725',
        rg: ' 1234567 ',
        dataNascimento: DateTime.utc(1980, 10, 16),
        nomeMae: 'Maria',
        enderecoId: 'e1',
        empresa: 'Autônomo',
        profissao: 'Motorista',
        telefoneTrabalho: '',
        rendaMensal: const Dinheiro(250000),
        referencia1Nome: 'José',
        referencia1Telefone: '64999991111',
        referencia1Relacao: 'Irmão',
        referencia2Nome: 'Ana',
        referencia2Telefone: '64999992222',
        referencia2Relacao: 'Vizinha',
        documentoCaminho: 'c1/documento.jpg',
        comprovanteCaminho: 'c1/comprovante.jpg',
      ).paraBanco();
      expect(dados['data_nascimento'], '1980-10-16');
      expect(dados['rg'], '1234567');
      expect(dados['renda_mensal_centavos'], 250000);
    });

    test('extrato lê pagamento com a forma usada', () {
      final lancamento = LancamentoCredito.deJson({
        'id': 'l1',
        'tipo': 'pagamento',
        'valor_centavos': -4000,
        'forma': 'pix_na_entrega',
        'criado_em': '2026-10-16T15:00:00Z',
      });
      expect(lancamento.tipo, TipoLancamento.pagamento);
      expect(lancamento.forma, FormaPagamento.pixNaEntrega);
      expect(lancamento.valor, const Dinheiro(-4000));
    });
  });
}
