# ==============================================================================
# QuizPro - Windows Desktop PowerShell Build Script
# ==============================================================================

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$DistDir = Join-Path $RootDir "release_bundles"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  🪟 Building QuizPro for Windows Desktop " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Set-Location $RootDir

if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

# Check Flutter
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Flutter SDK not found in PATH." -ForegroundColor Red
    exit 1
}

Write-Host "🔧 Enabling Windows Desktop support..." -ForegroundColor Cyan
flutter config --enable-windows-desktop

Write-Host "📥 Resolving dependencies (flutter pub get)..." -ForegroundColor Cyan
flutter pub get

Write-Host "🔨 Compiling Windows Release executable..." -ForegroundColor Cyan
flutter build windows --release

$WinReleaseDir = Join-Path $RootDir "build\windows\x64\runner\Release"
if (-not (Test-Path $WinReleaseDir)) {
    $WinReleaseDir = Join-Path $RootDir "build\windows\runner\Release"
}

if (Test-Path $WinReleaseDir) {
    $ZipTarget = Join-Path $DistDir "QuizPro-Windows.zip"
    Write-Host "📦 Compressing Windows bundle into $ZipTarget..." -ForegroundColor Cyan
    
    if (Test-Path $ZipTarget) {
        Remove-Item -Path $ZipTarget -Force
    }
    
    Compress-Archive -Path "$WinReleaseDir\*" -DestinationPath $ZipTarget -Force
    
    $Item = Get-Item $ZipTarget
    $SizeMB = [math]::Round($Item.Length / 1MB, 2)
    Write-Host "✅ Windows application built successfully!" -ForegroundColor Green
    Write-Host "   Zip: $ZipTarget ($SizeMB MB)" -ForegroundColor Green
} else {
    Write-Host "❌ Could not find Windows release directory at $WinReleaseDir" -ForegroundColor Red
    exit 1
}

Write-Host "✨ Windows build completed successfully." -ForegroundColor Green
