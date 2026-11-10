# Tarefa: conectar o Claude ao Autodesk ReCap (mcp-recap)

Você está rodando no Claude Code, num PC Windows. O usuário já tem o ReCap Pro instalado e ativado. Sua tarefa é instalar o servidor `mcp-recap` e deixá-lo funcionando no Claude Code e no chat do Claude Desktop.

## Regras de execução

- Trabalhe de forma autônoma; execute, verifique e corrija sozinho. Pare só para algo que o usuário precise fazer com as próprias mãos (ex.: entrar na conta do ReCap).
- Use PowerShell, sem privilégios de administrador. Instale tudo no perfil do usuário.
- Não presuma caminhos nem nome de usuário: use `$env:USERPROFILE`, `$env:APPDATA`, `$env:LOCALAPPDATA`, `Get-Command`.
- Antes de editar qualquer configuração existente, faça backup `.bak-AAAAMMDD-HHMMSS` ao lado do original. Não remova outros servidores MCP.
- Não feche nem reinicie o Claude Desktop (você pode estar dentro dele). Ao final, peça ao usuário para reiniciar.
- Não envie nuvens de pontos nem projetos para a internet. Use apenas dados sintéticos nos testes.

## Etapas

### 1. Diagnóstico inicial
Anote: versão do Windows, se `git` e `uv` estão no PATH, e se o ReCap está instalado:

```powershell
Get-ChildItem "$env:ProgramFiles\Autodesk" -Directory | Where-Object Name -match 'ReCap'
Get-ChildItem "$env:ProgramFiles\Autodesk\*ReCap*\decap.exe" -ErrorAction SilentlyContinue
```

Se `decap.exe` não existir, avise o usuário que o ReCap Pro precisa estar instalado e pare.

### 2. Instalar o uv (se faltar)
```powershell
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
& "$env:USERPROFILE\.local\bin\uv.exe" --version
```
Guarde o caminho absoluto do `uv.exe`.

### 3. Baixar o servidor
Pasta sugerida: `$env:LOCALAPPDATA\mcp-recap\src`.
- Se a pasta já existir e for um repositório git deste projeto, rode `git pull`.
- Senão: `git clone https://github.com/rafaelcruzmartins/mcp-recap.git "<pasta>"`.
- Sem git: baixe o ZIP da branch `main` em `https://github.com/rafaelcruzmartins/mcp-recap/archive/refs/heads/main.zip`, extraia e mova o conteúdo para a pasta (o `pyproject.toml` precisa ficar na raiz dela).

### 4. Preparar o ambiente e diagnosticar
```powershell
& $uv --directory "<pasta>" sync
& $uv --directory "<pasta>" run mcp-recap --diagnose --check-license
```
Confira `ready_for_import: true` e `license.state: "valida"`. Se a licença não for válida, peça ao usuário para abrir o ReCap Pro e entrar com a conta licenciada, depois repita. Se o ReCap estiver numa pasta fora do padrão, use `RECAP_HOME` (veja o README).

### 5. Registrar no Claude Code
```powershell
claude mcp remove recap --scope user 2>$null
claude mcp add --scope user recap -- "<uv.exe>" --directory "<pasta>" run mcp-recap
claude mcp list
```

### 6. Registrar no chat do Claude Desktop
Use o gerador do projeto, que faz backup, preserva os outros servidores e grava JSON UTF-8 sem BOM:
```powershell
& $uv --directory "<pasta>" run mcp-recap-configurar --client claude-desktop --uv "<uv.exe>" --dry-run
& $uv --directory "<pasta>" run mcp-recap-configurar --client claude-desktop --uv "<uv.exe>"
```
Ele procura `%APPDATA%\Claude\claude_desktop_config.json` e a variante da Microsoft Store. Se o JSON existente for inválido, ele não altera nada: mostre o erro ao usuário e corrija o arquivo (com backup) antes de repetir.

### 7. Teste
- Rode `& $uv --directory "<pasta>" run pytest tests/test_mcp_stdio.py -q` (testa o protocolo sem precisar do ReCap).
- Se as ferramentas `recap` já aparecem nesta sessão, chame `check_recap_installation` com `check_license=true`. Se não aparecerem, diga ao usuário para abrir uma nova sessão e pedir o teste lá.
- Teste opcional de importação com dado sintético: gere um `.pts` pequeno (uma grade de 20 x 20 pontos) numa pasta temporária nova, importe com `import_scans` para outra pasta nova e acompanhe com `get_job_status` até `succeeded`.

### 8. Relatório final
Em poucas linhas: o que foi instalado e onde, backups criados, resultado do diagnóstico e dos testes, e o que o usuário ainda precisa fazer (reiniciar o Claude Desktop pela bandeja do sistema).
