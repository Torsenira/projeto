#!/usr/bin/env bash
# Instala o FigCraft (clone + build) e aponta o MCP do Cursor para ele.
set -euo pipefail

FIGCRAFT_DIR="${FIGCRAFT_DIR:-$HOME/figcraft}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MCP_FILE="$REPO_ROOT/.cursor/mcp.json"

echo "==> FigCraft MCP setup"
echo "    destino: $FIGCRAFT_DIR"

if ! command -v node >/dev/null 2>&1; then
  echo "Erro: Node.js >= 20 é necessário." >&2
  exit 1
fi

NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]")"
if [ "$NODE_MAJOR" -lt 20 ]; then
  echo "Erro: Node.js >= 20 é necessário (encontrado: $(node -v))." >&2
  exit 1
fi

if [ ! -d "$FIGCRAFT_DIR/.git" ]; then
  echo "==> Clonando DivikWu/figcraft..."
  git clone --depth 1 https://github.com/DivikWu/figcraft.git "$FIGCRAFT_DIR"
else
  echo "==> Repositório já existe em $FIGCRAFT_DIR"
fi

echo "==> Instalando dependências e buildando..."
cd "$FIGCRAFT_DIR"
npm install
npm run build

mkdir -p "$REPO_ROOT/.cursor"
# Caminho absoluto: funciona no Windows (Git Bash) e no macOS/Linux.
cat > "$MCP_FILE" << JSON
{
  "mcpServers": {
    "figcraft": {
      "command": "node",
      "args": ["dist/mcp-server/index.js"],
      "cwd": "$FIGCRAFT_DIR"
    }
  }
}
JSON

echo
echo "==> MCP configurado em $MCP_FILE"
echo
echo "Próximos passos no Figma Desktop:"
echo "  1. Plugins → Development → Import plugin from manifest…"
echo "  2. Selecione: $FIGCRAFT_DIR/dist/plugin/manifest.json"
echo "  3. Abra o plugin FigCraft no arquivo do DevLinks"
echo "  4. No Cursor: Settings → Tools & MCP → confirme que 'figcraft' está Connected"
echo "  5. Peça ao agente para rodar a tool 'ping'"
echo
echo "Dica: o MCP oficial do Figma (https://mcp.figma.com/mcp) pode rodar em paralelo."
