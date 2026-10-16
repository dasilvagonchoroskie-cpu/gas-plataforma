/// Situação do pedido, com os mesmos valores do banco (`status_pedido`).
enum StatusPedido {
  novo('novo', 'Recebido', 'Novo'),
  confirmado('confirmado', 'Confirmado', 'Confirmado'),
  emRota('em_rota', 'Saiu para entrega', 'Em rota'),
  entregue('entregue', 'Entregue', 'Entregue'),
  cancelado('cancelado', 'Cancelado', 'Cancelado');

  const StatusPedido(this.valor, this.rotuloCliente, this.rotuloCentral);

  /// Valor gravado no banco.
  final String valor;

  /// Texto mostrado para o cliente.
  final String rotuloCliente;

  /// Texto curto mostrado no painel da central.
  final String rotuloCentral;

  bool get ehFinal =>
      this == StatusPedido.entregue || this == StatusPedido.cancelado;

  bool get emAndamento => !ehFinal;

  /// Ordem das etapas na linha do tempo do cliente.
  int get etapa => switch (this) {
        StatusPedido.novo => 0,
        StatusPedido.confirmado => 1,
        StatusPedido.emRota => 2,
        StatusPedido.entregue => 3,
        StatusPedido.cancelado => -1,
      };

  /// Próximo passo normal da central (botão principal no painel).
  StatusPedido? get proximoPassoCentral => switch (this) {
        StatusPedido.novo => StatusPedido.confirmado,
        StatusPedido.confirmado => StatusPedido.emRota,
        StatusPedido.emRota => StatusPedido.entregue,
        StatusPedido.entregue || StatusPedido.cancelado => null,
      };

  /// Texto do botão que leva ao próximo passo.
  String? get acaoProximoPasso => switch (this) {
        StatusPedido.novo => 'Confirmar pedido',
        StatusPedido.confirmado => 'Saiu para entrega',
        StatusPedido.emRota => 'Marcar como entregue',
        StatusPedido.entregue || StatusPedido.cancelado => null,
      };

  /// O cliente só cancela enquanto o pedido é novo.
  bool get clientePodeCancelar => this == StatusPedido.novo;

  /// A central transfere enquanto o pedido não saiu para entrega.
  bool get podeTransferir =>
      this == StatusPedido.novo || this == StatusPedido.confirmado;

  static StatusPedido deValor(String valor) => StatusPedido.values.firstWhere(
        (s) => s.valor == valor,
        orElse: () => throw FormatException('Status desconhecido: $valor'),
      );
}

/// Forma de pagamento (valores do banco). As três primeiras são pagas na
/// entrega; no crediário (fiado) o valor entra na conta do cliente.
enum FormaPagamento {
  dinheiro('dinheiro', 'Dinheiro'),
  cartaoNaEntrega('cartao_na_entrega', 'Cartão na maquininha'),
  pixNaEntrega('pix_na_entrega', 'Pix na entrega'),
  crediario('crediario', 'Crediário (fiado)');

  const FormaPagamento(this.valor, this.rotulo);

  final String valor;
  final String rotulo;

  /// Pago na hora da entrega (não é fiado).
  bool get naEntrega => this != FormaPagamento.crediario;

  /// Formas aceitas para receber um pagamento do crediário.
  static const List<FormaPagamento> paraReceber = [
    FormaPagamento.dinheiro,
    FormaPagamento.pixNaEntrega,
    FormaPagamento.cartaoNaEntrega,
  ];

  static FormaPagamento deValor(String valor) =>
      FormaPagamento.values.firstWhere(
        (f) => f.valor == valor,
        orElse: () => throw FormatException('Pagamento desconhecido: $valor'),
      );
}

/// Papel do usuário (valores do banco).
enum PapelPerfil {
  cliente('cliente', 'Cliente'),
  operadorCentral('operador_central', 'Operador de central'),
  entregador('entregador', 'Entregador'),
  dono('dono', 'Administrador (dono)');

  const PapelPerfil(this.valor, this.rotulo);

  final String valor;
  final String rotulo;

  static PapelPerfil deValor(String valor) => PapelPerfil.values.firstWhere(
        (p) => p.valor == valor,
        orElse: () => throw FormatException('Papel desconhecido: $valor'),
      );
}

/// Categoria do produto.
enum CategoriaProduto {
  gas('gas', 'Gás'),
  agua('agua', 'Água');

  const CategoriaProduto(this.valor, this.rotulo);

  final String valor;
  final String rotulo;

  static CategoriaProduto deValor(String valor) =>
      CategoriaProduto.values.firstWhere(
        (c) => c.valor == valor,
        orElse: () => throw FormatException('Categoria desconhecida: $valor'),
      );
}

/// Tipos de movimento de estoque que a central registra à mão.
enum TipoMovimentoEstoque {
  entrada('entrada', 'Entrada (chegou carga)'),
  saida('saida', 'Saída (perda, devolução)'),
  ajuste('ajuste', 'Ajuste (+ ou -)'),
  contagem('contagem', 'Contagem (o que tem agora)'),
  entregaPedido('entrega_pedido', 'Entrega de pedido');

  const TipoMovimentoEstoque(this.valor, this.rotulo);

  final String valor;
  final String rotulo;

  static TipoMovimentoEstoque deValor(String valor) =>
      TipoMovimentoEstoque.values.firstWhere(
        (t) => t.valor == valor,
        orElse: () => throw FormatException('Movimento desconhecido: $valor'),
      );
}

/// Situação da ficha de cadastro.
enum StatusFicha {
  pendente('pendente', 'Em análise'),
  aprovada('aprovada', 'Aprovada'),
  recusada('recusada', 'Recusada');

  const StatusFicha(this.valor, this.rotulo);

  final String valor;
  final String rotulo;

  static StatusFicha deValor(String valor) => StatusFicha.values.firstWhere(
        (s) => s.valor == valor,
        orElse: () => throw FormatException('Situação desconhecida: $valor'),
      );
}

/// Tipo de lançamento na conta do crediário.
enum TipoLancamento {
  compra('compra', 'Compra no fiado'),
  pagamento('pagamento', 'Pagamento'),
  ajuste('ajuste', 'Ajuste');

  const TipoLancamento(this.valor, this.rotulo);

  final String valor;
  final String rotulo;

  static TipoLancamento deValor(String valor) => TipoLancamento.values.firstWhere(
        (t) => t.valor == valor,
        orElse: () => throw FormatException('Lançamento desconhecido: $valor'),
      );
}
