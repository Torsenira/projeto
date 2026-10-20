#!/usr/bin/env bash
# Instala o FigCraft CLI (storytold/figcraft) e configura o MCP do Cursor.
# Detecta automaticamente Documentos/manager farm/ManagerFarmWeb.
# Uso: bash scripts/setup-figcraft-mcp.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESIGNS_DIR="$REPO_ROOT/designs"
MCP_FILE="$REPO_ROOT/.cursor/mcp.json"
VERSION="${FIGCRAFT_VERSION:-0.8.0}"
INSTALL_DIR="${FIGCRAFT_INSTALL_DIR:-$HOME/.local/share/figcraft}"
BIN_DIR="${FIGCRAFT_BIN_DIR:-$HOME/.local/bin}"
BASE_URL="https://github.com/storytold/figcraft/releases/download/v${VERSION}"

mkdir -p "$DESIGNS_DIR" "$INSTALL_DIR" "$BIN_DIR" "$REPO_ROOT/.cursor"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"

# Pastas locais do Manager Farm Web (Windows/macOS/Linux)
resolve_manager_farm_dirs() {
  local candidates=(
    "$HOME/Documents/manager farm/ManagerFarmWeb"
    "$HOME/Documentos/manager farm/ManagerFarmWeb"
    "$HOME/Documents/Manager farm/ManagerFarmWeb"
    "$HOME/Documentos/Manager farm/ManagerFarmWeb"
    "$HOME/Documents/manager farm/Manager Farm Web"
    "$HOME/Documentos/manager farm/Manager Farm Web"
    "$HOME/OneDrive/Documents/manager farm/ManagerFarmWeb"
    "$HOME/OneDrive/Documentos/manager farm/ManagerFarmWeb"
    "${USERPROFILE:-}/Documents/manager farm/ManagerFarmWeb"
    "${USERPROFILE:-}/Documentos/manager farm/ManagerFarmWeb"
  )
  local found=()
  local c
  for c in "${candidates[@]}"; do
    [ -z "$c" ] && continue
    if [ -d "$c" ] || [ -f "$c" ]; then
      found+=("$c")
    fi
  done
  # Também aceita override explícito
  if [ -n "${MANAGER_FARM_DIR:-}" ]; then
    found+=("$MANAGER_FARM_DIR")
  fi
  printf '%s\n' "${found[@]}"
}

resolve_asset() {
  case "$os" in
    linux)
      case "$arch" in
        x86_64|amd64) echo "figcraft-${VERSION}-linux-x86_64.tar.gz" ;;
        aarch64|arm64) echo "figcraft-${VERSION}-linux-aarch64.tar.gz" ;;
        *) echo "Arquitetura Linux não suportada: $arch" >&2; exit 1 ;;
      esac
      ;;
    darwin)
      echo "figcraft-cli-${VERSION}-macos-universal.zip"
      ;;
    msys*|mingw*|cygwin*)
      echo "figcraft-${VERSION}-windows-x64-portable.zip"
      ;;
    *)
      echo "SO não suportado automaticamente: $os" >&2
      echo "Baixe em https://github.com/storytold/figcraft/releases e aponte .cursor/mcp.json para figcraft-cli." >&2
      exit 1
      ;;
  esac
}

# Resolve CLI real (evita symlink loop em ~/.local/bin)
resolve_existing_cli() {
  local cand
  cand="$(find "$INSTALL_DIR" -type f \( -name 'figcraft-cli' -o -name 'figcraft-cli.exe' \) 2>/dev/null | head -n 1 || true)"
  if [ -n "$cand" ]; then
    echo "$cand"
    return 0
  fi
  cand="$(command -v figcraft-cli 2>/dev/null || true)"
  if [ -n "$cand" ] && [ -f "$cand" ]; then
    # Se for symlink, resolve o alvo final
    if command -v readlink >/dev/null 2>&1; then
      readlink -f "$cand" 2>/dev/null || echo "$cand"
    else
      echo "$cand"
    fi
    return 0
  fi
  return 1
}

EXISTING_CLI="$(resolve_existing_cli || true)"

if [ -n "$EXISTING_CLI" ] && [ -x "$EXISTING_CLI" ] && [ "${FORCE_DOWNLOAD:-0}" != "1" ]; then
  CLI_PATH="$EXISTING_CLI"
  echo "==> Reusando CLI existente: $CLI_PATH"
else
  ASSET="$(resolve_asset)"
  echo "==> FigCraft MCP setup (v${VERSION})"
  echo "    asset: $ASSET"
  echo "    install: $INSTALL_DIR"

  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  ARCHIVE="$TMP/$ASSET"

  echo "==> Baixando $BASE_URL/$ASSET"
  curl -fL --progress-bar -o "$ARCHIVE" "$BASE_URL/$ASSET"

  echo "==> Extraindo..."
  case "$ASSET" in
    *.tar.gz) tar -xzf "$ARCHIVE" -C "$INSTALL_DIR" ;;
    *.zip)
      if command -v unzip >/dev/null 2>&1; then
        unzip -qo "$ARCHIVE" -d "$INSTALL_DIR"
      else
        python3 - "$ARCHIVE" "$INSTALL_DIR" <<'PY'
