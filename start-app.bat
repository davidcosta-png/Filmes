@echo off
REM start-app.bat - Fully automated start: starts backend (with hosts/mkcert setup) and then starts Flutter if available.
REM Usage: start-app.bat [JWT_SECRET]

setlocal
set JWT_ARG=%~1

REM Start backend using the new automated script (passes optional JWT secret)
echo Starting backend (automated)...
if "%JWT_ARG%"=="" (
  call backend\start.bat
) else (
  call backend\start.bat %JWT_ARG%
)

REM Wait for backend readiness (tries multiple health URLs)
echo Waiting for backend to be ready...
set /a RETRIES=0
:waitloop
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $urls = @('http://localhost:4000/auth/health','http://127.0.0.1:4000/auth/health','https://filmes-series.com:4000/auth/health','http://filmes-series.com:4000/auth/health'); foreach ($u in $urls) { try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri $u -ErrorAction Stop; if ($r.StatusCode -eq 200) { exit 0 } } catch {} } exit 1 } catch { exit 1 }" >nul 2>nul
if errorlevel 1 (
  set /a RETRIES+=1
  if %RETRIES% GEQ 30 (
    echo Backend did not respond in time. Proceeding anyway.
  ) else (
    timeout /t 1 >nul
    goto waitloop
  )
)

REM Check for flutter and start app if available
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter not found in PATH. To run the app automatically, install Flutter and re-run this script.
  echo Install: https://docs.flutter.dev/get-started/install/windows
  echo You can still run the app manually: flutter pub get && flutter run
  pause
  endlocal
  exit /b 0
) else (
  echo Starting Flutter application...
  start "Flutter-Run" cmd /k "cd /d %~dp0 && flutter pub get && flutter run"
)

endlocal
exit /b 0
