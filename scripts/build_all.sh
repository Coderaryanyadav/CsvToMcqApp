#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# QuizPro - Master Multi-Platform Build Orchestrator
# Builds Android APK, iOS / IPA, macOS App, and Windows App using separated scripts
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${ROOT_DIR}/release_bundles"

# Formatting colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

START_TIME=$(date +%s)

echo -e "${MAGENTA}${BOLD}======================================================${NC}"
echo -e "${MAGENTA}${BOLD}       🚀 QuizPro Unified Build Pipeline              ${NC}"
echo -e "${MAGENTA}${BOLD}======================================================${NC}"

cd "${ROOT_DIR}"
mkdir -p "${DIST_DIR}"

RUN_TESTS=false
CLEAN_BUILD=false
BUILD_AAB=false
SIGNED_IOS=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --test)
      RUN_TESTS=true
      shift
      ;;
    --clean)
      CLEAN_BUILD=true
      shift
      ;;
    --aab)
      BUILD_AAB=true
      shift
      ;;
    --signed)
      SIGNED_IOS=true
      shift
      ;;
    --help|-h)
      echo "Usage: ./build_all.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --clean       Perform flutter clean before building"
      echo "  --test        Run flutter analyze and flutter test before building"
      echo "  --aab         Build Android App Bundle (.aab) in addition to APK"
      echo "  --signed      Sign iOS IPA with Xcode developer credentials"
      echo "  --help        Show this help message"
      echo ""
      echo "Individual platform scripts located in scripts/:"
      echo "  - ./scripts/build_android.sh"
      echo "  - ./scripts/build_ios.sh"
      echo "  - ./scripts/build_macos.sh"
      echo "  - ./scripts/build_windows.sh"
      exit 0
      ;;
  esac
done

# Pre-flight Check: Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter SDK not found in PATH.${NC}"
    exit 1
fi

FLUTTER_VER=$(flutter --version | head -1)
echo -e "${BLUE}ℹ️  Flutter version: ${FLUTTER_VER}${NC}"
echo -e "${BLUE}ℹ️  Target output directory: ${DIST_DIR}${NC}\n"

if [[ "${CLEAN_BUILD}" == "true" ]]; then
    echo -e "${YELLOW}🧹 Cleaning build directories...${NC}"
    flutter clean
fi

echo -e "${CYAN}📥 Updating project dependencies (flutter pub get)...${NC}"
flutter pub get

# Optional: Run verification tests
if [[ "${RUN_TESTS}" == "true" ]]; then
    echo -e "${CYAN}🔍 Running static analysis (flutter analyze)...${NC}"
    flutter analyze
    echo -e "${CYAN}🧪 Running automated tests (flutter test)...${NC}"
    flutter test
fi

echo ""

# 1. Execute Android Build Script
ANDROID_ARGS=()
if [[ "${BUILD_AAB}" == "true" ]]; then
    ANDROID_ARGS+=("--aab")
fi
"${SCRIPT_DIR}/build_android.sh" "${ANDROID_ARGS[@]}"

# 2. Execute iOS / IPA Build Script (macOS only)
if [[ "$(uname)" == "Darwin" ]]; then
    IOS_ARGS=()
    if [[ "${SIGNED_IOS}" == "true" ]]; then
        IOS_ARGS+=("--signed")
    fi
    "${SCRIPT_DIR}/build_ios.sh" "${IOS_ARGS[@]}"
else
    echo -e "${YELLOW}⚠️  Skipping iOS build (requires macOS).${NC}\n"
fi

# 3. Execute macOS Build Script (macOS only)
if [[ "$(uname)" == "Darwin" ]]; then
    "${SCRIPT_DIR}/build_macos.sh"
else
    echo -e "${YELLOW}⚠️  Skipping macOS build (requires macOS).${NC}\n"
fi

# 4. Execute Windows Build Script
"${SCRIPT_DIR}/build_windows.sh"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Final Summary Dashboard
echo -e "${MAGENTA}${BOLD}======================================================${NC}"
echo -e "${MAGENTA}${BOLD}           🎉 Build Pipeline Complete                 ${NC}"
echo -e "${MAGENTA}${BOLD}======================================================${NC}"
echo -e "${GREEN}⏱️  Total build time: ${DURATION} seconds${NC}"
echo -e "${GREEN}📁 Release bundles available at:${NC} ${DIST_DIR}\n"

if ls "${DIST_DIR}"/* &> /dev/null; then
    echo -e "${BOLD}Generated Artifacts:${NC}"
    for f in "${DIST_DIR}"/*; do
        if [[ -f "$f" ]]; then
            SIZE=$(du -h "$f" | cut -f1)
            FNAME=$(basename "$f")
            echo -e "  📦 ${GREEN}${FNAME}${NC} (${SIZE})"
        fi
    done
fi

echo -e "\n${GREEN}✨ All target builds finished!${NC}"
