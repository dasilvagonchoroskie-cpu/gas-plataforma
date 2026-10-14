-- RASCUNHO DE FASE 1 — NÃO APLICAR À INTEGRAÇÃO OU A PRODUÇÃO.
-- Cópia de teste local somente após revisão e autorização.
-- Fonte de requisitos: docs/ARQUITETURA.md e decisões provisórias em docs/PASSAGEM.md.

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

-- Usuários autenticados. O cliente não recebe permissão para alterar papel.
create table public.perfis (
  id uuid primary key references auth.users(id) on delete restrict,
  nome text not null check (length(btrim(nome)) > 0),
  telefone text not null,
  papel public.papel_perfil not null default 'cliente',
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

-- A arquitetura descreve uma única revenda, portanto as centrais são o escopo operacional.
create table public.centrais (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (length(btrim(nome)) > 0),
  cidade text not null check (length(btrim(cidade)) > 0),
  uf char(2) not null check (uf = upper(uf)),
  ativa boolean not null default false,
  whatsapp text,
  endereco text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint centrais_id_id_unico unique (id)
);

-- Cada operador/entregador fica vinculado a uma única central.
create table public.operadores_central (
  perfil_id uuid primary key references public.perfis(id) on delete restrict,
  central_id uuid not null references public.centrais(id) on delete restrict,
  criado_em timestamptz not null default now(),
  constraint operadores_central_par_unico unique (central_id, perfil_id)
);

create table public.areas_entrega (
  id uuid primary key default gen_random_uuid(),
  central_id uuid not null references public.centrais(id) on delete restrict,
  bairro text not null check (length(btrim(bairro)) > 0),
  taxa_entrega_centavos bigint not null default 0 check (taxa_entrega_centavos >= 0),
  ativa boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint areas_entrega_central_id_unico unique (central_id, id),
  constraint areas_entrega_bairro_unico unique (central_id, bairro)
);

create table public.produtos (
  id uuid primary key default gen_random_uuid(),
  nome text not null check (length(btrim(nome)) > 0),
  categoria text not null check (categoria in ('gas', 'agua')),
  descricao text,
  foto_url text,
  troca_vasilhame boolean not null default false,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

-- Chave composta central/produto para que cada preço pertença ao produto daquela central.
create table public.precos_central (
  central_id uuid not null references public.centrais(id) on delete restrict,
  produto_id uuid not null references public.produtos(id) on delete restrict,
  preco_centavos bigint not null check (preco_centavos >= 0),
  disponivel boolean not null default true,
  atualizado_em timestamptz not null default now(),
  primary key (central_id, produto_id)
);

create table public.estoque_central (
  central_id uuid not null references public.centrais(id) on delete restrict,
  produto_id uuid not null references public.produtos(id) on delete restrict,
  cheios integer not null default 0 check (cheios >= 0),
  vazios integer not null default 0 check (vazios >= 0),
  alerta_minimo integer not null default 0 check (alerta_minimo >= 0),
  atualizado_em timestamptz not null default now(),
  primary key (central_id, produto_id)
);

create table public.janelas_entrega (
  id uuid primary key default gen_random_uuid(),
  central_id uuid not null references public.centrais(id) on delete restrict,
  dia_semana smallint not null check (dia_semana between 0 and 6),
  hora_inicio time not null,
  hora_fim time not null,
  capacidade integer not null check (capacidade > 0),
  ativa boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint janelas_entrega_horario_valido check (hora_inicio < hora_fim),
  constraint janelas_entrega_central_id_unico unique (central_id, id),
  constraint janelas_entrega_periodo_unico unique (central_id, dia_semana, hora_inicio, hora_fim)
);

create table public.bloqueios_agenda (
  id uuid primary key default gen_random_uuid(),
  central_id uuid not null references public.centrais(id) on delete restrict,
  data date not null,
  janela_id uuid,
  motivo text not null check (length(btrim(motivo)) > 0),
  criado_em timestamptz not null default now(),
  constraint bloqueios_agenda_central_id_unico unique (central_id, id),
  constraint bloqueios_agenda_janela_mesma_central
    foreign key (central_id, janela_id)
    references public.janelas_entrega (central_id, id)
    on delete restrict
);

create table public.enderecos (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.perfis(id) on delete restrict,
  central_id uuid not null references public.centrais(id) on delete restrict,
  apelido text not null check (length(btrim(apelido)) > 0),
  cep text not null,
  logradouro text not null,
  numero text not null,
  bairro text not null,
  cidade text not null,
  complemento text,
  referencia text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint enderecos_central_id_unico unique (central_id, id)
);

create table public.pedidos (
  id uuid primary key default gen_random_uuid(),
  numero bigint not null check (numero > 0),
  cliente_id uuid not null references public.perfis(id) on delete restrict,
  central_id uuid not null references public.centrais(id) on delete restrict,
  endereco_apelido text,
  cep_entrega text not null,
  logradouro_entrega text not null,
  numero_entrega text not null,
  bairro_entrega text not null,
  cidade_entrega text not null,
  complemento_entrega text,
  referencia_entrega text,
  data_entrega date not null,
  janela_id uuid not null,
  status public.status_pedido not null default 'novo',
  forma_pagamento public.forma_pagamento not null,
  troco_para_centavos bigint not null default 0 check (troco_para_centavos >= 0),
  observacao text,
  subtotal_centavos bigint not null check (subtotal_centavos >= 0),
  taxa_entrega_centavos bigint not null check (taxa_entrega_centavos >= 0),
  total_centavos bigint not null check (total_centavos >= 0),
  entregador_id uuid,
  motivo_cancelamento text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint pedidos_central_id_unico unique (central_id, id),
  constraint pedidos_numero_por_central_unico unique (central_id, numero),
  constraint pedidos_janela_mesma_central
    foreign key (central_id, janela_id)
    references public.janelas_entrega (central_id, id)
    on delete restrict,
  constraint pedidos_entregador_mesma_central
    foreign key (central_id, entregador_id)
    references public.operadores_central (central_id, perfil_id)
    on delete restrict
);

-- central_id é repetido nos itens para permitir FKs compostas e impedir mistura de centrais.
create table public.itens_pedido (
  id uuid primary key default gen_random_uuid(),
  central_id uuid not null,
  pedido_id uuid not null,
  produto_id uuid not null,
  quantidade integer not null check (quantidade > 0),
  preco_unitario_centavos bigint not null check (preco_unitario_centavos >= 0),
  constraint itens_pedido_central_id_unico unique (central_id, id),
  constraint itens_pedido_mesmo_pedido
    foreign key (central_id, pedido_id)
    references public.pedidos (central_id, id)
    on delete restrict,
  constraint itens_pedido_produto_ofertado_na_central
    foreign key (central_id, produto_id)
    references public.precos_central (central_id, produto_id)
    on delete restrict,
  constraint itens_pedido_produto_unico unique (central_id, pedido_id, produto_id)
);

-- central_id é repetido para manter o histórico vinculado à mesma central do pedido.
create table public.historico_status (
  id uuid primary key default gen_random_uuid(),
  central_id uuid not null,
  pedido_id uuid not null,
  status public.status_pedido not null,
  por_perfil_id uuid not null references public.perfis(id) on delete restrict,
  criado_em timestamptz not null default now(),
  constraint historico_status_central_id_unico unique (central_id, id),
  constraint historico_status_mesmo_pedido
    foreign key (central_id, pedido_id)
    references public.pedidos (central_id, id)
    on delete restrict
);

create table public.movimentos_estoque (
  id uuid primary key default gen_random_uuid(),
  central_id uuid not null,
  produto_id uuid not null,
  tipo text not null,
  quantidade integer not null check (quantidade > 0),
  motivo text not null check (length(btrim(motivo)) > 0),
  pedido_id uuid,
  por_perfil_id uuid not null references public.perfis(id) on delete restrict,
  criado_em timestamptz not null default now(),
  constraint movimentos_estoque_central_id_unico unique (central_id, id),
  constraint movimentos_estoque_produto_na_central
    foreign key (central_id, produto_id)
    references public.estoque_central (central_id, produto_id)
    on delete restrict,
  constraint movimentos_estoque_pedido_mesma_central
    foreign key (central_id, pedido_id)
    references public.pedidos (central_id, id)
    on delete restrict
);

create table public.dispositivos_push (
  id uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references public.perfis(id) on delete cascade,
  token text not null unique,
  plataforma text not null check (plataforma in ('android', 'ios')),
  atualizado_em timestamptz not null default now()
);

-- registro_id é polimórfico conforme o modelo; central_id permite escopo de leitura por central.
-- A relação polimórfica com o registro-alvo não admite FK relacional única.
create table public.auditoria (
  id uuid primary key default gen_random_uuid(),
  central_id uuid references public.centrais(id) on delete restrict,
  por_perfil_id uuid not null references public.perfis(id) on delete restrict,
  acao text not null check (length(btrim(acao)) > 0),
  tabela text not null check (length(btrim(tabela)) > 0),
  registro_id uuid,
  antes jsonb,
  depois jsonb,
  criado_em timestamptz not null default now()
);

-- Funções auxiliares usadas pelas políticas. SECURITY DEFINER evita recursão de RLS:
-- elas consultam as tabelas-base sob o proprietário da função e usam auth.uid() como identidade.
create or replace function public.eh_dono()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.perfis as p
    where p.id = auth.uid()
      and p.papel = 'dono'::public.papel_perfil
  );
$$;

create or replace function public.central_do_operador()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select oc.central_id
  from public.operadores_central as oc
  join public.perfis as p on p.id = oc.perfil_id
  where oc.perfil_id = auth.uid()
    and p.papel = 'operador_central'::public.papel_perfil
  limit 1;
$$;

create or replace function public.pode_acessar_central(p_central_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    p_central_id is not null
    and (public.eh_dono() or public.central_do_operador() = p_central_id),
    false
  );
$$;

-- Trigger comum para manter atualizado_em no servidor, nunca pelo cliente.
create or replace function public.tg_atualizar_em()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;

-- A associação operador/entregador não pode ser criada para papéis incompatíveis.
create or replace function public.tg_validar_vinculo_central()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.perfis as p
    where p.id = new.perfil_id
      and p.papel in (
        'operador_central'::public.papel_perfil,
        'entregador'::public.papel_perfil
      )
  ) then
    raise exception 'O perfil precisa ser operador de central ou entregador.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

