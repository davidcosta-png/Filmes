@echo off
REM start.bat - instala dependências (se necessário) e inicia o backend em uma nova janela
REM Uso: start.bat [JWT_SECRET]

setlocal
set JWT_ARG=%~1

REM Verifica npm
where npm >nul 2>nul
if errorlevel 1 (
  echo npm nao encontrado no PATH. Por favor instale Node.js (inclui npm) e execute este script novamente.
  echo https://nodejs.org/
  pause
  exit /b 1
)

if "%%JWT_ARG%%"=="" (
  echo Iniciando backend sem JWT_SECRET customizado (usar valor padrao de desenvolvimento)...
  start "Stream-Backend" cmd /k "cd /d %~dp0 && npm install && node index.js"
) else (
  echo Iniciando backend com JWT_SECRET fornecido (na sessao atual)...
  REM Seta JWT_SECRET so para a sessao do processo que sera iniciado
  start "Stream-Backend" cmd /k "cd /d %~dp0 && set JWT_SECRET=%JWT_ARG% && npm install && node index.js"
)
endlocal
exit /b 0
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com> 