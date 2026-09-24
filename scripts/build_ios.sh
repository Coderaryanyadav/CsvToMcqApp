#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# QuizPro - iOS / IPA Build Script
# Builds iOS Archive, packaged IPA, and Runner.app bundle
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
echo -e "${CYAN}${BOLD}  🍎 Building QuizPro for iOS / IPA...   ${NC}"
echo -e "${CYAN}${BOLD}========================================${NC}"

cd "${ROOT_DIR}"
mkdir -p "${DIST_DIR}"

# Check OS (iOS builds require macOS)
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}❌ iOS / IPA builds must be run on macOS with Xcode installed.${NC}"
    exit 1
fi

NO_CODESIGN=true

# Parse arguments
for arg in "$@"; do
  case $arg in
    --signed|--codesign)
      NO_CODESIGN=false
      shift
      ;;
    --clean)
      echo -e "${YELLOW}🧹 Running flutter clean...${NC}"
      flutter clean
      shift
      ;;
    --help|-h)
      echo "Usage: ./scripts/build_ios.sh [OPTIONS]"
      echo "Options:"
      echo "  --clean       Clean build cache before building"
      echo "  --signed      Perform signed Xcode release build (requires Apple Developer Certs)"
      echo "  --help        Show this help message"
      exit 0
      ;;
  esac
done

# Check Flutter & Xcode
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter SDK not found in PATH.${NC}"
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode command line tools not found. Please install Xcode.${NC}"
    exit 1
fi

echo -e "${CYAN}📥 Resolving dependencies (flutter pub get)...${NC}"
flutter pub get

# Build iOS archive / ipa
if [[ "${NO_CODESIGN}" == "true" ]]; then
    echo -e "${CYAN}🔨 Compiling iOS Release (unsigned archive for packaging)...${NC}"
    flutter build ipa --release --no-codesign
else
    echo -e "${CYAN}🔨 Compiling iOS Release IPA (signed)...${NC}"
    flutter build ipa --release
fi

IPA_TARGET="${DIST_DIR}/QuizPro-iOS.ipa"
ZIP_TARGET="${DIST_DIR}/QuizPro-iOS-App.zip"
ARCHIVE_APP="${ROOT_DIR}/build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app"
EXPORTED_IPA_DIR="${ROOT_DIR}/build/ios/ipa"

# 1. Package IPA
if compgen -G "${EXPORTED_IPA_DIR}/*.ipa" > /dev/null; then
    LATEST_IPA=$(ls -t "${EXPORTED_IPA_DIR}"/*.ipa | head -1)
    cp "${LATEST_IPA}" "${IPA_TARGET}"
    echo -e "${GREEN}✅ Found exported IPA: ${LATEST_IPA}${NC}"
elif [[ -d "${ARCHIVE_APP}" ]]; then
    echo -e "${CYAN}📦 Packaging .ipa from xcarchive App Payload...${NC}"
    TMP_IPA_DIR=$(mktemp -d)
    mkdir -p "${TMP_IPA_DIR}/Payload"
    cp -R "${ARCHIVE_APP}" "${TMP_IPA_DIR}/Payload/"
    
    cd "${TMP_IPA_DIR}"
    zip -q -r "${IPA_TARGET}" Payload
    rm -rf "${TMP_IPA_DIR}"
    cd "${ROOT_DIR}"
fi

# 2. Package ZIP of Runner.app
if [[ -d "${ARCHIVE_APP}" ]]; then
    cd "${ROOT_DIR}/build/ios/archive/Runner.xcarchive/Products/Applications"
    zip -q -r "${ZIP_TARGET}" "Runner.app"
    cd "${ROOT_DIR}"
fi

if [[ -f "${IPA_TARGET}" ]]; then
    IPA_SIZE=$(du -h "${IPA_TARGET}" | cut -f1)
    echo -e "${GREEN}✅ iOS IPA built successfully!${NC}"
    echo -e "${GREEN}   IPA: ${IPA_TARGET} (${IPA_SIZE})${NC}"
    if [[ -f "${ZIP_TARGET}" ]]; then
        ZIP_SIZE=$(du -h "${ZIP_TARGET}" | cut -f1)
        echo -e "${GREEN}   ZIP: ${ZIP_TARGET} (${ZIP_SIZE})${NC}"
    fi
else
    echo -e "${RED}❌ Failed to produce iOS IPA.${NC}"
    exit 1
fi

echo -e "${GREEN}✨ iOS build completed successfully.${NC}\n"
