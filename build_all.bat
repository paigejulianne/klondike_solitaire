@echo off
setlocal enabledelayedexpansion

rem ============================================================================
rem Rebuilds the web release build.
rem
rem Usage:
rem   build_all.bat            (double-click friendly; pauses at the end)
rem   build_all.bat /silent    (no pause; for scripts/CI)
rem ============================================================================

set "FLUTTER_BIN=C:\src\flutter\bin"
set "PATH=%FLUTTER_BIN%;%PATH%"

cd /d "%~dp0"

echo ============================================================
echo  Klondike Solitaire - build Web
echo ============================================================
echo.

echo Fetching dependencies...
call flutter pub get
if errorlevel 1 goto :fail_deps

echo.
echo === Building Web (release) ===
call flutter build web --release
if errorlevel 1 goto :fail_web

echo.
echo ============================================================
echo  BUILD SUCCEEDED
echo ============================================================
echo Web build: build\web\
goto :end

:fail_deps
echo.
echo FAILED: could not fetch dependencies.
exit /b 1

:fail_web
echo.
echo FAILED: Web build did not succeed.
exit /b 1

:end
if not "%~1"=="/silent" pause
endlocal
