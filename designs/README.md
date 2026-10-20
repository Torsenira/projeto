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
