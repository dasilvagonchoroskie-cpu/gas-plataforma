// Cadastro de cliente.
//
// Cria o login já confirmado (o Supabase gratuito não envia e-mail de
// confirmação para qualquer endereço) e grava nome e telefone no perfil pelo
// gatilho do banco. O papel é sempre "cliente": esta função nunca cria
// operador nem dono.
import { createClient } from "npm:@supabase/supabase-js@2";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function resposta(status: number, corpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...CORS, "Content-Type": "application/json; charset=utf-8" },
  });
}

function texto(valor: unknown): string {
  return typeof valor === "string" ? valor.trim() : "";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "POST") return resposta(405, { erro: "Método não permitido." });

  let dados: Record<string, unknown>;
  try {
    dados = await req.json();
  } catch {
    return resposta(400, { erro: "Dados inválidos." });
  }

  const nome = texto(dados.nome).replace(/\s+/g, " ");
  const telefone = texto(dados.telefone).replace(/\D/g, "");
  const email = texto(dados.email).toLowerCase();
  const senha = typeof dados.senha === "string" ? dados.senha : "";

  if (nome.length < 2 || nome.length > 80) {
    return resposta(400, { erro: "Informe seu nome completo." });
  }
  if (telefone.length < 10 || telefone.length > 11) {
    return resposta(400, { erro: "Informe o celular com DDD, só números." });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email) || email.length > 254) {
    return resposta(400, { erro: "E-mail inválido." });
  }
  if (senha.length < 8 || senha.length > 72) {
    return resposta(400, { erro: "A senha precisa ter pelo menos 8 caracteres." });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  const { error } = await admin.auth.admin.createUser({
    email,
    password: senha,
    email_confirm: true,
    user_metadata: { nome, telefone },
  });

  if (error) {
    const mensagem = (error.message ?? "").toLowerCase();
    if (error.code === "email_exists" || mensagem.includes("already")) {
      return resposta(409, { erro: "Este e-mail já tem cadastro. Entre com sua senha." });
    }
    if (error.code === "weak_password" || mensagem.includes("password")) {
      return resposta(400, { erro: "Escolha uma senha mais forte, com letras e números." });
    }
    console.error("Falha no cadastro:", error.code, error.message);
    return resposta(500, { erro: "Não foi possível cadastrar agora. Tente de novo em instantes." });
  }

  return resposta(201, { ok: true });
});
