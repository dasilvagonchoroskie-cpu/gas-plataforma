#!/usr/bin/env bash
# Prepara, corrige o estilo e valida todos os pacotes Flutter do repositório.
#
# Uso: scripts/ci/validar_flutter.sh <arquivo-de-relatorio>
#
# 1. Baixa as dependências de cada pacote.
# 2. Aplica as correções automáticas do Dart (dart fix) e a formatação padrão.
# 3. Roda a análise estática (avisos contam como erro) e os testes.
#
# O relatório em português fica no arquivo indicado. O script termina com erro
# se a análise ou algum teste falhar.
set -uo pipefail

relatorio="$(realpath -m "${1:?informe o arquivo do relatório}")"
raiz="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$raiz"

# Ordem: primeiro os pacotes compartilhados, depois os apps.
pacotes=(packages/nucleo packages/design_system packages/dados apps/cliente apps/painel)

falhas=0
: > "$relatorio"
{
  echo "Relatório da validação Flutter"
  echo "Commit: ${GITHUB_SHA:-local}"
  echo "Data (UTC): $(date -u '+%Y-%m-%d %H:%M')"
  echo "Flutter: $(flutter --version 2>/dev/null | head -1)"
  echo
} >> "$relatorio"

registrar() {
  local titulo="$1"
  shift
  local saida
  saida="$("$@" 2>&1)"
  local codigo=$?
  {
    echo "### $titulo  →  $([[ $codigo -eq 0 ]] && echo OK || echo "FALHOU (código $codigo)")"
    if [[ $codigo -ne 0 ]]; then
      echo "$saida" | tail -n 400
    else
      echo "$saida" | tail -n 15
    fi
    echo
  } >> "$relatorio"
  return $codigo
}

for pasta in "${pacotes[@]}"; do
  echo "::group::Preparando $pasta"
  (
    cd "$pasta" || exit 1
    registrar "$pasta: dependências" flutter pub get || exit 1
    registrar "$pasta: correções automáticas" dart fix --apply || true
    registrar "$pasta: formatação" dart format . || true
  ) || falhas=$((falhas + 1))
  echo "::endgroup::"
done

for pasta in "${pacotes[@]}"; do
  echo "::group::Validando $pasta"
  (
    cd "$pasta" || exit 1
    resultado=0
    registrar "$pasta: análise estática" flutter analyze --fatal-infos --no-pub || resultado=1
    if [[ -d test ]]; then
      registrar "$pasta: testes" flutter test --no-pub || resultado=1
    fi
    exit $resultado
  ) || falhas=$((falhas + 1))
  echo "::endgroup::"
done

{
  echo "======================================"
  if [[ $falhas -eq 0 ]]; then
    echo "RESULTADO: tudo certo (análise e testes passaram em todos os pacotes)."
  else
    echo "RESULTADO: $falhas pacote(s) com problema. Veja as seções marcadas com FALHOU."
  fi
} >> "$relatorio"

cat "$relatorio"
[[ $falhas -eq 0 ]]
