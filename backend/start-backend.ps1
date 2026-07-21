<#
PowerShell helper script to install Node (if winget available), install dependencies, create local TLS certs for filmes-series.com using mkcert, map hosts file and start the backend.
Usage (run PowerShell as Admin or the script will ask for elevation):
  .\start-backend.ps1 [-jwtSecret <secret>] [-noHttps] [-skipHosts]

Options:
  -jwtSecret   : optional JWT secret to persist for the current user (setx)
  -noHttps     : do not attempt HTTPS / mkcert (default is to attempt HTTPS)
  -skipHosts   : do not modify hosts file (useful if you don't want to change system hosts)

This script tries to be as automatic as possible on Windows systems with winget available.
#>

param(
  [string]$jwtSecret,
  [switch]$noHttps,
  [switch]$skipHosts
)

function Test-IsAdmin {
  $current = [Security.Principal.WindowsIdentity]::GetCurrent();
  $principal = New-Object Security.Principal.WindowsPrincipal($current);
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Relaunch elevated if not admin and hosts modification / mkcert is desired
if (-not (Test-IsAdmin) -and -not $skipHosts) {
  Write-Host "Requesting elevation (Admin) to be able to edit hosts and install mkcert if necessary..."
  $argList = @()
  if ($jwtSecret) { $argList += "-jwtSecret `"$jwtSecret`"" }
  if ($noHttps) { $argList += "-noHttps" }
  if ($skipHosts) { $argList += "-skipHosts" }
  $args = $argList -join ' '
  Start-Process -FilePath "powershell" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" $args" -Verb RunAs
  exit
}

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

Push-Location -Path $PSScriptRoot

# Optionally modify hosts
if (-not $skipHosts) {
  $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
  $pattern = 'filmes-series.com'
  $has = Select-String -Path $hostsPath -Pattern $pattern -SimpleMatch -ErrorAction SilentlyContinue
  if (-not $has) {
    Write-Host "Adicionando mapeamento 127.0.0.1 filmes-series.com ao hosts file"
    Add-Content -Path $hostsPath -Value "127.0.0.1 filmes-series.com"
  } else { Write-Host "hosts já contém filmes-series.com" }
}

# HTTPS via mkcert (unless user opted out)
$certDir = Join-Path $PSScriptRoot 'certs'
$certPath = ''
$keyPath = ''
if (-not $noHttps) {
  $mkcert = Get-Command mkcert -ErrorAction SilentlyContinue
  if (-not $mkcert) {
    Write-Host "mkcert não encontrado. Tentando instalar mkcert via winget..."
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget) {
      winget install mkcert -e --accept-package-agreements --accept-source-agreements 2>$null
    }
  }
  $mkcert = Get-Command mkcert -ErrorAction SilentlyContinue
  if ($mkcert) {
    if (-not (Test-Path $certDir)) { New-Item -ItemType Directory -Path $certDir | Out-Null }
    $certPath = Join-Path $certDir 'filmes-series.pem'
    $keyPath = Join-Path $certDir 'filmes-series-key.pem'
    Write-Host "Gerando certificado mkcert para filmes-series.com em $certDir"
    & mkcert -install | Out-Null
    & mkcert -cert-file $certPath -key-file $keyPath filmes-series.com | Out-Null
    if (-not (Test-Path $certPath) -or -not (Test-Path $keyPath)) {
      Write-Host "Falha ao gerar certificados com mkcert. Continuando sem HTTPS.";
      $noHttps = $true
    } else {
      Write-Host "Certificados gerados: $certPath (cert), $keyPath (key)"
    }
  } else {
    Write-Host "mkcert não disponível. Continuando sem HTTPS. Para HTTPS local, instale mkcert: https://github.com/FiloSottile/mkcert"
    $noHttps = $true
  }
}

Write-Host "Instalando dependências npm..."
npm install
if ($LASTEXITCODE -ne 0) { Write-Host "npm install falhou."; Pop-Location; exit 1 }

# Persist JWT_SECRET for future sessions if provided
if ($jwtSecret) {
  Write-Host "Configurando variável de ambiente JWT_SECRET (usuário atual)..."
  setx JWT_SECRET $jwtSecret | Out-Null
  $env:JWT_SECRET = $jwtSecret
}

# Set environment variables for HTTPS when available
if (-not $noHttps -and (Test-Path $certPath) -and (Test-Path $keyPath)) {
  Write-Host "Configurando variáveis de ambiente para iniciar o backend com HTTPS local..."
  $env:USE_HTTPS = '1'
  $env:SSL_CERT_PATH = $certPath
  $env:SSL_KEY_PATH = $keyPath
} else {
  Write-Host "Iniciando backend em HTTP (sem HTTPS local)."
}

Write-Host "Iniciando backend (node index.js) em uma janela separada..."
Start-Process -FilePath "node" -ArgumentList "index.js" -WorkingDirectory $PSScriptRoot -WindowStyle Normal
if (-not $noHttps -and (Test-Path $certPath) -and (Test-Path $keyPath)) {
  Write-Host "Se hosts estiver configurado, acesse: https://filmes-series.com:4000"
} else {
  Write-Host "Acesse: http://localhost:4000"
}

Pop-Location
