-- Ficha de cadastro do cliente e crediário (fiado com limite).
--
-- Regras (pedido do Evandro em 16/10/2026):
-- * Todo cliente preenche a ficha antes do primeiro pedido.
-- * Quem aprova é o dono. Ele pode liberar, nas configurações, que as centrais
--   aprovem as fichas dos clientes delas, com um limite máximo opcional.
-- * Cliente aprovado pode pagar no crediário, se o pedido couber no limite
--   livre (limite − o que já deve − pedidos fiado ainda não entregues).
-- * Ao entregar um pedido fiado, o valor entra na conta do cliente. O dono e as
--   centrais registram os pagamentos.
-- * CPF, RG, renda e fotos só são vistos pelo próprio cliente, pelo dono e,
--   quando liberado, pela central que analisa a ficha.

-- ---------------------------------------------------------------------------
-- Tipos
-- ---------------------------------------------------------------------------

create type public.status_ficha as enum ('pendente', 'aprovada', 'recusada');
create type public.tipo_lancamento as enum ('compra', 'pagamento', 'ajuste');

-- ---------------------------------------------------------------------------
-- Funções simples
-- ---------------------------------------------------------------------------

-- Confere os dígitos verificadores do CPF (11 dígitos, sem pontuação).
create or replace function public.cpf_valido(p_cpf text)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_soma integer;
  v_digito integer;
  i integer;
begin
  if p_cpf is null or p_cpf !~ '^[0-9]{11}$' or p_cpf ~ '^(.)\1{10}$' then
    return false;
  end if;
  v_soma := 0;
  for i in 1..9 loop
    v_soma := v_soma + substr(p_cpf, i, 1)::integer * (11 - i);
  end loop;
  v_digito := (v_soma * 10) % 11;
  if v_digito = 10 then v_digito := 0; end if;
  if v_digito <> substr(p_cpf, 10, 1)::integer then
    return false;
  end if;
  v_soma := 0;
  for i in 1..10 loop
    v_soma := v_soma + substr(p_cpf, i, 1)::integer * (12 - i);
  end loop;
  v_digito := (v_soma * 10) % 11;
  if v_digito = 10 then v_digito := 0; end if;
  return v_digito = substr(p_cpf, 11, 1)::integer;
end;
$$;

-- 12345 → "R$ 123,45" (para mensagens).
create or replace function public.formatar_reais(p_centavos bigint)
returns text
language sql
immutable
set search_path = ''
as $$
  select case when p_centavos < 0 then '-' else '' end
    || 'R$ '
    || replace(to_char(abs(p_centavos) / 100, 'FM999,999,990'), ',', '.')
    || ','
    || lpad((abs(p_centavos) % 100)::text, 2, '0');
$$;

-- ---------------------------------------------------------------------------
-- Tabelas
-- ---------------------------------------------------------------------------

-- Configurações gerais da revenda (uma linha só).
create table public.configuracoes (
  id boolean primary key default true check (id),
  centrais_aprovam_credito boolean not null default false,
  -- Maior limite que uma central pode liberar. Nulo: sem teto.
  limite_maximo_central_centavos integer
    check (limite_maximo_central_centavos is null
           or limite_maximo_central_centavos between 0 and 100000000),
  atualizado_em timestamptz not null default now()
);
insert into public.configuracoes default values;

comment on table public.configuracoes is
  'Configurações da revenda. Só o dono altera.';

create table public.fichas_cliente (
  cliente_id uuid primary key,
  cpf text not null check (public.cpf_valido(cpf)),
  rg text not null check (char_length(btrim(rg)) between 3 and 20),
  data_nascimento date not null,
  nome_mae text not null check (char_length(btrim(nome_mae)) between 3 and 80),
  -- Endereço de moradia (um dos endereços do cliente) e a central que atende ele.
  endereco_id uuid,
  central_id uuid,
  empresa text not null check (char_length(btrim(empresa)) between 2 and 80),
  profissao text not null check (char_length(btrim(profissao)) between 2 and 60),
  telefone_trabalho text not null default '' check (telefone_trabalho ~ '^[0-9]{0,11}$'),
  renda_mensal_centavos integer not null check (renda_mensal_centavos between 0 and 100000000),
  referencia1_nome text not null check (char_length(btrim(referencia1_nome)) between 3 and 80),
  referencia1_telefone text not null check (referencia1_telefone ~ '^[0-9]{10,11}$'),
  referencia1_relacao text not null check (char_length(btrim(referencia1_relacao)) between 2 and 40),
  referencia2_nome text not null check (char_length(btrim(referencia2_nome)) between 3 and 80),
  referencia2_telefone text not null check (referencia2_telefone ~ '^[0-9]{10,11}$'),
  referencia2_relacao text not null check (char_length(btrim(referencia2_relacao)) between 2 and 40),
  -- Caminho das fotos no Storage (bucket privado "fichas").
  documento_caminho text not null check (char_length(documento_caminho) between 5 and 300),
  comprovante_caminho text not null check (char_length(comprovante_caminho) between 5 and 300),
  status public.status_ficha not null default 'pendente',
  limite_centavos integer not null default 0 check (limite_centavos between 0 and 100000000),
  credito_bloqueado boolean not null default false,
  motivo text check (motivo is null or char_length(motivo) <= 300),
  analisado_por uuid,
  analisado_em timestamptz,
  enviado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint fichas_cliente_cliente_fkey foreign key (cliente_id)
    references public.perfis (id) on delete cascade,
  constraint fichas_cliente_endereco_fkey foreign key (endereco_id)
    references public.enderecos (id) on delete set null,
  constraint fichas_cliente_central_fkey foreign key (central_id)
    references public.centrais (id) on delete set null,
  constraint fichas_cliente_analisado_por_fkey foreign key (analisado_por)
    references public.perfis (id) on delete set null,
  constraint fichas_cliente_cpf_unico unique (cpf)
);