-- A FK composta valida central; este trigger também valida que o perfil é entregador.
create or replace function public.tg_validar_entregador_pedido()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.entregador_id is not null and not exists (
    select 1
    from public.operadores_central as oc
    join public.perfis as p on p.id = oc.perfil_id
    where oc.central_id = new.central_id
      and oc.perfil_id = new.entregador_id
      and p.papel = 'entregador'::public.papel_perfil
  ) then
    raise exception 'O entregador precisa estar vinculado à mesma central do pedido.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

-- O cliente só alcança pedidos novos pela política RLS. Cancelamento posterior
-- exige motivo; a política permite essa operação somente a dono/operador da central.
create or replace function public.tg_validar_motivo_cancelamento()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'cancelado'::public.status_pedido
     and old.status <> 'cancelado'::public.status_pedido
     and old.status <> 'novo'::public.status_pedido
     and nullif(btrim(new.motivo_cancelamento), '') is null then
    raise exception 'Cancelamento após o primeiro status exige motivo.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger perfis_atualizado_em
before update on public.perfis
for each row execute function public.tg_atualizar_em();
create trigger centrais_atualizado_em
before update on public.centrais
for each row execute function public.tg_atualizar_em();
create trigger areas_entrega_atualizado_em
before update on public.areas_entrega
for each row execute function public.tg_atualizar_em();
create trigger produtos_atualizado_em
before update on public.produtos
for each row execute function public.tg_atualizar_em();
create trigger precos_central_atualizado_em
before update on public.precos_central
for each row execute function public.tg_atualizar_em();
create trigger estoque_central_atualizado_em
before update on public.estoque_central
for each row execute function public.tg_atualizar_em();
create trigger janelas_entrega_atualizado_em
before update on public.janelas_entrega
for each row execute function public.tg_atualizar_em();
create trigger enderecos_atualizado_em
before update on public.enderecos
for each row execute function public.tg_atualizar_em();
create trigger pedidos_atualizado_em
before update on public.pedidos
for each row execute function public.tg_atualizar_em();
create trigger dispositivos_push_atualizado_em
before update on public.dispositivos_push
for each row execute function public.tg_atualizar_em();

