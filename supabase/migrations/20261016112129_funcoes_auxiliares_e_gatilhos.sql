-- Fase 1 — funções auxiliares e gatilhos.
--
-- Todas as funções security definer usam search_path vazio e nomes completos,
-- para não poderem ser enganadas por objetos criados em outro schema.

-- ---------------------------------------------------------------------------
-- Identidade do usuário logado
-- ---------------------------------------------------------------------------

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
      and p.ativo
      and p.excluido_em is null
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
    and p.ativo
    and p.excluido_em is null;
$$;

create or replace function public.pode_acessar_central(p_central_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  -- coalesce é obrigatório: para quem não é operador, central_do_operador()
  -- devolve nulo, e "nulo" não pode ser tratado como permissão.
  select coalesce(
    p_central_id is not null
      and (public.eh_dono() or public.central_do_operador() = p_central_id),
    false
  );
$$;

create or replace function public.eh_cliente_ativo()
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
      and p.papel = 'cliente'::public.papel_perfil
      and p.ativo
      and p.excluido_em is null
  );
$$;

-- Hora e data no fuso da operação.
create or replace function public.agora_local()
returns timestamp
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'America/Sao_Paulo');
$$;

create or replace function public.hoje_local()
returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'America/Sao_Paulo')::date;
$$;

-- Distância em linha reta (fórmula de Haversine), em quilômetros.
create or replace function public.distancia_km(
  p_lat1 double precision,
  p_lon1 double precision,
  p_lat2 double precision,
  p_lon2 double precision
)
returns double precision
language sql
immutable
parallel safe
set search_path = ''
as $$
  select 2 * 6371.0088 * asin(
    least(1.0, sqrt(
      power(sin(radians(p_lat2 - p_lat1) / 2), 2)
      + cos(radians(p_lat1)) * cos(radians(p_lat2))
        * power(sin(radians(p_lon2 - p_lon1) / 2), 2)
    ))
  );
$$;

-- Deixa só os dígitos de um telefone (até 13).
create or replace function public.somente_digitos(p_texto text, p_limite integer default 13)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select left(regexp_replace(coalesce(p_texto, ''), '[^0-9]', '', 'g'), p_limite);
$$;

-- ---------------------------------------------------------------------------
-- Perfil criado automaticamente a cada novo login
-- ---------------------------------------------------------------------------

