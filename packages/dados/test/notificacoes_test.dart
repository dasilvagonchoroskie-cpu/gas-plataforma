import 'package:dados/dados.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sem os dados do Firebase no build, as notificações ficam desligadas',
      () {
    const vazia = ConfiguracaoFirebase(
        projeto: '', remetente: '', chaveApi: '', appId: '');
    const completa = ConfiguracaoFirebase(
        projeto: 'gas-agua', remetente: '123', chaveApi: 'AIza', appId: '1:1');

    expect(vazia.completa, isFalse);
    expect(completa.completa, isTrue);
    expect(ConfiguracaoFirebase.doAmbiente(appId: '').completa, isFalse);
  });

  test('resultado do teste vira uma frase para o dono', () {
    expect(
      ResultadoTesteNotificacao.deJson(const {'enviado': true, 'quantidade': 1})
          .mensagem,
      contains('deve aparecer neste celular'),
    );
    expect(
      ResultadoTesteNotificacao.deJson(const {
        'enviado': false,
        'quantidade': 0,
        'motivo': 'nenhum aparelho registrado',
      }).mensagem,
      contains('Nenhum celular registrado'),
    );
    expect(
      ResultadoTesteNotificacao.deJson(const {
        'enviado': false,
        'motivo': 'sem configuração do Firebase',
      }).mensagem,
      contains('Falta enviar a chave'),
    );
    final situacao = SituacaoNotificacoes.deJson(
        const {'configurado': true, 'projeto': 'gas-agua-dev'});
    expect(situacao.configurado, isTrue);
    expect(situacao.projeto, 'gas-agua-dev');
  });
}
