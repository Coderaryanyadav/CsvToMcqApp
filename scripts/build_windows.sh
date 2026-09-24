#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# QuizPro - Windows Desktop Build Script
# Builds Windows Release Executable and compressed ZIP bundle
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/release_bundles"

# Formatting colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${CYAN}${BOLD}========================================${NC}"
echo -e "${CYAN}${BOLD}  🪟 Building QuizPro for Windows...     ${NC}"
echo -e "${CYAN}${BOLD}========================================${NC}"

cd "${ROOT_DIR}"
mkdir -p "${DIST_DIR}"

# Parse arguments
for arg in "$@"; do
  case $arg in
    --clean)
      echo -e "${YELLOW}🧹 Running flutter clean...${NC}"
      flutter clean
      shift
      ;;
    --help|-h)
      echo "Usage: ./scripts/build_windows.sh [OPTIONS]"
      echo "Options:"
      echo "  --clean     Clean build cache before building"
      echo "  --help      Show this help message"
      exit 0
      ;;
  esac
done

OS_TYPE="$(uname -s 2>/dev/null || echo "Unknown")"

case "${OS_TYPE}" in
    CYGWIN*|MINGW*|MSYS*|Windows_NT*)
        IS_WINDOWS=true
        ;;
    *)
        IS_WINDOWS=false
        ;;
esac

if [[ "${IS_WINDOWS}" != "true" ]]; then
    echo -e "${YELLOW}⚠️  Note: Flutter Windows Desktop compilation requires a Windows host with Visual Studio (MSVC toolchain).${NC}"
    echo -e "${CYAN}💡 To build the Windows application:${NC}"
    echo -e "   1. On a Windows machine: run ${BOLD}.\\scripts\\build_windows.ps1${NC} or ${BOLD}.\\scripts\\build_windows.bat${NC}"
    echo -e "   2. In CI/CD: Trigger GitHub Actions workflow (${BOLD}.github/workflows/flutter.yml${NC}) which builds on ${BOLD}windows-latest${NC} automatically.\n"
    exit 0
fi

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter SDK not found in PATH.${NC}"
    exit 1
fi

flutter config --enable-windows-desktop &> /dev/null || true

echo -e "${CYAN}📥 Resolving dependencies (flutter pub get)...${NC}"
flutter pub get

echo -e "${CYAN}🔨 Compiling Windows Release executable...${NC}"
flutter build windows --release

WIN_RELEASE_DIR=""
if [[ -d "${ROOT_DIR}/build/windows/x64/runner/Release" ]]; then
    WIN_RELEASE_DIR="${ROOT_DIR}/build/windows/x64/runner/Release"
elif [[ -d "${ROOT_DIR}/build/windows/runner/Release" ]]; then
    WIN_RELEASE_DIR="${ROOT_DIR}/build/windows/runner/Release"
fi

if [[ -n "${WIN_RELEASE_DIR}" && -d "${WIN_RELEASE_DIR}" ]]; then
    ZIP_TARGET="${DIST_DIR}/QuizPro-Windows.zip"
    echo -e "${CYAN}📦 Compressing Windows bundle into ${ZIP_TARGET}...${NC}"
    
    cd "${WIN_RELEASE_DIR}"
    if command -v zip &> /dev/null; then
        zip -q -r "${ZIP_TARGET}" ./*
    elif command -v powershell &> /dev/null; then
        powershell -Command "Compress-Archive -Path '${WIN_RELEASE_DIR}\\*' -DestinationPath '${ZIP_TARGET}' -Force"
    fi
    cd "${ROOT_DIR}"

    if [[ -f "${ZIP_TARGET}" ]]; then
        ZIP_SIZE=$(du -h "${ZIP_TARGET}" | cut -f1)
        echo -e "${GREEN}✅ Windows application built successfully!${NC}"
        echo -e "${GREEN}   Zip: ${ZIP_TARGET} (${ZIP_SIZE})${NC}"
    fi
else
    echo -e "${RED}❌ Could not locate compiled Windows release files in build/windows${NC}"
    exit 1
fi

echo -e "${GREEN}✨ Windows build completed successfully.${NC}\n"
