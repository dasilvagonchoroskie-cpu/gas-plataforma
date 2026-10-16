-- Fase 1 — funções de conta: aparelhos para notificação e exclusão de conta.
-- (Separadas das funções de pedido porque contêm DELETE e pedem confirmação
-- própria ao aplicar.)

-- ---------------------------------------------------------------------------
-- Aparelhos para notificação
-- ---------------------------------------------------------------------------

-- O mesmo celular pode trocar de conta: o token passa para quem está logado.
create or replace function public.registrar_dispositivo(
  p_token text,
  p_plataforma text
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Faça login novamente.' using errcode = '42501';
  end if;
  if p_token is null or char_length(p_token) < 10 or char_length(p_token) > 4096 then
    raise exception 'Identificador do aparelho inválido.' using errcode = '22023';
  end if;
  if p_plataforma not in ('android', 'ios', 'web') then
    raise exception 'Plataforma inválida.' using errcode = '22023';
  end if;

  insert into public.dispositivos_push (perfil_id, token, plataforma)
  values (auth.uid(), p_token, p_plataforma)
  on conflict (token) do update
  set perfil_id = excluded.perfil_id,
      plataforma = excluded.plataforma,
      atualizado_em = now();

  -- No máximo 5 aparelhos por pessoa: remove os mais antigos.
  delete from public.dispositivos_push
  where id in (
    select id from public.dispositivos_push
    where perfil_id = auth.uid()
    order by atualizado_em desc
    offset 5
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Exclusão de conta (LGPD)
-- ---------------------------------------------------------------------------

-- Chamada pela Edge Function excluir-conta antes de apagar o login. Os pedidos
-- ficam para os relatórios, mas sem nome, telefone e endereço completo.
create or replace function public.anonimizar_minha_conta()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_usuario uuid := auth.uid();
  v_perfil public.perfis%rowtype;
begin
  select * into v_perfil from public.perfis where id = v_usuario for update;
  if not found then
    raise exception 'Conta não encontrada.' using errcode = 'P0002';
  end if;
  if v_perfil.papel <> 'cliente'::public.papel_perfil then
    raise exception 'Contas de operador ou dono são removidas pelo dono da revenda.'
      using errcode = '42501';
  end if;
  if v_perfil.excluido_em is not null then
    return;
  end if;
  if exists (
    select 1 from public.pedidos
    where cliente_id = v_usuario and status in ('novo', 'confirmado', 'em_rota')
  ) then
    raise exception 'Você tem um pedido em andamento. Aguarde a entrega ou cancele antes de excluir a conta.'
      using errcode = 'P0001';
  end if;

  update public.pedidos
  set cliente_nome = 'Cliente removido',
      cliente_telefone = '',
      endereco_apelido = null,
      logradouro_entrega = 'Endereço removido',
      numero_entrega = '',
      complemento_entrega = null,
      referencia_entrega = null,
      cep_entrega = left(cep_entrega, 5) || '000',
      latitude_entrega = round(latitude_entrega::numeric, 2)::double precision,
      longitude_entrega = round(longitude_entrega::numeric, 2)::double precision,
      observacao = null
  where cliente_id = v_usuario;

  delete from public.enderecos where cliente_id = v_usuario;
  delete from public.dispositivos_push where perfil_id = v_usuario;

  update public.perfis
  set nome = 'Conta excluída',
      telefone = '',
      email = null,
      ativo = false,
      excluido_em = now()
  where id = v_usuario;
end;
$$;