create trigger operadores_central_validar_perfil
before insert or update of perfil_id, central_id on public.operadores_central
for each row execute function public.tg_validar_vinculo_central();
create trigger pedidos_validar_entregador
before insert or update of central_id, entregador_id on public.pedidos
for each row execute function public.tg_validar_entregador_pedido();
create trigger pedidos_validar_motivo_cancelamento
before update of status, motivo_cancelamento on public.pedidos
for each row execute function public.tg_validar_motivo_cancelamento();

-- Privilégios explícitos: sem acesso anônimo; RLS continua sendo a autoridade por linha.
revoke all on all tables in schema public from anon, authenticated;
grant usage on schema public to authenticated;
grant select on
  public.perfis,
  public.centrais,
  public.operadores_central,
  public.areas_entrega,
  public.produtos,
  public.precos_central,
  public.estoque_central,
  public.janelas_entrega,
  public.bloqueios_agenda,
  public.enderecos,
  public.pedidos,
  public.itens_pedido,
  public.historico_status,
  public.movimentos_estoque,
  public.dispositivos_push,
  public.auditoria
  to authenticated;

-- O próprio perfil pode alterar apenas nome e telefone; nunca papel ou vínculo central.
grant update (nome, telefone) on public.perfis to authenticated;
grant insert, update on public.centrais to authenticated;
grant insert, update, delete on public.operadores_central to authenticated;
grant insert, update on public.areas_entrega to authenticated;
grant insert, update on public.produtos to authenticated;
grant insert, update on public.precos_central to authenticated;
grant insert, update on public.estoque_central to authenticated;
grant insert on public.movimentos_estoque to authenticated;
grant insert, update on public.janelas_entrega to authenticated;
grant insert, update, delete on public.bloqueios_agenda to authenticated;
grant insert, update, delete on public.enderecos to authenticated;
-- Não há UPDATE direto em pedidos nesta etapa. Futuras mudanças passam pelo RPC
-- mudar_status_pedido, que ainda é somente uma assinatura comentada.
grant insert, update, delete on public.dispositivos_push to authenticated;

