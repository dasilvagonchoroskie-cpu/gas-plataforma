-- Fase 1 — tipos e tabelas da plataforma de gás e água.
--
-- Uma única revenda, com quantas centrais o dono quiser abrir. Cada central tem
-- localização (latitude/longitude) e faixas de entrega por distância. O pedido
-- vai para a central ativa mais próxima que atende aquela distância e pode ser
-- transferido para outra central quando faltar mercadoria.
--
-- Regras gerais: dinheiro em centavos inteiros (sufixo _centavos); datas em UTC
-- no banco e exibidas em America/Sao_Paulo; RLS em todas as tabelas (migration
-- de permissões).

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------------

create type public.papel_perfil as enum (
  'cliente',
  'operador_central',
  'entregador',
  'dono'
);

create type public.status_pedido as enum (
  'novo',
  'confirmado',
  'em_rota',
  'entregue',
  'cancelado'
);

create type public.forma_pagamento as enum (
  'dinheiro',
  'cartao_na_entrega',
  'pix_na_entrega'
);

create type public.tipo_movimento_estoque as enum (
  'entrada',
  'saida',
  'ajuste',
  'contagem',
  'entrega_pedido'
);

create type public.evento_historico as enum (
  'status',
  'transferencia',
  'entregador'
);

-- ---------------------------------------------------------------------------
-- Pessoas e centrais
-- ---------------------------------------------------------------------------

