# Backup script for the SQLite DB (Windows PowerShell)
# Usage: .\backup-db.ps1 [outputDir]
param([string]$outputDir)
$base = $PSScriptRoot
$dataDir = Join-Path $base 'data'
$dbFile = Join-Path $dataDir 'users.db'
if (-not (Test-Path $dbFile)) { Write-Host "DB file not found: $dbFile"; exit 1 }
if (-not $outputDir) { $outputDir = Join-Path $dataDir 'backups' }
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir | Out-Null }
$timestamp = (Get-Date).ToString('yyyy-MM-dd_HH-mm-ss')
$dest = Join-Path $outputDir "users-$timestamp.db"
Copy-Item $dbFile $dest -Force
Write-Host "Backup created: $dest"