-- RLS em todas as tabelas, sem política para uma operação significa negação.
alter table public.perfis enable row level security;
alter table public.centrais enable row level security;
alter table public.operadores_central enable row level security;
alter table public.areas_entrega enable row level security;
alter table public.produtos enable row level security;
alter table public.precos_central enable row level security;
alter table public.estoque_central enable row level security;
alter table public.janelas_entrega enable row level security;
alter table public.bloqueios_agenda enable row level security;
alter table public.enderecos enable row level security;
alter table public.pedidos enable row level security;
alter table public.itens_pedido enable row level security;
alter table public.historico_status enable row level security;
alter table public.movimentos_estoque enable row level security;
alter table public.dispositivos_push enable row level security;
alter table public.auditoria enable row level security;

-- Perfis: cada pessoa lê o próprio perfil; o dono pode ler todos. Papel é imutável
-- por grants, e a tabela não tem central_id mutável pelo usuário.
create policy perfis_ler on public.perfis
for select to authenticated
using (id = auth.uid() or public.eh_dono());
create policy perfis_atualizar_proprio on public.perfis
for update to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- Centrais ativas são visíveis somente a usuários autenticados; dono administra todas.
create policy centrais_ler on public.centrais
for select to authenticated
using (ativa or public.eh_dono() or public.pode_acessar_central(id));
create policy centrais_inserir_dono on public.centrais
for insert to authenticated
with check (public.eh_dono());
create policy centrais_atualizar_dono on public.centrais
for update to authenticated
using (public.eh_dono())
with check (public.eh_dono());

-- Atribuições são privadas: operador consulta só a própria, dono consulta/administra todas.
create policy operadores_central_ler on public.operadores_central
for select to authenticated
using (perfil_id = auth.uid() or public.eh_dono());
create policy operadores_central_inserir_dono on public.operadores_central
for insert to authenticated
with check (public.eh_dono());
create policy operadores_central_atualizar_dono on public.operadores_central
for update to authenticated
using (public.eh_dono())
with check (public.eh_dono());
create policy operadores_central_excluir_dono on public.operadores_central
for delete to authenticated
using (public.eh_dono());

