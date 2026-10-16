-- Segredos usados só pelas Edge Functions do servidor (nunca pelos apps).
--
-- Os valores ficam guardados criptografados no Vault do Supabase e são
-- cadastrados fora das migrations (nunca no código). Esta função só lê os nomes
-- permitidos abaixo e só pode ser chamada com a chave service_role, que existe
-- apenas dentro das Edge Functions.
--
--   notificar_segredo      senha que o banco envia para a função "notificar"
--   android_chave_base64   chave de assinatura dos APKs (arquivo .jks em base64)
--   android_chave_senha    senha dessa chave
--   android_chave_apelido  apelido (alias) da chave dentro do arquivo

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
    'android_chave_apelido'
  ) then
    raise exception 'Segredo não permitido.' using errcode = '42501';
  end if;

  execute 'select decrypted_secret from vault.decrypted_secrets where name = $1 limit 1'
    into v_valor using p_nome;
  return v_valor;
end;
$$;

revoke all on function public.segredo_do_servidor(text) from public, anon, authenticated;
grant execute on function public.segredo_do_servidor(text) to service_role;

comment on function public.segredo_do_servidor(text) is
  'Lê um segredo do Vault para as Edge Functions. Somente service_role.';