comment on table public.fichas_cliente is
  'Ficha de cadastro (crediário). Dados sensíveis: só o cliente, o dono e a central que analisa.';

create table public.lancamentos_credito (
  id uuid primary key default gen_random_uuid(),
  cliente_id uuid not null references public.perfis (id) on delete restrict,
  central_id uuid references public.centrais (id) on delete set null,
  pedido_id uuid unique references public.pedidos (id) on delete set null,
  tipo public.tipo_lancamento not null,
  -- Positivo aumenta a dívida (compra); negativo diminui (pagamento).
  valor_centavos integer not null
    check (valor_centavos <> 0 and abs(valor_centavos) <= 100000000),
  forma public.forma_pagamento
    check (forma is null or forma <> 'crediario'::public.forma_pagamento),
  observacao text check (observacao is null or char_length(observacao) <= 300),
  por_perfil_id uuid references public.perfis (id) on delete set null,
  criado_em timestamptz not null default now(),
  check (
    (tipo = 'compra' and valor_centavos > 0 and pedido_id is not null)
    or (tipo = 'pagamento' and valor_centavos < 0 and forma is not null)
    or (tipo = 'ajuste' and observacao is not null)
  )
);

comment on table public.lancamentos_credito is
  'Conta do crediário: compras fiado entregues, pagamentos e ajustes.';

create index fichas_cliente_status_idx on public.fichas_cliente (status, enviado_em);
create index fichas_cliente_central_idx on public.fichas_cliente (central_id);
create index fichas_cliente_endereco_idx on public.fichas_cliente (endereco_id);
create index fichas_cliente_analisado_por_idx on public.fichas_cliente (analisado_por);
create index lancamentos_credito_cliente_idx on public.lancamentos_credito (cliente_id, criado_em);
create index lancamentos_credito_central_idx on public.lancamentos_credito (central_id);
create index lancamentos_credito_perfil_idx on public.lancamentos_credito (por_perfil_id);

create trigger configuracoes_atualizado_em before update on public.configuracoes
for each row execute function public.tg_atualizado_em();
create trigger fichas_cliente_atualizado_em before update on public.fichas_cliente
for each row execute function public.tg_atualizado_em();
create trigger auditar_configuracoes after insert or update on public.configuracoes
for each row execute function public.tg_auditar();

-- ---------------------------------------------------------------------------
-- Funções de permissão e de saldo
-- ---------------------------------------------------------------------------

create or replace function public.centrais_aprovam_credito()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select c.centrais_aprovam_credito from public.configuracoes as c where c.id), false);
$$;

-- O usuário logado pode ver o crediário deste cliente? (o próprio cliente, o
-- dono, ou a central da ficha / onde o cliente já pediu)
create or replace function public.pode_ver_cliente(p_cliente_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    p_cliente_id is not null and (
      p_cliente_id = auth.uid()
      or public.eh_dono()
      or (
        public.central_do_operador() is not null
        and (
          exists (
            select 1 from public.fichas_cliente as f
            where f.cliente_id = p_cliente_id and f.central_id = public.central_do_operador()
          )
          or exists (
            select 1 from public.pedidos as p
            where p.cliente_id = p_cliente_id and p.central_id = public.central_do_operador()
          )
        )
      )
    ),
    false
  );
$$;

-- O usuário logado pode aprovar/recusar a ficha deste cliente?
create or replace function public.pode_analisar_ficha(p_cliente_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    public.eh_dono()
    or (
      public.centrais_aprovam_credito()
      and exists (
        select 1 from public.fichas_cliente as f
        where f.cliente_id = p_cliente_id
          and f.central_id is not null
          and f.central_id = public.central_do_operador()
      )
    ),
    false
  );
$$;

