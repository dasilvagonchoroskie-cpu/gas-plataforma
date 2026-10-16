-- Chave do Firebase (notificações push) guardada no Vault pelo próprio dono.
--
-- O dono baixa o arquivo da "conta de serviço" no console do Firebase e o envia
-- pela Super Central. A Edge Function "configurar-notificacoes" confere que
-- quem enviou é o dono, valida o arquivo com o Google e chama a função abaixo
-- (só service_role). A chave nunca passa pelo chat, pelo código nem pelo GitHub,
-- e a função "notificar" passa a lê-la do Vault.
--
--   fcm_conta_servico   JSON da conta de serviço do Firebase (só envio de push)

create or replace function public.segredo_do_servidor(p_nome text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_valor text;
begin
  if p_nome is null or p_nome not in (
    'notificar_segredo',
    'android_chave_base64',
    'android_chave_senha',
    'android_chave_apelido',
    'fcm_conta_servico'
  ) then
    raise exception 'Segredo não permitido.' using errcode = '42501';
  end if;

  execute 'select decrypted_secret from vault.decrypted_secrets where name = $1 limit 1'
    into v_valor using p_nome;
  return v_valor;
end;
$$;

create or replace function public.guardar_segredo_do_servidor(
  p_nome text,
  p_valor text,
  p_por_perfil_id uuid
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  -- Só a chave do Firebase pode ser trocada por aqui (a chave dos APKs, não).
  if p_nome is null or p_nome not in ('fcm_conta_servico') then
    raise exception 'Segredo não permitido.' using errcode = '42501';
  end if;
  if p_valor is null or char_length(p_valor) < 200 or char_length(p_valor) > 20000 then
    raise exception 'Conteúdo inválido.' using errcode = '22023';
  end if;

  execute 'select id from vault.secrets where name = $1 limit 1' into v_id using p_nome;
  if v_id is null then
    execute 'select vault.create_secret($1, $2, $3)'
      using p_valor, p_nome, 'Conta de serviço do Firebase (envio de notificações)';
  else
    execute 'select vault.update_secret($1, $2)' using v_id, p_valor;
  end if;

  -- Fica registrado quem trocou e quando (nunca o conteúdo).
  insert into public.auditoria (por_perfil_id, acao, tabela, registro_id, depois)
  values (p_por_perfil_id, 'configurar_notificacoes', 'segredos', p_nome,
          jsonb_build_object('segredo', p_nome));
end;
$$;

revoke all on function public.segredo_do_servidor(text) from public, anon, authenticated;
grant execute on function public.segredo_do_servidor(text) to service_role;
revoke all on function public.guardar_segredo_do_servidor(text, text, uuid) from public, anon, authenticated;
grant execute on function public.guardar_segredo_do_servidor(text, text, uuid) to service_role;

comment on function public.guardar_segredo_do_servidor(text, text, uuid) is
  'Grava a chave do Firebase no Vault (chamada pela Edge Function configurar-notificacoes). Somente service_role.';
