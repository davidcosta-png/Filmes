@echo off
REM backup-db.bat - wrapper to call the PowerShell backup script
REM Usage: backup-db.bat [outputDir]
setlocalnset OUT=%~1nif "%OUT%"=="" (  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0backup-db.ps1") else (  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0backup-db.ps1" "%OUT%")
endlocalnexit /b 0