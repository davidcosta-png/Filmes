@echo off
REM start.bat - delega para start-backend.ps1 que executa a automação completa (hosts, mkcert, npm install, start)
REM Uso: start.bat [JWT_SECRET] [--no-https] [--skip-hosts]

setlocal
set JWT_ARG=%~1nshift
set EXTRA_ARGS=%*

REM Call PowerShell script (it will relaunch as Admin when needed)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-backend.ps1" %JWT_ARG% %EXTRA_ARGS%

endlocal
exit /b 0