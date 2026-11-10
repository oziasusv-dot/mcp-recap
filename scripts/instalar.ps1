<#
.SYNOPSIS
  Instala o mcp-recap neste PC e o registra no chat do Claude Desktop.

.DESCRIPTION
  1. Confere o ReCap (decap.exe).        4. Prepara o ambiente Python (uv sync).
  2. Instala o uv, se faltar.            5. Roda o diagnóstico.
  3. Baixa ou atualiza o repositório.    6. Registra o servidor "recap" no Claude Desktop
                                            (com backup e sem tocar nos outros servidores).
  Não exige administrador. Não altera configurações de segurança do Windows.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/rafaelcruzmartins/mcp-recap/main/scripts/instalar.ps1 | iex"

.EXAMPLE
  .\instalar.ps1 -Clientes claude-desktop,claude-code -Branch main
#>
param(
    [string]$Repo = "https://github.com/rafaelcruzmartins/mcp-recap",
    [string]$Branch = "main",
    [string]$Destino = (Join-Path $env:LOCALAPPDATA "mcp-recap\src"),
    [string[]]$Clientes = @("claude-desktop"),
    [switch]$SemConfigurar
)

$ErrorActionPreference = "Stop"
function Passo($t) { Write-Host "`n==> $t" -ForegroundColor Cyan }

# 1. ReCap
Passo "Procurando o Autodesk ReCap"
$decap = Get-ChildItem (Join-Path $env:ProgramFiles "Autodesk\*ReCap*\decap.exe") -ErrorAction SilentlyContinue | Select-Object -First 1
if ($decap) { Write-Host "decap.exe: $($decap.FullName)" }
else { Write-Warning "decap.exe não encontrado. A leitura de projetos funciona, mas importar exige o ReCap Pro instalado (ou RECAP_HOME)." }

# 2. uv
Passo "Verificando o uv"
$uv = (Get-Command uv -ErrorAction SilentlyContinue).Source
if (-not $uv) {
    $local = Join-Path $env:USERPROFILE ".local\bin\uv.exe"
    if (-not (Test-Path $local)) {
        Write-Host "Instalando o uv (instalador oficial da Astral)..."
        powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    }
    $uv = $local
}
if (-not (Test-Path $uv)) { throw "uv não encontrado depois da instalação: $uv" }
& $uv --version

# 3. Código
Passo "Obtendo o mcp-recap ($Branch) em $Destino"
$git = (Get-Command git -ErrorAction SilentlyContinue).Source
if ((Test-Path (Join-Path $Destino ".git")) -and $git) {
    & $git -C $Destino fetch --quiet origin $Branch
    & $git -C $Destino checkout --quiet $Branch
    & $git -C $Destino pull --ff-only --quiet origin $Branch
} else {
    if (Test-Path $Destino) {
        $antigo = "$Destino.old-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Write-Host "Pasta existente sem git; movendo para $antigo"
        Move-Item $Destino $antigo
    }
    New-Item -ItemType Directory -Force (Split-Path $Destino) | Out-Null
    if ($git) {
        & $git clone --quiet --branch $Branch $Repo $Destino
    } else {
        $zip = Join-Path $env:TEMP "mcp-recap-$Branch.zip"
        $tmp = Join-Path $env:TEMP "mcp-recap-extrair-$(Get-Date -Format yyyyMMddHHmmss)"
        Invoke-WebRequest "$Repo/archive/refs/heads/$Branch.zip" -OutFile $zip -UseBasicParsing
        Expand-Archive $zip -DestinationPath $tmp
        $raiz = Get-ChildItem $tmp -Directory | Select-Object -First 1
        Move-Item $raiz.FullName $Destino
        Remove-Item $zip, $tmp -Recurse -Force
    }
}
if (-not (Test-Path (Join-Path $Destino "pyproject.toml"))) { throw "pyproject.toml não encontrado em $Destino" }

# 4. Ambiente
Passo "Preparando o ambiente Python (uv sync)"
& $uv --directory $Destino sync --locked
if ($LASTEXITCODE -ne 0) { throw "uv sync falhou" }

# 5. Diagnóstico
Passo "Diagnóstico"
& $uv --directory $Destino run mcp-recap --diagnose --check-license
if ($LASTEXITCODE -ne 0) { Write-Warning "Diagnóstico indica que a importação não está pronta (veja o JSON acima)." }

# 6. Clientes
if (-not $SemConfigurar) {
    Passo "Registrando o servidor 'recap' em: $($Clientes -join ', ')"
    $cargs = @("--directory", $Destino, "run", "mcp-recap-configurar", "--uv", $uv)
    foreach ($c in $Clientes) { $cargs += @("--client", $c) }
    if ($Clientes -contains "claude-code") { $cargs += "--run" }
    & $uv @cargs
    if ($LASTEXITCODE -ne 0) { throw "O registro nos clientes falhou (veja o JSON acima). Nenhum arquivo inválido foi alterado." }
}

Write-Host "`nPronto. Feche o Claude Desktop pela bandeja do sistema (botão direito > Sair), abra de novo e peça num chat novo:" -ForegroundColor Green
Write-Host '  "verifique a instalação do ReCap com check_recap_installation, incluindo a licença"'
