// Entrega a chave de assinatura dos APKs somente ao build oficial do GitHub.
//
// Quem chama é a esteira "Verificações Flutter" do ramo main. Ela envia o token
// OIDC que o próprio GitHub assina; aqui conferimos a assinatura do GitHub e
// que o token é deste repositório, do ramo main e deste fluxo de build. Assim
// nenhuma senha precisa ficar guardada no GitHub.
//
// A chave fica no Vault (android_chave_base64, android_chave_senha,
// android_chave_apelido), lida pela função segredo_do_servidor.
import { createClient } from "npm:@supabase/supabase-js@2";
import { createRemoteJWKSet, jwtVerify } from "npm:jose@5";

const EMISSOR = "https://token.actions.githubusercontent.com";
const PUBLICO = "gas-plataforma-assinatura";
const REPOSITORIO = "dasilvagonchoroskie-cpu/gas-plataforma";
const REPOSITORIO_ID = "1417526021";
const DONO_ID = "293395957";
const FLUXO = `${REPOSITORIO}/.github/workflows/validacao.yml@refs/heads/main`;

const chavesGithub = createRemoteJWKSet(new URL(`${EMISSOR}/.well-known/jwks`));

function resposta(status: number, corpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return resposta(405, { erro: "Método não permitido." });

  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  if (!token) return resposta(401, { erro: "Não autorizado." });

  try {
    const { payload } = await jwtVerify(token, chavesGithub, {
      issuer: EMISSOR,
      audience: PUBLICO,
      algorithms: ["RS256"],
    });
    const autorizado = payload.repository === REPOSITORIO &&
      String(payload.repository_id) === REPOSITORIO_ID &&
      String(payload.repository_owner_id) === DONO_ID &&
      payload.ref === "refs/heads/main" &&
      (payload.event_name === "push" || payload.event_name === "workflow_dispatch") &&
      payload.workflow_ref === FLUXO &&
      payload.runner_environment === "github-hosted";
    if (!autorizado) {
      console.warn("assinatura-android: token recusado", {
        repositorio: payload.repository,
        ref: payload.ref,
        evento: payload.event_name,
        fluxo: payload.workflow_ref,
      });
      return resposta(403, { erro: "Build não autorizado." });
    }
  } catch (erro) {
    console.warn("assinatura-android: token inválido", String(erro));
    return resposta(401, { erro: "Não autorizado." });
  }

  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const ler = async (nome: string) => {
    const { data, error } = await admin.rpc("segredo_do_servidor", { p_nome: nome });
    if (error) throw error;
    return typeof data === "string" ? data : "";
  };

  try {
    const [chave, senha, apelido] = await Promise.all([
      ler("android_chave_base64"),
      ler("android_chave_senha"),
      ler("android_chave_apelido"),
    ]);
    if (!chave || !senha || !apelido) return resposta(404, { erro: "Chave não cadastrada." });
    console.info("assinatura-android: chave entregue ao build oficial");
    return resposta(200, { keystore_base64: chave, senha, alias: apelido });
  } catch (erro) {
    console.error("assinatura-android:", erro);
    return resposta(500, { erro: "Não foi possível ler a chave." });
  }
});