-- Áreas: clientes autenticados consultam áreas ativas; o dono administra.
create policy areas_entrega_ler on public.areas_entrega
for select to authenticated
using (ativa or public.eh_dono() or public.pode_acessar_central(central_id));
create policy areas_entrega_inserir_dono on public.areas_entrega
for insert to authenticated
with check (public.eh_dono());
create policy areas_entrega_atualizar_dono on public.areas_entrega
for update to authenticated
using (public.eh_dono())
with check (public.eh_dono());

-- Catálogo autenticado. Anon não recebe privilégio nem política de leitura.
create policy produtos_ler_catalogo on public.produtos
for select to authenticated
using (ativo or public.eh_dono());
create policy produtos_inserir_dono on public.produtos
for insert to authenticated
with check (public.eh_dono());
create policy produtos_atualizar_dono on public.produtos
for update to authenticated
using (public.eh_dono())
with check (public.eh_dono());

create policy precos_central_ler on public.precos_central
for select to authenticated
using (
  public.eh_dono()
  or public.pode_acessar_central(central_id)
  or (
    disponivel
    and exists (
      select 1 from public.centrais as c
      where c.id = central_id and c.ativa
    )
  )
);
create policy precos_central_inserir_dono on public.precos_central
for insert to authenticated
with check (public.eh_dono());
create policy precos_central_atualizar_dono on public.precos_central
for update to authenticated
using (public.eh_dono())
with check (public.eh_dono());

create policy estoque_central_ler_operacao on public.estoque_central
for select to authenticated
using (public.eh_dono() or public.pode_acessar_central(central_id));
create policy estoque_central_inserir_operacao on public.estoque_central
for insert to authenticated
with check (public.pode_acessar_central(central_id));
create policy estoque_central_atualizar_operacao on public.estoque_central
for update to authenticated
using (public.pode_acessar_central(central_id))
with check (public.pode_acessar_central(central_id));

create policy janelas_entrega_ler on public.janelas_entrega
for select to authenticated
using (ativa or public.pode_acessar_central(central_id));
create policy janelas_entrega_inserir_operacao on public.janelas_entrega
for insert to authenticated
with check (public.pode_acessar_central(central_id));
create policy janelas_entrega_atualizar_operacao on public.janelas_entrega
for update to authenticated
using (public.pode_acessar_central(central_id))
with check (public.pode_acessar_central(central_id));

create policy bloqueios_agenda_ler_operacao on public.bloqueios_agenda
for select to authenticated
using (public.pode_acessar_central(central_id));
create policy bloqueios_agenda_inserir_operacao on public.bloqueios_agenda
for insert to authenticated
with check (public.pode_acessar_central(central_id));
create policy bloqueios_agenda_atualizar_operacao on public.bloqueios_agenda
for update to authenticated
using (public.pode_acessar_central(central_id))
with check (public.pode_acessar_central(central_id));
create policy bloqueios_agenda_excluir_operacao on public.bloqueios_agenda
for delete to authenticated
using (public.pode_acessar_central(central_id));

-- Cliente administra apenas os próprios endereços; dono vê todos. Operador recebe
-- o endereço copiado apenas dentro do pedido da própria central.
create policy enderecos_ler on public.enderecos
for select to authenticated
using (cliente_id = auth.uid() or public.eh_dono());
create policy enderecos_inserir_proprio on public.enderecos
for insert to authenticated
with check (cliente_id = auth.uid());
create policy enderecos_atualizar_proprio on public.enderecos
for update to authenticated
using (cliente_id = auth.uid() or public.eh_dono())
with check (cliente_id = auth.uid() or public.eh_dono());
create policy enderecos_excluir_proprio on public.enderecos
for delete to authenticated
using (cliente_id = auth.uid() or public.eh_dono());

-- Leitura: cliente próprio, operador da central e dono. Pedido é criado pelo RPC,
-- nunca com preço ou total confiados ao aplicativo.
create policy pedidos_ler_autorizados on public.pedidos
for select to authenticated
using (
  cliente_id = auth.uid()
  or public.pode_acessar_central(central_id)
);
create policy pedidos_cancelar_cliente_novo on public.pedidos
for update to authenticated
using (cliente_id = auth.uid() and status = 'novo'::public.status_pedido)
with check (
  cliente_id = auth.uid()
  and status in ('novo'::public.status_pedido, 'cancelado'::public.status_pedido)
);
create policy pedidos_atualizar_operacao on public.pedidos
for update to authenticated
using (public.pode_acessar_central(central_id))
with check (public.pode_acessar_central(central_id));

