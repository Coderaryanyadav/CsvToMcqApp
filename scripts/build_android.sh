#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# QuizPro - Android Build Script
# Builds Android Release APK and optional App Bundle (AAB)
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
echo -e "${CYAN}${BOLD}  📦 Building QuizPro for Android...     ${NC}"
echo -e "${CYAN}${BOLD}========================================${NC}"

cd "${ROOT_DIR}"
mkdir -p "${DIST_DIR}"

BUILD_AAB=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --bundle|--aab)
      BUILD_AAB=true
      shift
      ;;
    --clean)
      echo -e "${YELLOW}🧹 Running flutter clean...${NC}"
      flutter clean
      shift
      ;;
    --help|-h)
      echo "Usage: ./scripts/build_android.sh [OPTIONS]"
      echo "Options:"
      echo "  --clean     Clean build cache before building"
      echo "  --aab       Also build Android App Bundle (.aab) for Google Play"
      echo "  --help      Show this help message"
      exit 0
      ;;
  esac
done

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter SDK not found in PATH. Please install Flutter.${NC}"
    exit 1
fi

echo -e "${CYAN}📥 Resolving dependencies (flutter pub get)...${NC}"
flutter pub get

# 1. Build APK
echo -e "${CYAN}🔨 Compiling Android Release APK...${NC}"
flutter build apk --release

APK_SOURCE="${ROOT_DIR}/build/app/outputs/flutter-apk/app-release.apk"
APK_TARGET="${DIST_DIR}/QuizPro-Android.apk"

if [[ -f "${APK_SOURCE}" ]]; then
    cp "${APK_SOURCE}" "${APK_TARGET}"
    APK_SIZE=$(du -h "${APK_TARGET}" | cut -f1)
    echo -e "${GREEN}✅ Android APK built successfully!${NC}"
    echo -e "${GREEN}   Output: ${APK_TARGET} (${APK_SIZE})${NC}"
else
    echo -e "${RED}❌ Failed to locate compiled APK at ${APK_SOURCE}${NC}"
    exit 1
fi

# 2. Build AAB (Optional)
if [[ "${BUILD_AAB}" == "true" ]]; then
    echo -e "${CYAN}🔨 Compiling Android App Bundle (AAB)...${NC}"
    flutter build appbundle --release
    AAB_SOURCE="${ROOT_DIR}/build/app/outputs/bundle/release/app-release.aab"
    AAB_TARGET="${DIST_DIR}/QuizPro-Android.aab"
    if [[ -f "${AAB_SOURCE}" ]]; then
        cp "${AAB_SOURCE}" "${AAB_TARGET}"
        AAB_SIZE=$(du -h "${AAB_TARGET}" | cut -f1)
        echo -e "${GREEN}✅ Android AAB built successfully!${NC}"
        echo -e "${GREEN}   Output: ${AAB_TARGET} (${AAB_SIZE})${NC}"
    fi
fi

echo -e "${GREEN}✨ Android build completed successfully.${NC}\n"
