@echo off
REM start-app.bat - Inicia o backend e tenta iniciar o app Flutter (se flutter estiver no PATH)
REM Uso: start-app.bat [JWT_SECRET]

setlocal
set JWT_ARG=%~1

REM Inicia backend (script backend\start.bat aceita JWT secret opcional)
if "%JWT_ARG%"=="" (
  call backend\start.bat
) else (
  call backend\start.bat %JWT_ARG%
)

REM Aguarda alguns segundos para backend subir
ping -n 4 127.0.0.1 >nul

REM Verifica flutter
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter nao encontrado no PATH. Se voce quiser iniciar o app Flutter automaticamente, instale Flutter e execute este script novamente.
  echo Para instrucoes de instalacao: https://docs.flutter.dev/get-started/install/windows
  echo Você pode iniciar o app manualmente: cd %~dp0 && flutter pub get && flutter run
  pause
  exit /b 0
)

REM Tentativa de rodar o app Flutter (na mesma janela atual para ver logs)
start "Flutter-Run" cmd /k "cd /d %~dp0 && flutter pub get && flutter run"
endlocal
exit /b 0
