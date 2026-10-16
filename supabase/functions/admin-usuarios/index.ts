// Gestão de usuários pelo dono: criar operador ou administrador, trocar a
// central do operador, mudar papel, ativar/desativar e redefinir senha.
//
// Somente quem tem papel "dono" (ativo) pode chamar. A chave service_role fica
// só aqui no servidor.
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PAPEIS_GERENCIAVEIS = ["cliente", "operador_central", "dono"] as const;
type Papel = (typeof PAPEIS_GERENCIAVEIS)[number];

class ErroDeUso extends Error {
  constructor(public status: number, mensagem: string) {
    super(mensagem);
  }
}

function resposta(status: number, corpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

function texto(valor: unknown): string {
  return typeof valor === "string" ? valor.trim() : "";
}

function uuid(valor: unknown, campo: string): string {
  const v = texto(valor);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v)) {
    throw new ErroDeUso(400, `Campo ${campo} inválido.`);
  }
  return v;
}

function validarSenha(senha: unknown): string {
  if (typeof senha !== "string" || senha.length < 8 || senha.length > 72) {
    throw new ErroDeUso(400, "A senha precisa ter pelo menos 8 caracteres.");
  }
  return senha;
}

async function exigirCentral(admin: SupabaseClient, centralId: string) {
  const { data, error } = await admin.from("centrais").select("id").eq("id", centralId).maybeSingle();
  if (error) throw error;
  if (!data) throw new ErroDeUso(404, "Central não encontrada.");
}

async function auditar(
  admin: SupabaseClient,
  donoId: string,
  acao: string,
  registroId: string,
  depois: Record<string, unknown>,
  centralId: string | null = null,
) {
  const { error } = await admin.from("auditoria").insert({
    por_perfil_id: donoId,
    central_id: centralId,
    acao,
    tabela: "usuarios",
    registro_id: registroId,
    depois,
  });
  if (error) console.error("Falha ao auditar:", error.message);
}

