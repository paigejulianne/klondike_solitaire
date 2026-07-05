@echo off
setlocal enabledelayedexpansion

rem ============================================================================
rem Rebuilds the Windows desktop app and the Android release APK.
rem
rem Usage:
rem   build_all.bat            (double-click friendly; pauses at the end)
rem   build_all.bat /silent    (no pause; for scripts/CI)
rem ============================================================================

set "FLUTTER_BIN=C:\src\flutter\bin"
set "ANDROID_HOME=%LOCALAPPDATA%\Android\sdk"
set "JAVA_HOME=%LOCALAPPDATA%\Programs\Android Studio\jbr"
set "PATH=%FLUTTER_BIN%;%PATH%"

cd /d "%~dp0"

echo ============================================================
echo  Klondike Solitaire - build Windows + Android
echo ============================================================
echo.

rem Close a running instance of the app first - on Windows, Gradle/CMake
rem builds fail with "Unable to delete directory" if a previous build's
rem exe (or a stray Gradle daemon) is still holding files open.
echo Closing any running instance of the app...
taskkill /IM klondike_solitaire.exe /F >nul 2>&1

echo Stopping any Gradle daemons...
if exist "android\gradlew.bat" (
    pushd android
    call gradlew.bat --stop >nul 2>&1
    popd
)

echo Fetching dependencies...
call flutter pub get
if errorlevel 1 goto :fail_deps

echo.
echo === Building Windows (release) ===
call :build_windows
if errorlevel 1 goto :fail_windows

echo.
echo === Building Web (release) ===
call :build_web
if errorlevel 1 goto :fail_web

echo.
echo === Building Android APK (release) ===
call :build_android
if errorlevel 1 goto :fail_android

echo.
echo ============================================================
echo  BUILD SUCCEEDED
echo ============================================================
echo Windows exe: build\windows\x64\runner\Release\klondike_solitaire.exe
echo Web build:   build\web\
echo Android APK: build\app\outputs\flutter-apk\app-release.apk
goto :end

rem ----------------------------------------------------------------------
rem Web build
rem ----------------------------------------------------------------------
:build_web
call flutter build web --release
if not errorlevel 1 exit /b 0
exit /b 1

rem ----------------------------------------------------------------------
rem Windows build, with one retry if a file lock breaks the clean step.
rem ----------------------------------------------------------------------
:build_windows
call flutter build windows --release
if not errorlevel 1 exit /b 0

echo Windows build failed - retrying after clearing locks...
taskkill /IM klondike_solitaire.exe /F >nul 2>&1
timeout /t 2 /nobreak >nul
call flutter build windows --release
if not errorlevel 1 exit /b 0
exit /b 1

rem ----------------------------------------------------------------------
rem Android build, with up to 2 retries clearing Gradle's locked
rem intermediates directories (a recurring Windows-only Gradle issue).
rem ----------------------------------------------------------------------
:build_android
set ANDROID_RETRY=0

:build_android_attempt
call flutter build apk --release
if not errorlevel 1 exit /b 0

set /a ANDROID_RETRY+=1
if !ANDROID_RETRY! GEQ 3 exit /b 1

echo Android build failed - retrying after clearing locks (attempt !ANDROID_RETRY!)...
rmdir /s /q "build\app\intermediates" >nul 2>&1
rmdir /s /q "build\app\outputs\apk" >nul 2>&1
timeout /t 2 /nobreak >nul
goto :build_android_attempt

:fail_deps
echo.
echo FAILED: could not fetch dependencies.
exit /b 1

:fail_windows
echo.
echo FAILED: Windows build did not succeed after retry.
exit /b 1

:fail_web
echo.
echo FAILED: Web build did not succeed.
exit /b 1

:fail_android
echo.
echo FAILED: Android build did not succeed after retries.
exit /b 1

:end
if not "%~1"=="/silent" pause
endlocal
