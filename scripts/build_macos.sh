#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# QuizPro - macOS Desktop Build Script
# Builds macOS Release App and compressed ZIP bundle
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
echo -e "${CYAN}${BOLD}  🖥️  Building QuizPro for macOS Desktop...${NC}"
echo -e "${CYAN}${BOLD}========================================${NC}"

cd "${ROOT_DIR}"
mkdir -p "${DIST_DIR}"

# Check OS (macOS builds require macOS)
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}❌ macOS Desktop builds must be run on macOS.${NC}"
    exit 1
fi

# Parse arguments
for arg in "$@"; do
  case $arg in
    --clean)
      echo -e "${YELLOW}🧹 Running flutter clean...${NC}"
      flutter clean
      shift
      ;;
    --help|-h)
      echo "Usage: ./scripts/build_macos.sh [OPTIONS]"
      echo "Options:"
      echo "  --clean     Clean build cache before building"
      echo "  --help      Show this help message"
      exit 0
      ;;
  esac
done

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter SDK not found in PATH.${NC}"
    exit 1
fi

flutter config --enable-macos-desktop &> /dev/null || true

echo -e "${CYAN}📥 Resolving dependencies (flutter pub get)...${NC}"
flutter pub get

echo -e "${CYAN}🔨 Compiling macOS Release Desktop application...${NC}"
flutter build macos --release

MACOS_BUILD_DIR="${ROOT_DIR}/build/macos/Build/Products/Release"
APP_PATH=$(find "${MACOS_BUILD_DIR}" -maxdepth 1 -name "*.app" | head -1)

if [[ -n "${APP_PATH}" && -d "${APP_PATH}" ]]; then
    APP_NAME=$(basename "${APP_PATH}")
    ZIP_TARGET="${DIST_DIR}/QuizPro-macOS.zip"

    echo -e "${CYAN}📦 Compressing ${APP_NAME} into ${ZIP_TARGET}...${NC}"
    cd "${MACOS_BUILD_DIR}"
    zip -q -r "${ZIP_TARGET}" "${APP_NAME}"
    cd "${ROOT_DIR}"

    ZIP_SIZE=$(du -h "${ZIP_TARGET}" | cut -f1)
    echo -e "${GREEN}✅ macOS application built successfully!${NC}"
    echo -e "${GREEN}   App: ${APP_PATH}${NC}"
    echo -e "${GREEN}   Zip: ${ZIP_TARGET} (${ZIP_SIZE})${NC}"
else
    echo -e "${RED}❌ Could not find compiled macOS .app in ${MACOS_BUILD_DIR}${NC}"
    exit 1
fi

echo -e "${GREEN}✨ macOS build completed successfully.${NC}\n"
