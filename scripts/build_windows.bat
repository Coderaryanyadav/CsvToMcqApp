@echo off
REM ==============================================================================
REM QuizPro - Windows Desktop Batch Build Script
REM ==============================================================================

echo ========================================
echo   Building QuizPro for Windows Desktop
echo ========================================

cd /d "%~dp0\.."

if not exist release_bundles mkdir release_bundles

echo Enabling Windows Desktop...
call flutter config --enable-windows-desktop

echo Resolving dependencies...
call flutter pub get

echo Compiling Windows Release executable...
call flutter build windows --release
if errorlevel 1 (
    echo [ERROR] Windows build failed!
    exit /b 1
)

echo Packaging Windows release bundle...
powershell -Command "if (Test-Path 'build\windows\x64\runner\Release') { Compress-Archive -Path 'build\windows\x64\runner\Release\*' -DestinationPath 'release_bundles\QuizPro-Windows.zip' -Force } else { Compress-Archive -Path 'build\windows\runner\Release\*' -DestinationPath 'release_bundles\QuizPro-Windows.zip' -Force }"

echo [SUCCESS] Windows build completed. Check release_bundles\QuizPro-Windows.zip