-- Situação do crediário (uso interno das funções abaixo).
create or replace function public.situacao_credito(p_cliente_id uuid)
returns table (
  status public.status_ficha,
  bloqueado boolean,
  limite_centavos bigint,
  devido_centavos bigint,
  reservado_centavos bigint,
  disponivel_centavos bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  with ficha as (
    select f.status, f.credito_bloqueado, f.limite_centavos
    from public.fichas_cliente as f
    where f.cliente_id = p_cliente_id
  ),
  devido as (
    select coalesce(sum(l.valor_centavos), 0)::bigint as valor
    from public.lancamentos_credito as l
    where l.cliente_id = p_cliente_id
  ),
  reservado as (
    select coalesce(sum(p.total_centavos), 0)::bigint as valor
    from public.pedidos as p
    where p.cliente_id = p_cliente_id
      and p.forma_pagamento = 'crediario'::public.forma_pagamento
      and p.status in ('novo', 'confirmado', 'em_rota')
  )
  select
    (select ficha.status from ficha),
    coalesce((select ficha.credito_bloqueado from ficha), false),
    coalesce((select ficha.limite_centavos from ficha), 0)::bigint,
    devido.valor,
    reservado.valor,
    case
      when (select ficha.status from ficha) = 'aprovada'
       and not coalesce((select ficha.credito_bloqueado from ficha), false)
      then greatest(coalesce((select ficha.limite_centavos from ficha), 0) - devido.valor - reservado.valor, 0)
      else 0
    end::bigint
  from devido, reservado;
$$;

-- ---------------------------------------------------------------------------
-- Pedido: ficha obrigatória e limite do fiado
-- ---------------------------------------------------------------------------

create or replace function public.tg_conferir_ficha_e_credito()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ficha public.fichas_cliente%rowtype;
  v_situacao record;
begin
  -- Trava a ficha: dois pedidos fiado ao mesmo tempo não passam do limite.
  select * into v_ficha
  from public.fichas_cliente
  where cliente_id = new.cliente_id
  for update;

  if not found then
    raise exception 'Preencha sua ficha de cadastro antes de fazer o pedido.'
      using errcode = 'P0001';
  end if;

  if new.forma_pagamento = 'crediario'::public.forma_pagamento then
    if v_ficha.status <> 'aprovada' then
      raise exception 'Seu crediário ainda não foi aprovado. Escolha outra forma de pagamento.'
        using errcode = 'P0001';
    end if;
    if v_ficha.credito_bloqueado then
      raise exception 'Seu crediário está bloqueado. Fale com a loja ou escolha outra forma de pagamento.'
        using errcode = 'P0001';
    end if;
    select * into v_situacao from public.situacao_credito(new.cliente_id);
    if new.total_centavos > v_situacao.disponivel_centavos then
      raise exception 'O pedido passa do seu limite livre no crediário (%). Escolha outra forma de pagamento.',
        public.formatar_reais(v_situacao.disponivel_centavos)
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end;
$$;

create trigger conferir_ficha_e_credito
before insert on public.pedidos
for each row execute function public.tg_conferir_ficha_e_credito();

-- Pedido fiado entregue: a compra entra na conta do cliente.
create or replace function public.tg_lancar_compra_credito()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.lancamentos_credito (cliente_id, central_id, pedido_id, tipo, valor_centavos, por_perfil_id)
  values (
    new.cliente_id,
    new.central_id,
    new.id,
    'compra',
    new.total_centavos,
    case when exists (select 1 from public.perfis where id = auth.uid()) then auth.uid() end
  )
  on conflict (pedido_id) do nothing;
  return null;
end;
$$;

create trigger lancar_compra_credito
after update of status on public.pedidos
for each row
when (
  new.status = 'entregue'::public.status_pedido
  and old.status is distinct from new.status
  and new.forma_pagamento = 'crediario'::public.forma_pagamento
)
execute function public.tg_lancar_compra_credito();

-- ---------------------------------------------------------------------------
-- Ficha: envio pelo cliente
-- ---------------------------------------------------------------------------

-- Recebe todos os campos num JSON. Enquanto a ficha não é aprovada, o cliente
-- pode corrigir e reenviar; depois de aprovada, só a loja altera.
create or replace function public.enviar_ficha(p_ficha jsonb)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_cliente uuid := auth.uid();
  v_atual public.fichas_cliente%rowtype;
  v_cpf text := public.somente_digitos(p_ficha ->> 'cpf', 20);
  v_rg text := btrim(coalesce(p_ficha ->> 'rg', ''));
  v_nascimento date;
  v_nome_mae text := btrim(regexp_replace(coalesce(p_ficha ->> 'nome_mae', ''), '\s+', ' ', 'g'));
  v_endereco_id uuid;
  v_endereco public.enderecos%rowtype;
  v_central uuid;
  v_empresa text := btrim(coalesce(p_ficha ->> 'empresa', ''));
  v_profissao text := btrim(coalesce(p_ficha ->> 'profissao', ''));
  v_tel_trabalho text := public.somente_digitos(p_ficha ->> 'telefone_trabalho', 20);
  v_renda integer;
  v_ref1_nome text := btrim(coalesce(p_ficha ->> 'referencia1_nome', ''));
  v_ref1_tel text := public.somente_digitos(p_ficha ->> 'referencia1_telefone', 20);
  v_ref1_rel text := btrim(coalesce(p_ficha ->> 'referencia1_relacao', ''));
  v_ref2_nome text := btrim(coalesce(p_ficha ->> 'referencia2_nome', ''));
  v_ref2_tel text := public.somente_digitos(p_ficha ->> 'referencia2_telefone', 20);
  v_ref2_rel text := btrim(coalesce(p_ficha ->> 'referencia2_relacao', ''));
  v_documento text := btrim(coalesce(p_ficha ->> 'documento_caminho', ''));
  v_comprovante text := btrim(coalesce(p_ficha ->> 'comprovante_caminho', ''));
  v_prefixo text;
begin
  if v_cliente is null or not public.eh_cliente_ativo() then
    raise exception 'Faça login com sua conta de cliente.' using errcode = '42501';
  end if;
  if p_ficha is null or jsonb_typeof(p_ficha) <> 'object' then
    raise exception 'Ficha inválida.' using errcode = '22023';
  end if;

  select * into v_atual from public.fichas_cliente where cliente_id = v_cliente for update;
  if found and v_atual.status = 'aprovada' then
    raise exception 'Sua ficha já foi aprovada. Para mudar algum dado, fale com a loja.'
      using errcode = 'P0001';
  end if;

  if not public.cpf_valido(v_cpf) then
    raise exception 'CPF inválido. Confira os números.' using errcode = '22023';
  end if;
  if exists (select 1 from public.fichas_cliente where cpf = v_cpf and cliente_id <> v_cliente) then
    raise exception 'Este CPF já está em outra conta. Fale com a loja.' using errcode = 'P0001';
  end if;
  if char_length(v_rg) not between 3 and 20 then
    raise exception 'Informe o RG.' using errcode = '22023';
  end if;

  begin
    v_nascimento := (p_ficha ->> 'data_nascimento')::date;
  exception when others then
    v_nascimento := null;
  end;
  if v_nascimento is null then
    raise exception 'Informe a data de nascimento.' using errcode = '22023';
  end if;
  if v_nascimento > (public.hoje_local() - interval '18 years')::date then
    raise exception 'O cadastro é só para maiores de 18 anos.' using errcode = 'P0001';
  end if;
  if v_nascimento < (public.hoje_local() - interval '120 years')::date then
    raise exception 'Confira a data de nascimento.' using errcode = '22023';
  end if;

  if char_length(v_nome_mae) not between 3 and 80 then
    raise exception 'Informe o nome da mãe.' using errcode = '22023';
  end if;

  begin
    v_endereco_id := nullif(p_ficha ->> 'endereco_id', '')::uuid;
  exception when others then
    v_endereco_id := null;
  end;
  select * into v_endereco from public.enderecos where id = v_endereco_id and cliente_id = v_cliente;
  if not found then
    raise exception 'Escolha o endereço onde você mora.' using errcode = '22023';
  end if;
  select a.central_id into v_central
  from public.atendimento_para_coordenadas(v_endereco.latitude, v_endereco.longitude) as a;

  if char_length(v_empresa) not between 2 and 80 then
    raise exception 'Informe onde você trabalha (ou "autônomo").' using errcode = '22023';
  end if;
  if char_length(v_profissao) not between 2 and 60 then
    raise exception 'Informe sua profissão.' using errcode = '22023';
  end if;
  if char_length(v_tel_trabalho) not in (0, 10, 11) then
    raise exception 'Telefone do trabalho com DDD, só números.' using errcode = '22023';
  end if;

  begin
    v_renda := (p_ficha ->> 'renda_mensal_centavos')::integer;
  exception when others then
    v_renda := null;
  end;
  if v_renda is null or v_renda < 0 or v_renda > 100000000 then
    raise exception 'Informe a renda mensal.' using errcode = '22023';
  end if;

  if char_length(v_ref1_nome) not between 3 and 80 or char_length(v_ref2_nome) not between 3 and 80 then
    raise exception 'Informe o nome das duas referências.' using errcode = '22023';
  end if;
  if char_length(v_ref1_tel) not between 10 and 11 or char_length(v_ref2_tel) not between 10 and 11 then
    raise exception 'Informe o telefone com DDD das duas referências.' using errcode = '22023';
  end if;
  if v_ref1_tel = v_ref2_tel then
    raise exception 'As duas referências precisam ter telefones diferentes.' using errcode = '22023';
  end if;
  if char_length(v_ref1_rel) not between 2 and 40 or char_length(v_ref2_rel) not between 2 and 40 then
    raise exception 'Informe quem são as referências (ex.: irmão, vizinho, patrão).' using errcode = '22023';
  end if;

  -- As fotos precisam estar na pasta do próprio cliente no bucket privado.
  v_prefixo := v_cliente::text || '/';
  if left(v_documento, char_length(v_prefixo)) <> v_prefixo
     or left(v_comprovante, char_length(v_prefixo)) <> v_prefixo then
    raise exception 'Envie as fotos de novo.' using errcode = '22023';
  end if;
  if not exists (select 1 from storage.objects where bucket_id = 'fichas' and name = v_documento) then
    raise exception 'A foto do documento não chegou. Envie de novo.' using errcode = 'P0001';
  end if;
  if not exists (select 1 from storage.objects where bucket_id = 'fichas' and name = v_comprovante) then
    raise exception 'A foto do comprovante de endereço não chegou. Envie de novo.' using errcode = 'P0001';
  end if;

  insert into public.fichas_cliente (
    cliente_id, cpf, rg, data_nascimento, nome_mae, endereco_id, central_id,
    empresa, profissao, telefone_trabalho, renda_mensal_centavos,
    referencia1_nome, referencia1_telefone, referencia1_relacao,
    referencia2_nome, referencia2_telefone, referencia2_relacao,
    documento_caminho, comprovante_caminho, status, motivo, enviado_em
  ) values (
    v_cliente, v_cpf, v_rg, v_nascimento, v_nome_mae, v_endereco_id, v_central,
    v_empresa, v_profissao, v_tel_trabalho, v_renda,
    v_ref1_nome, v_ref1_tel, v_ref1_rel,
    v_ref2_nome, v_ref2_tel, v_ref2_rel,
    v_documento, v_comprovante, 'pendente', null, now()
  )
  on conflict (cliente_id) do update
  set cpf = excluded.cpf,
      rg = excluded.rg,
      data_nascimento = excluded.data_nascimento,
      nome_mae = excluded.nome_mae,
      endereco_id = excluded.endereco_id,
      central_id = excluded.central_id,
      empresa = excluded.empresa,
      profissao = excluded.profissao,
      telefone_trabalho = excluded.telefone_trabalho,
      renda_mensal_centavos = excluded.renda_mensal_centavos,
      referencia1_nome = excluded.referencia1_nome,
      referencia1_telefone = excluded.referencia1_telefone,
      referencia1_relacao = excluded.referencia1_relacao,
      referencia2_nome = excluded.referencia2_nome,
      referencia2_telefone = excluded.referencia2_telefone,
      referencia2_relacao = excluded.referencia2_relacao,
      documento_caminho = excluded.documento_caminho,
      comprovante_caminho = excluded.comprovante_caminho,
      status = 'pendente',
      motivo = null,
      enviado_em = now();
end;
$$;

-- ---------------------------------------------------------------------------
-- Ficha: análise pelo dono (ou pela central, se o dono liberar)
-- ---------------------------------------------------------------------------

create or replace function public.analisar_ficha(
  p_cliente_id uuid,
  p_status public.status_ficha,
  p_limite_centavos integer default 0,
  p_motivo text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_ficha public.fichas_cliente%rowtype;
  v_motivo text := nullif(btrim(coalesce(p_motivo, '')), '');
  v_limite integer := coalesce(p_limite_centavos, 0);
  v_teto integer;
begin
  if v_usuario is null then
    raise exception 'Faça login novamente.' using errcode = '42501';
  end if;

  select * into v_ficha from public.fichas_cliente where cliente_id = p_cliente_id for update;
  if not found or not public.pode_analisar_ficha(p_cliente_id) then
    raise exception 'Ficha não encontrada.' using errcode = 'P0002';
  end if;

  if p_status is null or p_status = 'pendente' then
    raise exception 'Escolha aprovar ou recusar.' using errcode = '22023';
  end if;
  if v_motivo is not null and char_length(v_motivo) > 300 then
    raise exception 'O motivo pode ter no máximo 300 letras.' using errcode = '22023';
  end if;

  if p_status = 'recusada' then
    if v_motivo is null then
      raise exception 'Informe o motivo da recusa.' using errcode = '22023';
    end if;
    v_limite := 0;
  else
    if v_limite < 0 or v_limite > 100000000 then
      raise exception 'Limite inválido.' using errcode = '22023';
    end if;
    if not public.eh_dono() then
      select c.limite_maximo_central_centavos into v_teto from public.configuracoes as c where c.id;
      if v_teto is not null and v_limite > v_teto then
        raise exception 'A central pode liberar no máximo % de limite.', public.formatar_reais(v_teto)
          using errcode = 'P0001';
      end if;
    end if;
  end if;

  update public.fichas_cliente
  set status = p_status,
      limite_centavos = v_limite,
      motivo = v_motivo,
      analisado_por = v_usuario,
      analisado_em = now()
  where cliente_id = p_cliente_id;

  insert into public.auditoria (central_id, por_perfil_id, acao, tabela, registro_id, antes, depois)
  values (
    v_ficha.central_id, v_usuario, 'analisar_ficha', 'fichas_cliente', p_cliente_id::text,
    jsonb_build_object('status', v_ficha.status, 'limite_centavos', v_ficha.limite_centavos),
    jsonb_build_object('status', p_status, 'limite_centavos', v_limite, 'motivo', v_motivo)
  );
end;
$$;

create or replace function public.definir_bloqueio_credito(
  p_cliente_id uuid,
  p_bloqueado boolean,
  p_motivo text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_ficha public.fichas_cliente%rowtype;
  v_motivo text := nullif(btrim(coalesce(p_motivo, '')), '');
begin
  select * into v_ficha from public.fichas_cliente where cliente_id = p_cliente_id for update;
  if v_usuario is null or not found or not public.pode_analisar_ficha(p_cliente_id) then
    raise exception 'Ficha não encontrada.' using errcode = 'P0002';
  end if;
  if p_bloqueado is null then
    raise exception 'Escolha bloquear ou liberar.' using errcode = '22023';
  end if;
  if p_bloqueado and v_motivo is null then
    raise exception 'Informe o motivo do bloqueio.' using errcode = '22023';
  end if;
  if v_motivo is not null and char_length(v_motivo) > 300 then
    raise exception 'O motivo pode ter no máximo 300 letras.' using errcode = '22023';
  end if;

  update public.fichas_cliente
  set credito_bloqueado = p_bloqueado,
      motivo = case when p_bloqueado then v_motivo else motivo end
  where cliente_id = p_cliente_id;

  insert into public.auditoria (central_id, por_perfil_id, acao, tabela, registro_id, antes, depois)
  values (
    v_ficha.central_id, v_usuario,
    case when p_bloqueado then 'bloquear_credito' else 'liberar_credito' end,
    'fichas_cliente', p_cliente_id::text,
    jsonb_build_object('credito_bloqueado', v_ficha.credito_bloqueado),
    jsonb_build_object('credito_bloqueado', p_bloqueado, 'motivo', v_motivo)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Consultas
-- ---------------------------------------------------------------------------

-- Resumo do crediário. Sem parâmetro: o do próprio cliente logado.
create or replace function public.resumo_credito(p_cliente_id uuid default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_cliente uuid := coalesce(p_cliente_id, auth.uid());
  v_situacao record;
begin
  if auth.uid() is null or not public.pode_ver_cliente(v_cliente) then
    raise exception 'Cliente não encontrado.' using errcode = 'P0002';
  end if;
  select * into v_situacao from public.situacao_credito(v_cliente);
  return jsonb_build_object(
    'cliente_id', v_cliente,
    'status', v_situacao.status,
    'bloqueado', v_situacao.bloqueado,
    'limite_centavos', v_situacao.limite_centavos,
    'devido_centavos', v_situacao.devido_centavos,
    'reservado_centavos', v_situacao.reservado_centavos,
    'disponivel_centavos', v_situacao.disponivel_centavos
  );
end;
$$;

-- Lista de fichas para o dono (todas) ou para a central (as dela, se liberado).
create or replace function public.listar_fichas(
  p_status public.status_ficha default null,
  p_busca text default null
)
returns table (
  cliente_id uuid,
  nome text,
  telefone text,
  email text,
  cpf text,
  status public.status_ficha,
  limite_centavos integer,
  credito_bloqueado boolean,
  central_id uuid,
  central_nome text,
  enviado_em timestamptz,
  analisado_em timestamptz,
  devido_centavos bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_busca text := nullif(btrim(coalesce(p_busca, '')), '');
  v_digitos text := public.somente_digitos(p_busca, 13);
  v_dono boolean := public.eh_dono();
  v_central uuid := public.central_do_operador();
begin
  if not v_dono and (v_central is null or not public.centrais_aprovam_credito()) then
    raise exception 'Você não tem permissão para ver as fichas.' using errcode = '42501';
  end if;
  return query
  select
    f.cliente_id, p.nome, p.telefone, p.email, f.cpf, f.status, f.limite_centavos,
    f.credito_bloqueado, f.central_id, c.nome, f.enviado_em, f.analisado_em,
    (select coalesce(sum(l.valor_centavos), 0)::bigint
     from public.lancamentos_credito as l where l.cliente_id = f.cliente_id)
  from public.fichas_cliente as f
  join public.perfis as p on p.id = f.cliente_id
  left join public.centrais as c on c.id = f.central_id
  where (v_dono or f.central_id = v_central)
    and (p_status is null or f.status = p_status)
    and (
      v_busca is null
      or p.nome ilike '%' || v_busca || '%'
      or (char_length(v_digitos) >= 3 and (f.cpf like '%' || v_digitos || '%' or p.telefone like '%' || v_digitos || '%'))
    )
  order by (f.status = 'pendente') desc, f.enviado_em desc
  limit 300;
end;
$$;

-- Ficha completa de um cliente (para quem analisa).
create or replace function public.ficha_completa(p_cliente_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_resultado jsonb;
begin
  if p_cliente_id is null
     or not (p_cliente_id = auth.uid() or public.pode_analisar_ficha(p_cliente_id)) then
    raise exception 'Ficha não encontrada.' using errcode = 'P0002';
  end if;
  select to_jsonb(f) || jsonb_build_object(
      'nome', p.nome,
      'telefone', p.telefone,
      'email', p.email,
      'central_nome', c.nome,
      'endereco', case when e.id is null then null else jsonb_build_object(
        'logradouro', e.logradouro, 'numero', e.numero, 'bairro', e.bairro,
        'cidade', e.cidade, 'uf', e.uf, 'cep', e.cep, 'complemento', e.complemento
      ) end,
      'analisado_por_nome', a.nome
    )
  into v_resultado
  from public.fichas_cliente as f
  join public.perfis as p on p.id = f.cliente_id
  left join public.centrais as c on c.id = f.central_id
  left join public.enderecos as e on e.id = f.endereco_id
  left join public.perfis as a on a.id = f.analisado_por
  where f.cliente_id = p_cliente_id;
  if v_resultado is null then
    raise exception 'Ficha não encontrada.' using errcode = 'P0002';
  end if;
  return v_resultado;
end;
$$;

-- Quem deve: dono vê todos; a central vê os clientes dela.
create or replace function public.devedores(p_central_id uuid default null)
returns table (
  cliente_id uuid,
  nome text,
  telefone text,
  limite_centavos integer,
  devido_centavos bigint,
  ultima_compra timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_dono boolean := public.eh_dono();
  v_central uuid := case when public.eh_dono() then p_central_id else public.central_do_operador() end;
begin
  if not v_dono and v_central is null then
    raise exception 'Você não tem permissão para ver o crediário.' using errcode = '42501';
  end if;
  return query
  select
    l.cliente_id, p.nome, p.telefone, coalesce(f.limite_centavos, 0),
    sum(l.valor_centavos)::bigint,
    max(l.criado_em) filter (where l.tipo = 'compra')
  from public.lancamentos_credito as l
  join public.perfis as p on p.id = l.cliente_id
  left join public.fichas_cliente as f on f.cliente_id = l.cliente_id
  where v_central is null
     or f.central_id = v_central
     or exists (
       select 1 from public.pedidos as pe
       where pe.cliente_id = l.cliente_id and pe.central_id = v_central
     )
  group by l.cliente_id, p.nome, p.telefone, f.limite_centavos
  having sum(l.valor_centavos) > 0
  order by sum(l.valor_centavos) desc
  limit 500;
end;
$$;

-- ---------------------------------------------------------------------------
-- Pagamentos e ajustes
-- ---------------------------------------------------------------------------

create or replace function public.registrar_pagamento_credito(
  p_cliente_id uuid,
  p_valor_centavos integer,
  p_forma public.forma_pagamento,
  p_observacao text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_devido bigint;
  v_observacao text := nullif(btrim(coalesce(p_observacao, '')), '');
begin
  if v_usuario is null
     or not (public.eh_dono() or public.central_do_operador() is not null)
     or not public.pode_ver_cliente(p_cliente_id) then
    raise exception 'Cliente não encontrado.' using errcode = 'P0002';
  end if;
  if p_forma is null or p_forma = 'crediario'::public.forma_pagamento then
    raise exception 'Escolha como o cliente pagou.' using errcode = '22023';
  end if;
  if v_observacao is not null and char_length(v_observacao) > 300 then
    raise exception 'A observação pode ter no máximo 300 letras.' using errcode = '22023';
  end if;

  -- Um pagamento por vez para o mesmo cliente.
  perform pg_advisory_xact_lock(hashtextextended('credito:' || p_cliente_id::text, 0));

  select coalesce(sum(valor_centavos), 0) into v_devido
  from public.lancamentos_credito where cliente_id = p_cliente_id;

  if p_valor_centavos is null or p_valor_centavos <= 0 then
    raise exception 'Informe o valor recebido.' using errcode = '22023';
  end if;
  if p_valor_centavos > v_devido then
    raise exception 'O valor passa do que o cliente deve (%).', public.formatar_reais(v_devido)
      using errcode = 'P0001';
  end if;

  insert into public.lancamentos_credito (cliente_id, central_id, tipo, valor_centavos, forma, observacao, por_perfil_id)
  values (
    p_cliente_id,
    case when public.eh_dono() then null else public.central_do_operador() end,
    'pagamento', -p_valor_centavos, p_forma, v_observacao, v_usuario
  );

  return public.resumo_credito(p_cliente_id);
end;
$$;

-- Ajuste manual (só o dono), sempre com motivo. Positivo aumenta a dívida.
create or replace function public.ajustar_credito(
  p_cliente_id uuid,
  p_valor_centavos integer,
  p_motivo text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_motivo text := nullif(btrim(coalesce(p_motivo, '')), '');
begin
  if not public.eh_dono() then
    raise exception 'Somente o dono faz ajustes no crediário.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.perfis where id = p_cliente_id and papel = 'cliente') then
    raise exception 'Cliente não encontrado.' using errcode = 'P0002';
  end if;
  if p_valor_centavos is null or p_valor_centavos = 0 or abs(p_valor_centavos) > 100000000 then
    raise exception 'Informe o valor do ajuste.' using errcode = '22023';
  end if;
  if v_motivo is null or char_length(v_motivo) > 300 then
    raise exception 'Informe o motivo do ajuste (até 300 letras).' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('credito:' || p_cliente_id::text, 0));
  insert into public.lancamentos_credito (cliente_id, tipo, valor_centavos, observacao, por_perfil_id)
  values (p_cliente_id, 'ajuste', p_valor_centavos, v_motivo, auth.uid());

  insert into public.auditoria (por_perfil_id, acao, tabela, registro_id, depois)
  values (auth.uid(), 'ajustar_credito', 'lancamentos_credito', p_cliente_id::text,
          jsonb_build_object('valor_centavos', p_valor_centavos, 'motivo', v_motivo));

  return public.resumo_credito(p_cliente_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Fotos da ficha (Storage privado)
-- ---------------------------------------------------------------------------
-- Cada cliente envia só para a própria pasta (<id do cliente>/...). Ninguém
-- troca nem apaga pelo app. Leem: o próprio cliente, o dono e a central que
-- analisa (quando liberado). As fotos abrem por link temporário.

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('fichas', 'fichas', false, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
    on conflict (id) do update
    set public = false,
        file_size_limit = excluded.file_size_limit,
        allowed_mime_types = excluded.allowed_mime_types;

    execute $p$
      create policy fichas_fotos_enviar_cliente on storage.objects
      for insert to authenticated
      with check (
        bucket_id = 'fichas'
        and (storage.foldername(name))[1] = (select auth.uid())::text
        and (select public.eh_cliente_ativo())
      )
    $p$;
    execute $p$
      create policy fichas_fotos_ler on storage.objects
      for select to authenticated
      using (
        bucket_id = 'fichas'
        and (
          (storage.foldername(name))[1] = (select auth.uid())::text
          or (select public.eh_dono())
          or (
            (select public.centrais_aprovam_credito())
            and exists (
              select 1 from public.fichas_cliente as f
              where f.cliente_id::text = (storage.foldername(name))[1]
                and f.central_id = (select public.central_do_operador())
            )
          )
        )
      )
    $p$;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Permissões e RLS
-- ---------------------------------------------------------------------------

alter table public.configuracoes enable row level security;
alter table public.fichas_cliente enable row level security;
alter table public.lancamentos_credito enable row level security;

revoke all on public.configuracoes, public.fichas_cliente, public.lancamentos_credito
  from public, anon, authenticated;
grant all on public.configuracoes, public.fichas_cliente, public.lancamentos_credito to service_role;

grant select on public.configuracoes to authenticated;
grant update (centrais_aprovam_credito, limite_maximo_central_centavos) on public.configuracoes to authenticated;
grant select on public.fichas_cliente to authenticated;
grant select on public.lancamentos_credito to authenticated;

create policy configuracoes_ler on public.configuracoes
for select to authenticated
using ((select public.eh_dono()) or (select public.central_do_operador()) is not null);

create policy configuracoes_atualizar_dono on public.configuracoes
for update to authenticated
using ((select public.eh_dono()))
with check ((select public.eh_dono()));

create policy fichas_cliente_ler on public.fichas_cliente
for select to authenticated
using (
  cliente_id = (select auth.uid())
  or (select public.eh_dono())
  or (
    central_id = (select public.central_do_operador())
    and (select public.centrais_aprovam_credito())
  )
);

create policy lancamentos_credito_ler on public.lancamentos_credito
for select to authenticated
using (
  cliente_id = (select auth.uid())
  or (select public.eh_dono())
  or ((select public.central_do_operador()) is not null and public.pode_ver_cliente(cliente_id))
);

-- Funções: nada aberto por padrão.
revoke all on function public.cpf_valido(text) from public, anon, authenticated;
revoke all on function public.formatar_reais(bigint) from public, anon, authenticated;
revoke all on function public.centrais_aprovam_credito() from public, anon, authenticated;
revoke all on function public.pode_ver_cliente(uuid) from public, anon, authenticated;
revoke all on function public.pode_analisar_ficha(uuid) from public, anon, authenticated;
revoke all on function public.situacao_credito(uuid) from public, anon, authenticated;
revoke all on function public.tg_conferir_ficha_e_credito() from public, anon, authenticated;
revoke all on function public.tg_lancar_compra_credito() from public, anon, authenticated;
revoke all on function public.enviar_ficha(jsonb) from public, anon, authenticated;
revoke all on function public.analisar_ficha(uuid, public.status_ficha, integer, text) from public, anon, authenticated;
revoke all on function public.definir_bloqueio_credito(uuid, boolean, text) from public, anon, authenticated;
revoke all on function public.resumo_credito(uuid) from public, anon, authenticated;
revoke all on function public.listar_fichas(public.status_ficha, text) from public, anon, authenticated;
revoke all on function public.ficha_completa(uuid) from public, anon, authenticated;
revoke all on function public.devedores(uuid) from public, anon, authenticated;
revoke all on function public.registrar_pagamento_credito(uuid, integer, public.forma_pagamento, text) from public, anon, authenticated;
revoke all on function public.ajustar_credito(uuid, integer, text) from public, anon, authenticated;

grant execute on function
  public.cpf_valido(text),
  public.formatar_reais(bigint),
  public.centrais_aprovam_credito(),
  public.pode_ver_cliente(uuid),
  public.pode_analisar_ficha(uuid),
  public.situacao_credito(uuid),
  public.tg_conferir_ficha_e_credito(),
  public.tg_lancar_compra_credito(),
  public.enviar_ficha(jsonb),
  public.analisar_ficha(uuid, public.status_ficha, integer, text),
  public.definir_bloqueio_credito(uuid, boolean, text),
  public.resumo_credito(uuid),
  public.listar_fichas(public.status_ficha, text),
  public.ficha_completa(uuid),
  public.devedores(uuid),
  public.registrar_pagamento_credito(uuid, integer, public.forma_pagamento, text),
  public.ajustar_credito(uuid, integer, text)
to service_role;

-- Usadas pelas regras de acesso (RLS e Storage).
grant execute on function public.centrais_aprovam_credito() to authenticated;
grant execute on function public.pode_ver_cliente(uuid) to authenticated;

-- Funções que os apps chamam (cada uma confere quem chamou).
grant execute on function public.enviar_ficha(jsonb) to authenticated;
grant execute on function public.analisar_ficha(uuid, public.status_ficha, integer, text) to authenticated;
grant execute on function public.definir_bloqueio_credito(uuid, boolean, text) to authenticated;
grant execute on function public.resumo_credito(uuid) to authenticated;
grant execute on function public.listar_fichas(public.status_ficha, text) to authenticated;
grant execute on function public.ficha_completa(uuid) to authenticated;
grant execute on function public.devedores(uuid) to authenticated;
grant execute on function public.registrar_pagamento_credito(uuid, integer, public.forma_pagamento, text) to authenticated;
grant execute on function public.ajustar_credito(uuid, integer, text) to authenticated;
