<#
PowerShell helper script to install Node (if winget available), install dependencies and start the backend.
Usage (PowerShell as Admin may be required for winget install and setx):

# If you want to set a JWT secret during start:
.
#   .\start-backend.ps1 -jwtSecret "uma_chave_forte_aqui"
#
# If Node/npm are already installed this will just run npm install and start the server.
#
# Notes:
# - On Windows emulators you may need to use 10.0.2.2 in the Flutter app to reach localhost from Android emulator.
# - This script uses Start-Process to start node in a detached window.
#
#</#>

param(
  [string]$jwtSecret
)

Write-Host "== Verificando npm/node..."
$npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npm) {
  Write-Host "npm não encontrado. Tentando usar winget para instalar Node.js LTS (se disponível)..."
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if ($winget) {
    Write-Host "Executando: winget install OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements"
    winget install OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) { Write-Host "winget falhou ao instalar Node.js. Por favor instale manualmente em https://nodejs.org/"; exit 1 }
  } else {
    Write-Host "winget não disponível. Por favor instale Node.js LTS manualmente a partir de https://nodejs.org/ e adicione ao PATH.";
    exit 1
  }
} else {
  Write-Host "npm encontrado: $($npm.Path)"
}

if ($jwtSecret) {
  Write-Host "Configurando variável de ambiente JWT_SECRET (usuário atual)..."
  setx JWT_SECRET $jwtSecret | Out-Null
  $env:JWT_SECRET = $jwtSecret
}

Write-Host "Instalando dependências npm..."
Push-Location -Path $PSScriptRoot
npm install
if ($LASTEXITCODE -ne 0) { Write-Host "npm install falhou."; Pop-Location; exit 1 }

Write-Host "Iniciando backend (node index.js) em uma janela separada..."
Start-Process -FilePath "node" -ArgumentList "index.js" -WorkingDirectory $PSScriptRoot -WindowStyle Normal
Write-Host "Backend iniciado. Verifique a saída na nova janela do processo ou abra http://localhost:4000"

Pop-Location

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com> 