-- Itens e histórico seguem o acesso ao pedido pai e a central gravada na linha.
create policy itens_pedido_ler_autorizados on public.itens_pedido
for select to authenticated
using (
  exists (
    select 1 from public.pedidos as p
    where p.id = pedido_id
      and p.central_id = itens_pedido.central_id
      and (p.cliente_id = auth.uid() or public.pode_acessar_central(p.central_id))
  )
);
create policy historico_status_ler_autorizados on public.historico_status
for select to authenticated
using (
  exists (
    select 1 from public.pedidos as p
    where p.id = pedido_id
      and p.central_id = historico_status.central_id
      and (p.cliente_id = auth.uid() or public.pode_acessar_central(p.central_id))
  )
);

create policy movimentos_estoque_ler_operacao on public.movimentos_estoque
for select to authenticated
using (public.pode_acessar_central(central_id));
create policy movimentos_estoque_inserir_operacao on public.movimentos_estoque
for insert to authenticated
with check (
  public.pode_acessar_central(central_id)
  and (public.eh_dono() or por_perfil_id = auth.uid())
);

-- Tokens de push são privados para o próprio perfil.
create policy dispositivos_push_ler_proprio on public.dispositivos_push
for select to authenticated
using (perfil_id = auth.uid());
create policy dispositivos_push_inserir_proprio on public.dispositivos_push
for insert to authenticated
with check (perfil_id = auth.uid());
create policy dispositivos_push_atualizar_proprio on public.dispositivos_push
for update to authenticated
using (perfil_id = auth.uid())
with check (perfil_id = auth.uid());
create policy dispositivos_push_excluir_proprio on public.dispositivos_push
for delete to authenticated
using (perfil_id = auth.uid());

create policy auditoria_ler_autorizada on public.auditoria
for select to authenticated
using (public.eh_dono() or public.pode_acessar_central(central_id));

-- A view respeita as RLS das tabelas subjacentes do usuário chamador.
create view public.v_pedidos_com_itens
with (security_invoker = true)
as
select
  p.id,
  p.numero,
  p.cliente_id,
  p.central_id,
  p.status,
  p.data_entrega,
  p.janela_id,
  p.forma_pagamento,
  p.subtotal_centavos,
  p.taxa_entrega_centavos,
  p.total_centavos,
  p.cep_entrega,
  p.logradouro_entrega,
  p.numero_entrega,
  p.bairro_entrega,
  p.cidade_entrega,
  p.complemento_entrega,
  p.referencia_entrega,
  coalesce(
    jsonb_agg(
      jsonb_build_object(
        'produto_id', i.produto_id,
        'quantidade', i.quantidade,
        'preco_unitario_centavos', i.preco_unitario_centavos
      ) order by i.id
    ) filter (where i.id is not null),
    '[]'::jsonb
  ) as itens
from public.pedidos as p
left join public.itens_pedido as i
  on i.central_id = p.central_id and i.pedido_id = p.id
group by p.id;

grant select on public.v_pedidos_com_itens to authenticated;

-- Índices de FKs e filtros operacionais (além das PKs e UNIQUEs compostas).
create index operadores_central_central_idx on public.operadores_central (central_id);
create index areas_entrega_central_ativa_idx on public.areas_entrega (central_id, ativa);
create index precos_central_produto_idx on public.precos_central (produto_id);
create index estoque_central_produto_idx on public.estoque_central (produto_id);
create index janelas_entrega_central_ativa_dia_idx on public.janelas_entrega (central_id, ativa, dia_semana);
create index bloqueios_agenda_central_data_idx on public.bloqueios_agenda (central_id, data);
create index bloqueios_agenda_central_janela_idx on public.bloqueios_agenda (central_id, janela_id);
create index enderecos_cliente_idx on public.enderecos (cliente_id);
create index enderecos_central_idx on public.enderecos (central_id);
create index pedidos_cliente_criado_idx on public.pedidos (cliente_id, criado_em desc);
create index pedidos_central_status_criado_idx on public.pedidos (central_id, status, criado_em desc);
create index pedidos_central_janela_idx on public.pedidos (central_id, janela_id);
create index pedidos_central_entregador_idx on public.pedidos (central_id, entregador_id);
create index itens_pedido_central_pedido_idx on public.itens_pedido (central_id, pedido_id);
create index itens_pedido_central_produto_idx on public.itens_pedido (central_id, produto_id);
create index historico_status_central_pedido_data_idx on public.historico_status (central_id, pedido_id, criado_em desc);
create index historico_status_perfil_idx on public.historico_status (por_perfil_id);
create index movimentos_estoque_central_produto_data_idx on public.movimentos_estoque (central_id, produto_id, criado_em desc);
create index movimentos_estoque_central_pedido_idx on public.movimentos_estoque (central_id, pedido_id);
create index movimentos_estoque_perfil_idx on public.movimentos_estoque (por_perfil_id);
create index dispositivos_push_perfil_idx on public.dispositivos_push (perfil_id);
create index auditoria_central_data_idx on public.auditoria (central_id, criado_em desc);
create index auditoria_perfil_idx on public.auditoria (por_perfil_id);
create index auditoria_tabela_registro_idx on public.auditoria (tabela, registro_id);