async function definirPapel(
  admin: SupabaseClient,
  usuarioId: string,
  papel: Papel,
  centralId: string | null,
) {
  if (papel === "operador_central" && !centralId) {
    throw new ErroDeUso(400, "Escolha a central do operador.");
  }
  if (centralId) await exigirCentral(admin, centralId);

  // Remove o vínculo antes de mudar o papel, para o gatilho do banco aceitar.
  if (papel !== "operador_central") {
    const { error } = await admin.from("operadores_central").delete().eq("perfil_id", usuarioId);
    if (error) throw error;
  }

  const { error: erroPerfil } = await admin.from("perfis").update({ papel }).eq("id", usuarioId);
  if (erroPerfil) throw erroPerfil;

  if (papel === "operador_central") {
    const { error } = await admin
      .from("operadores_central")
      .upsert({ perfil_id: usuarioId, central_id: centralId }, { onConflict: "perfil_id" });
    if (error) throw error;
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return resposta(405, { erro: "Método não permitido." });

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Quem está chamando?
    const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
    if (!token) throw new ErroDeUso(401, "Faça login novamente.");
    const { data: usuario, error: erroUsuario } = await admin.auth.getUser(token);
    if (erroUsuario || !usuario?.user) throw new ErroDeUso(401, "Faça login novamente.");
    const donoId = usuario.user.id;

    const { data: perfilDono, error: erroPerfil } = await admin
      .from("perfis")
      .select("papel, ativo, excluido_em")
      .eq("id", donoId)
      .maybeSingle();
    if (erroPerfil) throw erroPerfil;
    if (!perfilDono || perfilDono.papel !== "dono" || !perfilDono.ativo || perfilDono.excluido_em) {
      throw new ErroDeUso(403, "Somente o dono pode gerenciar usuários.");
    }

    const dados = await req.json().catch(() => ({})) as Record<string, unknown>;
    const acao = texto(dados.acao);

    if (acao === "criar") {
      const nome = texto(dados.nome).replace(/\s+/g, " ");
      const telefone = texto(dados.telefone).replace(/\D/g, "");
      const email = texto(dados.email).toLowerCase();
      const senha = validarSenha(dados.senha);
      const papel = texto(dados.papel) as Papel;
      const centralId = dados.central_id ? uuid(dados.central_id, "central_id") : null;

      if (nome.length < 2 || nome.length > 80) throw new ErroDeUso(400, "Informe o nome completo.");
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) throw new ErroDeUso(400, "E-mail inválido.");
      if (!["operador_central", "dono"].includes(papel)) {
        throw new ErroDeUso(400, "Escolha se é operador de central ou administrador.");
      }
      if (papel === "operador_central") {
        if (!centralId) throw new ErroDeUso(400, "Escolha a central do operador.");
        await exigirCentral(admin, centralId);
      }

      const { data: criado, error } = await admin.auth.admin.createUser({
        email,
        password: senha,
        email_confirm: true,
        user_metadata: { nome, telefone },
      });
      if (error) {
        if (error.code === "email_exists" || (error.message ?? "").toLowerCase().includes("already")) {
          throw new ErroDeUso(409, "Já existe um usuário com este e-mail.");
        }
        throw error;
      }

      const novoId = criado.user!.id;
      try {
        await definirPapel(admin, novoId, papel, centralId);
      } catch (erro) {
        // Não deixa login "pela metade": desfaz a criação.
        await admin.auth.admin.deleteUser(novoId);
        throw erro;
      }
      await auditar(admin, donoId, "criar_usuario", novoId, { email, papel, central_id: centralId }, centralId);
      return resposta(201, { ok: true, usuario_id: novoId });
    }

    if (acao === "mudar_papel") {
      const usuarioId = uuid(dados.usuario_id, "usuario_id");
      const papel = texto(dados.papel) as Papel;
      const centralId = dados.central_id ? uuid(dados.central_id, "central_id") : null;
      if (!PAPEIS_GERENCIAVEIS.includes(papel)) throw new ErroDeUso(400, "Papel inválido.");
      if (usuarioId === donoId) throw new ErroDeUso(400, "Você não pode mudar o seu próprio papel.");
      await definirPapel(admin, usuarioId, papel, centralId);
      await auditar(admin, donoId, "mudar_papel", usuarioId, { papel, central_id: centralId }, centralId);
      return resposta(200, { ok: true });
    }

    if (acao === "definir_ativo") {
      const usuarioId = uuid(dados.usuario_id, "usuario_id");
      const ativo = dados.ativo === true;
      if (usuarioId === donoId) throw new ErroDeUso(400, "Você não pode desativar a sua própria conta.");
      const { error: erroBan } = await admin.auth.admin.updateUserById(usuarioId, {
        ban_duration: ativo ? "none" : "876000h",
      });
      if (erroBan) throw erroBan;
      const { error } = await admin.from("perfis").update({ ativo }).eq("id", usuarioId);
      if (error) throw error;
      await auditar(admin, donoId, ativo ? "ativar_usuario" : "desativar_usuario", usuarioId, { ativo });
      return resposta(200, { ok: true });
    }

    if (acao === "redefinir_senha") {
      const usuarioId = uuid(dados.usuario_id, "usuario_id");
      const senha = validarSenha(dados.senha);
      const { error } = await admin.auth.admin.updateUserById(usuarioId, { password: senha });
      if (error) throw error;
      await auditar(admin, donoId, "redefinir_senha", usuarioId, {});
      return resposta(200, { ok: true });
    }

    throw new ErroDeUso(400, "Ação desconhecida.");
  } catch (erro) {
    if (erro instanceof ErroDeUso) return resposta(erro.status, { erro: erro.message });
    console.error("admin-usuarios:", erro);
    return resposta(500, { erro: "Não foi possível concluir agora. Tente de novo em instantes." });
  }
});
