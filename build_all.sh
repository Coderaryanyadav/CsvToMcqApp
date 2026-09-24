#!/usr/bin/env bash
# ==============================================================================
# QuizPro - Build All Script (Root Wrapper)
# Forwards execution to scripts/build_all.sh
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/scripts/build_all.sh" "$@"
