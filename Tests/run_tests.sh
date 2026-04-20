#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_FILE="$SCRIPT_DIR/SmokeTests.swift"
BINARY="/tmp/sideb_smoke_test"

echo "🔨 Compiling smoke tests..."
swiftc -o "$BINARY" "$TEST_FILE" 2>&1

echo "🚀 Running smoke tests..."
echo ""
"$BINARY"

EXIT_CODE=$?
rm -f "$BINARY"
exit $EXIT_CODE