import sys, zipfile
zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])
PY
      fi
      ;;
  esac

  CLI_PATH="$(find "$INSTALL_DIR" -type f \( -name 'figcraft-cli' -o -name 'figcraft-cli.exe' \) 2>/dev/null | head -n 1 || true)"
  if [ -z "$CLI_PATH" ]; then
    CLI_PATH="$(find "$INSTALL_DIR" -type f -name 'figcraft' 2>/dev/null | head -n 1 || true)"
  fi
  if [ -z "$CLI_PATH" ]; then
    echo "Erro: não encontrei figcraft-cli em $INSTALL_DIR" >&2
    find "$INSTALL_DIR" -maxdepth 4 -type f | head -40 >&2
    exit 1
  fi
fi

chmod +x "$CLI_PATH" 2>/dev/null || true
mkdir -p "$BIN_DIR"
ln -sfn "$CLI_PATH" "$BIN_DIR/figcraft-cli"
if [[ "$CLI_PATH" == *.exe ]]; then
  ln -sfn "$CLI_PATH" "$BIN_DIR/figcraft-cli.exe" 2>/dev/null || true
fi

echo "==> CLI: $CLI_PATH"
"$CLI_PATH" --version || true

# Raízes de automação: designs/ + Documentos/manager farm/ManagerFarmWeb
mapfile -t FARM_DIRS < <(resolve_manager_farm_dirs || true)
READ_ROOTS=("$DESIGNS_DIR")
WRITE_ROOTS=("$DESIGNS_DIR")

for d in "${FARM_DIRS[@]:-}"; do
  [ -z "${d:-}" ] && continue
  # Se for arquivo .figcraft, usa o diretório pai
  if [ -f "$d" ]; then
    d="$(cd "$(dirname "$d")" && pwd)"
  else
    d="$(cd "$d" && pwd)"
  fi
  READ_ROOTS+=("$d")
  WRITE_ROOTS+=("$d")
  echo "==> Manager Farm detectado: $d"
  # Atalho no repo para o Cloud/Desktop enxergar o mesmo lugar
  ln -sfn "$d" "$DESIGNS_DIR/ManagerFarmWeb" 2>/dev/null || true
done

if [ "${#FARM_DIRS[@]}" -eq 0 ]; then
  echo "==> Aviso: pasta ManagerFarmWeb não encontrada em Documentos."
  echo "    Esperado: ~/Documents/manager farm/ManagerFarmWeb"
  echo "    Ou defina MANAGER_FARM_DIR=/caminho/absoluto"
fi

# Monta args do MCP
ARGS_JSON='["mcp", "--no-system-fonts"'
for r in "${READ_ROOTS[@]}"; do
  ARGS_JSON+=", \"--automation-read-root\", \"$r\""
done
for r in "${WRITE_ROOTS[@]}"; do
  ARGS_JSON+=", \"--automation-write-root\", \"$r\""
done
ARGS_JSON+=']'

cat > "$MCP_FILE" <<JSON
{
  "mcpServers": {
    "figcraft": {
      "command": "$CLI_PATH",
      "args": $ARGS_JSON
    },
    "figcraft-app": {
      "command": "$CLI_PATH",
      "args": ["mcp", "--attach", "7979"]
    }
  }
}
JSON

cat > "$DESIGNS_DIR/README.md" <<'EOF'
# Designs FigCraft — Manager Farm Web

Pasta usada pelo MCP do Cursor.

## Onde está o projeto
Caminho local esperado:

- `Documentos/manager farm/ManagerFarmWeb`
- ou `Documents/manager farm/ManagerFarmWeb`

O script `scripts/setup-figcraft-mcp.sh` detecta essa pasta e:
1. libera leitura/escrita no MCP
2. cria o atalho `designs/ManagerFarmWeb` → sua pasta em Documentos

## Cloud Agent
O Cloud Agent **não vê** sua pasta Documentos. Para trabalhar na nuvem, copie o `.figcraft` para cá ou anexe no chat.
EOF

echo
echo "==> MCP gravado em $MCP_FILE"
echo "    read roots: ${READ_ROOTS[*]}"
echo
echo "Próximos passos:"
echo "  1. Cursor → Settings → Tools & MCP → confirme 'figcraft' Connected"
echo "  2. (Opcional ao vivo) figcraft --control 7979 + servidor 'figcraft-app'"
echo "  3. Peça ao agente: abrir o .figcraft de ManagerFarmWeb"
echo
echo "Obs.: o editor web (figcraft.net) NÃO aceita MCP — use desktop/CLI."
