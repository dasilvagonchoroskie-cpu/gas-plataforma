#!/usr/bin/env bash
# Cria um banco Postgres descartável, imita o Supabase, aplica todas as
# migrations, carrega o seed e roda os testes pgTAP de supabase/tests.
#
# Uso: scripts/testar_banco_local.sh
# Variáveis opcionais: PGHOST (padrão /tmp), PGPORT (padrão 54329), PGUSER (postgres)
set -euo pipefail

raiz="$(cd "$(dirname "$0")/.." && pwd)"
export PGHOST="${PGHOST:-/tmp}"
export PGPORT="${PGPORT:-54329}"
export PGUSER="${PGUSER:-postgres}"
banco="gas_teste_$$"

psql_banco() { psql -X -q -v ON_ERROR_STOP=1 -d "$banco" "$@"; }

createdb "$banco"
trap 'dropdb --if-exists "$banco" >/dev/null 2>&1 || true' EXIT

psql_banco -f "$raiz/scripts/banco_local/stub_supabase.sql" >/dev/null

for migration in "$raiz"/supabase/migrations/*.sql; do
  echo "Aplicando $(basename "$migration")"
  psql_banco -f "$migration" >/dev/null
done

echo "Carregando seed"
psql_banco -f "$raiz/supabase/seed.sql" >/dev/null

falhas=0
for teste in "$raiz"/supabase/tests/*.sql; do
  echo "Testando $(basename "$teste")"
  saida="$(psql -X -At -v ON_ERROR_STOP=1 -d "$banco" -f "$teste" 2>&1)" || { echo "$saida"; falhas=1; continue; }
  echo "$saida" | grep -E '^(not ok|ok|#|1\.\.)' || true
  if echo "$saida" | grep -qE '^not ok|Looks like you failed|ERROR'; then
    falhas=1
  fi
done

if [[ "$falhas" -ne 0 ]]; then
  echo "FALHOU: há testes com erro."
  exit 1
fi
echo "Todos os testes passaram."
