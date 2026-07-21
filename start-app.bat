@echo off
REM start-app.bat - Fully automated start: starts backend (with hosts/mkcert setup) and then starts Flutter if available.
REM Usage: start-app.bat [JWT_SECRET]

setlocal
set JWT_ARG=%~1

REM Start backend using the new automated script (passes optional JWT secret)necho Starting backend (automated)...
if "%JWT_ARG%"=="" (n  call backend\start.batn) else (n  call backend\start.bat %JWT_ARG%n)

REM Wait for backend readiness (tries health endpoint)necho Waiting for backend to be ready...
set /a RETRIES=0n:waitloopn  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri http://localhost:4000/auth/health -ErrorAction Stop; exit 0 } catch { exit 1 }" >nul 2>nuln  if errorlevel 1 (n    set /a RETRIES+=1n    if %RETRIES% GEQ 30 (n      echo Backend did not respond in time. Proceeding anyway.n    ) else (n      timeout /t 1 >nuln      goto waitloopn    )n  )

REM Check for flutter and start app if availablenwhere flutter >nul 2>nulnif errorlevel 1 (n  echo Flutter not found in PATH. To run the app automatically, install Flutter and re-run this script.n  echo Install: https://docs.flutter.dev/get-started/install/windowsn  echo You can still run the app manually: flutter pub get && flutter runn  pausen  endlocaln  exit /b 0n) else (n  echo Starting Flutter application...n  start "Flutter-Run" cmd /k "cd /d %~dp0 && flutter pub get && flutter run"n)

endlocalnexit /b 0