-- O papel começa sempre como cliente. Os dados enviados pelo app no cadastro
-- (user_metadata) nunca definem papel: operadores e donos são criados pelo
-- servidor, na função admin-usuarios.
create or replace function public.tg_criar_perfil_do_usuario()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nome text;
begin
  v_nome := left(btrim(coalesce(
    nullif(btrim(new.raw_user_meta_data ->> 'nome'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Cliente'
  )), 80);

  insert into public.perfis (id, nome, telefone, email)
  values (
    new.id,
    v_nome,
    public.somente_digitos(new.raw_user_meta_data ->> 'telefone'),
    left(new.email, 254)
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger criar_perfil_ao_cadastrar
after insert on auth.users
for each row execute function public.tg_criar_perfil_do_usuario();

-- Mantém o e-mail do perfil igual ao do login.
create or replace function public.tg_sincronizar_email_do_usuario()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.perfis
  set email = left(new.email, 254)
  where id = new.id
    and excluido_em is null
    and email is distinct from new.email;
  return new;
end;
$$;

create trigger sincronizar_email_do_perfil
after update of email on auth.users
for each row execute function public.tg_sincronizar_email_do_usuario();

-- ---------------------------------------------------------------------------
-- Gatilhos de consistência
-- ---------------------------------------------------------------------------

create or replace function public.tg_atualizado_em()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;

create trigger perfis_atualizado_em before update on public.perfis
for each row execute function public.tg_atualizado_em();
create trigger centrais_atualizado_em before update on public.centrais
for each row execute function public.tg_atualizado_em();
create trigger entregadores_atualizado_em before update on public.entregadores
for each row execute function public.tg_atualizado_em();
create trigger faixas_entrega_atualizado_em before update on public.faixas_entrega
for each row execute function public.tg_atualizado_em();
create trigger produtos_atualizado_em before update on public.produtos
for each row execute function public.tg_atualizado_em();
create trigger precos_central_atualizado_em before update on public.precos_central
for each row execute function public.tg_atualizado_em();
create trigger estoque_central_atualizado_em before update on public.estoque_central
for each row execute function public.tg_atualizado_em();
create trigger janelas_entrega_atualizado_em before update on public.janelas_entrega
for each row execute function public.tg_atualizado_em();
create trigger enderecos_atualizado_em before update on public.enderecos
for each row execute function public.tg_atualizado_em();
create trigger pedidos_atualizado_em before update on public.pedidos
for each row execute function public.tg_atualizado_em();
create trigger dispositivos_push_atualizado_em before update on public.dispositivos_push
for each row execute function public.tg_atualizado_em();

-- Só operador de central pode ser vinculado a uma central.
create or replace function public.tg_validar_vinculo_operador()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.perfis as p
    where p.id = new.perfil_id
      and p.papel = 'operador_central'::public.papel_perfil
  ) then
    raise exception 'Somente usuários com papel de operador podem ser vinculados a uma central.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger operadores_central_validar_papel
before insert or update on public.operadores_central
for each row execute function public.tg_validar_vinculo_operador();

-- Operador pode marcar produto como disponível ou indisponível na própria
-- central, mas só o dono altera o valor. Chamadas do servidor (sem usuário
-- logado) e do dono passam.
create or replace function public.tg_proteger_preco()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is not null
     and new.preco_centavos is distinct from old.preco_centavos
     and not public.eh_dono() then
    raise exception 'Somente o dono pode alterar preços.'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger precos_central_proteger_valor
before update on public.precos_central
for each row execute function public.tg_proteger_preco();

-- Limite de endereços por cliente.
create or replace function public.tg_limitar_enderecos()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select count(*) from public.enderecos where cliente_id = new.cliente_id) >= 10 then
    raise exception 'Você pode salvar no máximo 10 endereços.'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger enderecos_limite
before insert on public.enderecos
for each row execute function public.tg_limitar_enderecos();

-- Normaliza CEP e UF dos endereços.
create or replace function public.tg_normalizar_endereco()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.cep := public.somente_digitos(new.cep, 8);
  new.uf := upper(btrim(new.uf));
  new.apelido := btrim(new.apelido);
  new.logradouro := btrim(new.logradouro);
  new.numero := btrim(new.numero);
  new.bairro := btrim(new.bairro);
  new.cidade := btrim(new.cidade);
  new.complemento := nullif(btrim(coalesce(new.complemento, '')), '');
  new.referencia := nullif(btrim(coalesce(new.referencia, '')), '');
  return new;
end;
$$;

create trigger enderecos_normalizar
before insert or update on public.enderecos
for each row execute function public.tg_normalizar_endereco();

-- Normaliza telefones digitados no perfil e nos entregadores.
create or replace function public.tg_normalizar_telefone()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.telefone := public.somente_digitos(new.telefone);
  new.nome := btrim(new.nome);
  return new;
end;
$$;

create trigger perfis_normalizar before insert or update on public.perfis
for each row execute function public.tg_normalizar_telefone();
create trigger entregadores_normalizar before insert or update on public.entregadores
for each row execute function public.tg_normalizar_telefone();

create or replace function public.tg_normalizar_central()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.nome := btrim(new.nome);
  new.cidade := btrim(new.cidade);
  new.uf := upper(btrim(new.uf));
  new.endereco := btrim(coalesce(new.endereco, ''));
  new.whatsapp := nullif(public.somente_digitos(new.whatsapp), '');
  return new;
end;
$$;

create trigger centrais_normalizar before insert or update on public.centrais
for each row execute function public.tg_normalizar_central();

-- ---------------------------------------------------------------------------
-- Auditoria das tabelas administrativas
-- ---------------------------------------------------------------------------

create or replace function public.tg_auditar()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_antes jsonb;
  v_depois jsonb;
  v_linha jsonb;
  v_central uuid;
  v_registro text;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    v_antes := to_jsonb(old) - 'atualizado_em';
  end if;
  if tg_op in ('INSERT', 'UPDATE') then
    v_depois := to_jsonb(new) - 'atualizado_em';
  end if;
  if tg_op = 'UPDATE' and v_antes = v_depois then
    return null;
  end if;

  v_linha := coalesce(v_depois, v_antes);
  if tg_table_name = 'centrais' then
    v_central := (v_linha ->> 'id')::uuid;
  else
    v_central := (v_linha ->> 'central_id')::uuid;
  end if;

  v_registro := coalesce(
    v_linha ->> 'id',
    concat_ws(':', v_linha ->> 'central_id', v_linha ->> 'produto_id', v_linha ->> 'perfil_id')
  );

  insert into public.auditoria (central_id, por_perfil_id, acao, tabela, registro_id, antes, depois)
  values (
    -- Se a central foi apagada nesta mesma operação, a auditoria fica sem vínculo.
    case when exists (select 1 from public.centrais where id = v_central) then v_central end,
    case when exists (select 1 from public.perfis where id = auth.uid()) then auth.uid() end,
    lower(tg_op),
    tg_table_name,
    v_registro,
    v_antes,
    v_depois
  );
  return null;
end;
$$;

create trigger auditar_centrais after insert or update or delete on public.centrais
for each row execute function public.tg_auditar();
create trigger auditar_produtos after insert or update or delete on public.produtos
for each row execute function public.tg_auditar();
create trigger auditar_precos after insert or update or delete on public.precos_central
for each row execute function public.tg_auditar();
create trigger auditar_faixas after insert or update or delete on public.faixas_entrega
for each row execute function public.tg_auditar();
create trigger auditar_janelas after insert or update or delete on public.janelas_entrega
for each row execute function public.tg_auditar();
create trigger auditar_bloqueios after insert or update or delete on public.bloqueios_agenda
for each row execute function public.tg_auditar();
create trigger auditar_entregadores after insert or update or delete on public.entregadores
for each row execute function public.tg_auditar();
create trigger auditar_operadores after insert or update or delete on public.operadores_central
for each row execute function public.tg_auditar();

-- No perfil, só mudanças de papel e de ativação vão para a auditoria, sem
-- copiar nome, telefone ou e-mail.
create or replace function public.tg_auditar_perfil()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.auditoria (por_perfil_id, acao, tabela, registro_id, antes, depois)
  values (
    case when exists (select 1 from public.perfis where id = auth.uid()) then auth.uid() end,
    'update',
    'perfis',
    new.id::text,
    jsonb_build_object('papel', old.papel, 'ativo', old.ativo),
    jsonb_build_object('papel', new.papel, 'ativo', new.ativo)
  );
  return null;
end;
$$;

create trigger auditar_perfis_papel
after update of papel, ativo on public.perfis
for each row
when (old.papel is distinct from new.papel or old.ativo is distinct from new.ativo)
execute function public.tg_auditar_perfil();