-- O id é o mesmo do login (auth.users). Não há chave estrangeira para auth.users
-- de propósito: quando o cliente exclui a conta, o login é apagado e o perfil
-- fica anonimizado, preservando os pedidos para os relatórios.
create table public.perfis (
  id uuid primary key,
  nome text not null check (char_length(btrim(nome)) between 1 and 80),
  telefone text not null default '' check (telefone ~ '^[0-9]{0,13}$'),
  email text check (email is null or char_length(email) <= 254),
  papel public.papel_perfil not null default 'cliente',
  ativo boolean not null default true,
  excluido_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

comment on table public.perfis is
  'Dados do usuário ligados ao login. O papel só muda pelo servidor (função admin-usuarios).';

create table public.centrais (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (char_length(btrim(nome)) between 1 and 80),
  cidade text not null check (char_length(btrim(cidade)) between 1 and 80),
  uf char(2) not null check (uf ~ '^[A-Z]{2}$'),
  endereco text not null default '' check (char_length(endereco) <= 200),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  whatsapp text check (whatsapp is null or whatsapp ~ '^[0-9]{10,13}$'),
  ativa boolean not null default false,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

comment on table public.centrais is
  'Centrais da revenda. São dados, nunca código: o dono cria quantas quiser pelo painel.';

-- Cada operador pertence a uma única central.
create table public.operadores_central (
  perfil_id uuid primary key references public.perfis (id) on delete cascade,
  central_id uuid not null references public.centrais (id) on delete restrict,
  criado_em timestamptz not null default now()
);

-- No piloto o entregador é só um cadastro da central (sem login). O campo
-- perfil_id fica pronto para o futuro app do entregador.
create table public.entregadores (
  id uuid primary key default gen_random_uuid(),
  central_id uuid not null references public.centrais (id) on delete restrict,
  nome text not null check (char_length(btrim(nome)) between 1 and 80),
  telefone text not null default '' check (telefone ~ '^[0-9]{0,13}$'),
  ativo boolean not null default true,
  perfil_id uuid unique references public.perfis (id) on delete set null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint entregadores_central_id_unico unique (central_id, id)
);

-- Faixas de entrega por distância em linha reta a partir da central.
-- A maior faixa define o alcance da central. Ex.: até 5 km grátis, até 15 km R$ 5.
create table public.faixas_entrega (
  id uuid primary key default gen_random_uuid(),
  central_id uuid not null references public.centrais (id) on delete cascade,
  ate_km numeric(6, 2) not null check (ate_km > 0 and ate_km <= 300),
  taxa_entrega_centavos integer not null default 0
    check (taxa_entrega_centavos between 0 and 100000),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint faixas_entrega_distancia_unica unique (central_id, ate_km)
);

-- ---------------------------------------------------------------------------
-- Catálogo, preços e estoque
-- ---------------------------------------------------------------------------

create table public.produtos (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (char_length(btrim(nome)) between 1 and 80),
  categoria text not null check (categoria in ('gas', 'agua')),
  descricao text check (descricao is null or char_length(descricao) <= 300),
  foto_url text check (foto_url is null or foto_url ~ '^https://'),
  -- Verdadeiro quando o cliente entrega o vasilhame vazio na troca.
  troca_vasilhame boolean not null default false,
  ordem integer not null default 0,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table public.precos_central (
  central_id uuid not null references public.centrais (id) on delete cascade,
  produto_id uuid not null references public.produtos (id) on delete restrict,
  preco_centavos integer not null check (preco_centavos between 1 and 10000000),
  disponivel boolean not null default true,
  atualizado_em timestamptz not null default now(),
  primary key (central_id, produto_id)
);

-- Estoque físico da central. Pode ficar negativo de propósito: uma contagem
-- desatualizada nunca deve impedir a central de confirmar uma entrega feita.
-- O painel destaca valores negativos para a central corrigir pela contagem.
create table public.estoque_central (
  central_id uuid not null references public.centrais (id) on delete cascade,
  produto_id uuid not null references public.produtos (id) on delete restrict,
  cheios integer not null default 0,
  vazios integer not null default 0,
  alerta_minimo integer not null default 0 check (alerta_minimo >= 0),
  atualizado_em timestamptz not null default now(),
  primary key (central_id, produto_id)
);

-- ---------------------------------------------------------------------------
-- Agenda de entregas
-- ---------------------------------------------------------------------------

-- dia_semana: 0 = domingo ... 6 = sábado (igual a extract(dow)).
create table public.janelas_entrega (
  id uuid primary key default gen_random_uuid(),
  central_id uuid not null references public.centrais (id) on delete cascade,
  dia_semana smallint not null check (dia_semana between 0 and 6),
  hora_inicio time not null,
  hora_fim time not null,
  capacidade integer not null check (capacidade between 1 and 500),
  ativa boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint janelas_entrega_horario_valido check (hora_inicio < hora_fim),
  constraint janelas_entrega_central_id_unico unique (central_id, id),
  constraint janelas_entrega_periodo_unico
    unique (central_id, dia_semana, hora_inicio, hora_fim)
);

-- Bloqueio de um dia inteiro (janela_id nulo) ou de um horário específico.
create table public.bloqueios_agenda (
  id uuid primary key default gen_random_uuid(),
  central_id uuid not null references public.centrais (id) on delete cascade,
  data date not null,
  janela_id uuid,
  motivo text not null check (char_length(btrim(motivo)) between 1 and 200),
  por_perfil_id uuid references public.perfis (id) on delete set null,
  criado_em timestamptz not null default now(),
  constraint bloqueios_agenda_janela_mesma_central
    foreign key (central_id, janela_id)
    references public.janelas_entrega (central_id, id)
    on delete cascade
);

-- ---------------------------------------------------------------------------
-- Endereços do cliente
-- ---------------------------------------------------------------------------

-- O endereço não fica preso a uma central: a central é escolhida pela distância
-- no momento do pedido, então abrir uma central nova já passa a atender os
-- endereços próximos a ela.
create table public.enderecos (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.perfis (id) on delete cascade,
  apelido text not null check (char_length(btrim(apelido)) between 1 and 40),
  cep text not null check (cep ~ '^[0-9]{8}$'),
  logradouro text not null check (char_length(btrim(logradouro)) between 1 and 120),
  numero text not null check (char_length(btrim(numero)) between 1 and 20),
  bairro text not null check (char_length(btrim(bairro)) between 1 and 80),
  cidade text not null check (char_length(btrim(cidade)) between 1 and 80),
  uf char(2) not null check (uf ~ '^[A-Z]{2}$'),
  complemento text check (complemento is null or char_length(complemento) <= 80),
  referencia text check (referencia is null or char_length(referencia) <= 120),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Pedidos
-- ---------------------------------------------------------------------------

-- Número único e global, para não mudar quando o pedido é transferido.
create sequence public.pedidos_numero_seq as bigint start with 1001;

create table public.pedidos (
  id uuid primary key default gen_random_uuid(),
  numero bigint not null unique default nextval('public.pedidos_numero_seq'),
  cliente_id uuid not null references public.perfis (id) on delete restrict,
  central_id uuid not null references public.centrais (id) on delete restrict,
  -- Cópias feitas no momento do pedido (a central vê só o necessário para entregar).
  cliente_nome text not null,
  cliente_telefone text not null,
  endereco_apelido text,
  cep_entrega text not null,
  logradouro_entrega text not null,
  numero_entrega text not null,
  bairro_entrega text not null,
  cidade_entrega text not null,
  uf_entrega char(2) not null,
  complemento_entrega text,
  referencia_entrega text,
  latitude_entrega double precision not null,
  longitude_entrega double precision not null,
  distancia_km numeric(7, 2) not null check (distancia_km >= 0),
  data_entrega date not null,
  janela_id uuid,
  hora_inicio time not null,
  hora_fim time not null,
  status public.status_pedido not null default 'novo',
  forma_pagamento public.forma_pagamento not null,
  troco_para_centavos integer not null default 0 check (troco_para_centavos >= 0),
  observacao text check (observacao is null or char_length(observacao) <= 500),
  subtotal_centavos integer not null check (subtotal_centavos >= 0),
  taxa_entrega_centavos integer not null check (taxa_entrega_centavos >= 0),
  total_centavos integer not null check (total_centavos >= 0),
  entregador_id uuid,
  motivo_cancelamento text check (
    motivo_cancelamento is null or char_length(motivo_cancelamento) <= 300
  ),
  transferencias smallint not null default 0 check (transferencias between 0 and 10),
  chave_idempotencia uuid not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  confirmado_em timestamptz,
  saiu_em timestamptz,
  entregue_em timestamptz,
  cancelado_em timestamptz,
  constraint pedidos_total_confere
    check (total_centavos = subtotal_centavos + taxa_entrega_centavos),
  constraint pedidos_horario_valido check (hora_inicio < hora_fim),
  constraint pedidos_chave_idempotencia_unica unique (cliente_id, chave_idempotencia),
  -- A janela, quando existe, é sempre da mesma central do pedido.
  constraint pedidos_janela_mesma_central
    foreign key (central_id, janela_id)
    references public.janelas_entrega (central_id, id)
    on update cascade
    on delete set null (janela_id),
  -- O entregador, quando existe, é sempre da mesma central do pedido.
  constraint pedidos_entregador_mesma_central
    foreign key (central_id, entregador_id)
    references public.entregadores (central_id, id)
    on delete set null (entregador_id)
);

create table public.itens_pedido (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.pedidos (id) on delete cascade,
  produto_id uuid not null references public.produtos (id) on delete restrict,
  produto_nome text not null,
  quantidade integer not null check (quantidade between 1 and 50),
  -- Copiado de precos_central pelo servidor; nunca vem do aplicativo.
  preco_unitario_centavos integer not null check (preco_unitario_centavos >= 0),
  troca_vasilhame boolean not null default false,
  constraint itens_pedido_produto_unico unique (pedido_id, produto_id)
);

create table public.historico_status (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.pedidos (id) on delete cascade,
  -- Central responsável no momento do evento.
  central_id uuid not null references public.centrais (id) on delete restrict,
  status public.status_pedido not null,
  evento public.evento_historico not null default 'status',
  observacao text check (observacao is null or char_length(observacao) <= 400),
  por_perfil_id uuid references public.perfis (id) on delete set null,
  criado_em timestamptz not null default now()
);

create table public.transferencias_pedido (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.pedidos (id) on delete cascade,
  de_central_id uuid not null references public.centrais (id) on delete restrict,
  para_central_id uuid not null references public.centrais (id) on delete restrict,
  motivo text not null check (char_length(btrim(motivo)) between 1 and 300),
  por_perfil_id uuid references public.perfis (id) on delete set null,
  criado_em timestamptz not null default now(),
  constraint transferencias_pedido_centrais_diferentes
    check (de_central_id <> para_central_id)
);

create table public.movimentos_estoque (
  id uuid primary key default gen_random_uuid(),
  central_id uuid not null references public.centrais (id) on delete cascade,
  produto_id uuid not null references public.produtos (id) on delete restrict,
  tipo public.tipo_movimento_estoque not null,
  delta_cheios integer not null default 0,
  delta_vazios integer not null default 0,
  cheios_apos integer not null,
  vazios_apos integer not null,
  motivo text not null check (char_length(btrim(motivo)) between 1 and 200),
  pedido_id uuid references public.pedidos (id) on delete set null,
  por_perfil_id uuid references public.perfis (id) on delete set null,
  criado_em timestamptz not null default now(),
  constraint movimentos_estoque_produto_na_central
    foreign key (central_id, produto_id)
    references public.estoque_central (central_id, produto_id)
    on delete cascade
);

-- ---------------------------------------------------------------------------
-- Notificações e auditoria
-- ---------------------------------------------------------------------------

create table public.dispositivos_push (
  id uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references public.perfis (id) on delete cascade,
  token text not null unique check (char_length(token) between 10 and 4096),
  plataforma text not null check (plataforma in ('android', 'ios', 'web')),
  atualizado_em timestamptz not null default now()
);

create table public.auditoria (
  id bigint generated always as identity primary key,
  central_id uuid references public.centrais (id) on delete set null,
  por_perfil_id uuid references public.perfis (id) on delete set null,
  acao text not null check (char_length(btrim(acao)) > 0),
  tabela text not null check (char_length(btrim(tabela)) > 0),
  registro_id text,
  antes jsonb,
  depois jsonb,
  criado_em timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Índices
-- ---------------------------------------------------------------------------

create index operadores_central_central_idx on public.operadores_central (central_id);
create index entregadores_central_idx on public.entregadores (central_id, ativo);
create index faixas_entrega_central_idx on public.faixas_entrega (central_id, ate_km);
create index centrais_ativa_idx on public.centrais (ativa);
create index precos_central_central_idx on public.precos_central (central_id);
create index precos_central_produto_idx on public.precos_central (produto_id);
create index estoque_central_produto_idx on public.estoque_central (produto_id);
create index janelas_entrega_central_dia_idx
  on public.janelas_entrega (central_id, dia_semana, ativa);
create index bloqueios_agenda_central_data_idx on public.bloqueios_agenda (central_id, data);
create index enderecos_cliente_idx on public.enderecos (cliente_id);
create index pedidos_central_status_criado_idx
  on public.pedidos (central_id, status, criado_em desc);
create index pedidos_cliente_criado_idx on public.pedidos (cliente_id, criado_em desc);
create index pedidos_janela_data_idx
  on public.pedidos (janela_id, data_entrega) where status <> 'cancelado';
create index pedidos_central_data_idx on public.pedidos (central_id, data_entrega);
create index pedidos_entregador_idx on public.pedidos (entregador_id);
create index itens_pedido_pedido_idx on public.itens_pedido (pedido_id);
create index itens_pedido_produto_idx on public.itens_pedido (produto_id);
create index historico_status_pedido_idx on public.historico_status (pedido_id, criado_em);
create index historico_status_central_idx on public.historico_status (central_id);
create index historico_status_perfil_idx on public.historico_status (por_perfil_id);
create index transferencias_pedido_pedido_idx on public.transferencias_pedido (pedido_id);
create index transferencias_pedido_de_idx on public.transferencias_pedido (de_central_id);
create index transferencias_pedido_para_idx on public.transferencias_pedido (para_central_id);
create index movimentos_estoque_central_produto_idx
  on public.movimentos_estoque (central_id, produto_id, criado_em desc);
create index movimentos_estoque_pedido_idx on public.movimentos_estoque (pedido_id);
create index movimentos_estoque_perfil_idx on public.movimentos_estoque (por_perfil_id);
create index dispositivos_push_perfil_idx on public.dispositivos_push (perfil_id);
create index auditoria_central_data_idx on public.auditoria (central_id, criado_em desc);
create index auditoria_data_idx on public.auditoria (criado_em desc);
create index auditoria_perfil_idx on public.auditoria (por_perfil_id);
create index bloqueios_agenda_perfil_idx on public.bloqueios_agenda (por_perfil_id);
create index bloqueios_agenda_central_janela_idx on public.bloqueios_agenda (central_id, janela_id);
create index pedidos_central_janela_idx on public.pedidos (central_id, janela_id);
create index pedidos_central_entregador_idx on public.pedidos (central_id, entregador_id);
create index movimentos_estoque_produto_idx on public.movimentos_estoque (produto_id);
create index transferencias_pedido_perfil_idx on public.transferencias_pedido (por_perfil_id);
