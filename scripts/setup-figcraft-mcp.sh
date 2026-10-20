#!/usr/bin/env bash
# Instala o FigCraft CLI (storytold/figcraft) e configura o MCP do Cursor.
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

ASSET="$(resolve_asset)"
echo "==> FigCraft MCP setup (v${VERSION})"
echo "    asset: $ASSET"
echo "    install: $INSTALL_DIR"
echo "    designs: $DESIGNS_DIR"

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

# Localiza o binário do CLI dentro da pasta extraída
CLI_PATH="$(find "$INSTALL_DIR" -type f \( -name 'figcraft-cli' -o -name 'figcraft-cli.exe' \) 2>/dev/null | head -n 1 || true)"
if [ -z "$CLI_PATH" ]; then
  # AppImage / layouts alternativos
  CLI_PATH="$(find "$INSTALL_DIR" -type f -name 'figcraft' 2>/dev/null | head -n 1 || true)"
fi
if [ -z "$CLI_PATH" ]; then
  echo "Erro: não encontrei figcraft-cli em $INSTALL_DIR" >&2
  find "$INSTALL_DIR" -maxdepth 4 -type f | head -40 >&2
  exit 1
fi

chmod +x "$CLI_PATH" 2>/dev/null || true
ln -sfn "$CLI_PATH" "$BIN_DIR/figcraft-cli"
# Windows Git Bash: também cria .exe link se aplicável
if [[ "$CLI_PATH" == *.exe ]]; then
  ln -sfn "$CLI_PATH" "$BIN_DIR/figcraft-cli.exe" 2>/dev/null || true
fi

echo "==> CLI: $CLI_PATH"
"$CLI_PATH" --version || true

# Caminhos absolutos no mcp.json (Cursor no Desktop)
cat > "$MCP_FILE" <<JSON
{
  "mcpServers": {
    "figcraft": {
      "command": "$CLI_PATH",
      "args": [
        "mcp",
        "--no-system-fonts",
        "--automation-read-root",
        "$DESIGNS_DIR",
        "--automation-write-root",
        "$DESIGNS_DIR"
      ]
    },
    "figcraft-app": {
      "command": "$CLI_PATH",
      "args": ["mcp", "--attach", "7979"]
    }
  }
}
JSON

cat > "$DESIGNS_DIR/README.md" <<'EOF'
# Designs FigCraft

Coloque aqui o arquivo do projeto (ex.: `Manager-Farm-Web.figcraft`).

O MCP do Cursor só lê/escreve nesta pasta (raízes de automação).

## Como obter o arquivo
1. Abra o projeto no FigCraft (app desktop ou exporte do navegador).
2. Salve como `.figcraft` nesta pasta.
3. No chat do Cursor: peç para abrir `designs/SeuArquivo.figcraft` e editar.
EOF

echo
echo "==> MCP gravado em $MCP_FILE"
echo
echo "Próximos passos:"
echo "  1. Coloque o .figcraft do Manager Farm Web em: $DESIGNS_DIR"
echo "  2. Cursor → Settings → Tools & MCP → confirme 'figcraft' Connected"
echo "  3. (Opcional, ao vivo) Inicie o app: figcraft --control 7979"
echo "     e use o servidor MCP 'figcraft-app'"
echo "  4. Peça ao agente: abrir designs/<arquivo>.figcraft e editar"
echo
echo "Obs.: o editor web (figcraft.net) NÃO aceita MCP — use desktop/CLI."
