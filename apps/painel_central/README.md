# Painel da central

Shell Flutter Web responsivo para as operações de uma central atribuída. As áreas planejadas são Pedidos, Estoque, Horários e Entregas. A plataforma Web inicial está gerada em `web/` e foi compilada para teste.

O shell não contém fila, status, estoque, capacidade ou dados falsos. Antes de conectar qualquer informação, o backend deverá confirmar que o usuário tem associação ativa à empresa e à central específica. Transferência, reserva, baixa de estoque e transições ainda dependem das decisões D-002 a D-004. As dependências estão fixadas em `pubspec.lock`.

Esta estrutura não inclui app do entregador nem acesso administrativo global. Consulte [`docs/GUIA_BUILDS_TESTE.md`](../../docs/GUIA_BUILDS_TESTE.md) para os limites e o artefato temporário.