-- Helpers invocáveis apenas por authenticated. Não há permissão para anon.
revoke all on function public.eh_dono() from public, anon;
revoke all on function public.central_do_operador() from public, anon;
revoke all on function public.pode_acessar_central(uuid) from public, anon;
revoke all on function public.tg_atualizar_em() from public, anon, authenticated;
revoke all on function public.tg_validar_vinculo_central() from public, anon, authenticated;
revoke all on function public.tg_validar_entregador_pedido() from public, anon, authenticated;
revoke all on function public.tg_validar_motivo_cancelamento() from public, anon, authenticated;
grant execute on function public.eh_dono() to authenticated;
grant execute on function public.central_do_operador() to authenticated;
grant execute on function public.pode_acessar_central(uuid) to authenticated;

-- Funções de negócio: somente assinaturas conceituais e comentários nesta etapa.
-- PostgreSQL não permite criar uma função executável sem corpo; por isso estas
-- assinaturas ficam comentadas e não são stubs nem operações executáveis.
/*
Assinatura proposta:
public.criar_pedido(
  p_central_id uuid,
  p_endereco_id uuid,
  p_janela_id uuid,
  p_data_entrega date,
  p_forma_pagamento public.forma_pagamento,
  p_troco_para_centavos bigint,
  p_observacao text,
  p_itens jsonb -- apenas produto_id e quantidade; nunca preço nem total
) returns uuid;

Deve validar central ativa, área atendida, janela/capacidade e produtos disponíveis;
ler os preços vigentes de public.precos_central no servidor; calcular subtotais,
taxa e total; gravar o pedido, itens e histórico atomicamente; usar bloqueio para
impedir que duas solicitações ocupem a última vaga. O preço unitário em
public.itens_pedido.preco_unitario_centavos é uma cópia do banco, nunca do app.

Assinatura proposta:
public.janelas_disponiveis(p_central_id uuid, p_data date)
returns table (janela_id uuid, hora_inicio time, hora_fim time, vagas_disponiveis integer);

Deve listar apenas janelas ativas, sem bloqueio e com capacidade restante para a
central e data informadas, sem expor dados privados.

Assinatura proposta:
public.mudar_status_pedido(
  p_pedido_id uuid,
  p_novo_status public.status_pedido,
  p_motivo text default null
) returns void;

Deve validar o papel e a central do chamador, permitir somente transições válidas,
exigir motivo em cancelamento após o primeiro status, registrar histórico e, ao
entregar, atualizar estoque de forma consistente.

Assinatura proposta:
public.criar_central(
  p_nome text,
  p_cidade text,
  p_uf char(2),
  p_whatsapp text,
  p_endereco text,
  p_central_modelo_id uuid,
  p_primeiro_operador_id uuid
) returns uuid;

Deve ser exclusiva do dono; criar a central; copiar preços e janelas da central
modelo; vincular o primeiro operador; validar os dados e auditar a operação.
*/

comment on column public.itens_pedido.preco_unitario_centavos is
  'Preço copiado pelo servidor de precos_central no momento do pedido; nunca aceito do aplicativo.';
comment on column public.pedidos.motivo_cancelamento is
  'Motivo obrigatório em cancelamentos por dono/central após o status novo.';
comment on column public.auditoria.registro_id is
  'Identificador polimórfico conforme tabela; não substitui FK relacional.';
