#!/usr/bin/env bash
# Fails if lib/ or pubspec.yaml contains code that could make network requests.
# See docs.md "Network lockdown" for the full chain of evidence.

set -uo pipefail

LIB_DIR="lib"

if [ ! -d "$LIB_DIR" ]; then
  echo "Error: $LIB_DIR not found. Run from repo root." >&2
  exit 2
fi

patterns=(
  "package:http import|^[[:space:]]*import[[:space:]]+['\"]package:http/"
  "package:dio import|^[[:space:]]*import[[:space:]]+['\"]package:dio/"
  "package:web_socket_channel import|^[[:space:]]*import[[:space:]]+['\"]package:web_socket_channel/"
  "package:grpc import|^[[:space:]]*import[[:space:]]+['\"]package:grpc/"
  "package:graphql import|^[[:space:]]*import[[:space:]]+['\"]package:graphql"
  "dart:io HttpClient|\\bHttpClient\\b"
  "dart:io Socket|\\bSocket\\b"
  "dart:io RawSocket|\\bRawSocket\\b"
  "dart:io ServerSocket|\\bServerSocket\\b"
  "dart:io RawDatagramSocket|\\bRawDatagramSocket\\b"
  "dart:io WebSocket|\\bWebSocket\\b"
)

found=0

for entry in "${patterns[@]}"; do
  label="${entry%%|*}"
  regex="${entry#*|}"
  matches=$(grep -rEn --include='*.dart' \
            --exclude='*.g.dart' --exclude='*.drift.dart' --exclude='*.freezed.dart' \
            "$regex" "$LIB_DIR" 2>/dev/null || true)
  if [ -n "$matches" ]; then
    echo "FAIL: forbidden ($label)"
    echo "$matches" | sed 's/^/    /'
    found=1
  fi
done

forbidden_deps=(http dio web_socket_channel grpc graphql)
for dep in "${forbidden_deps[@]}"; do
  if grep -E "^[[:space:]]+${dep}:[[:space:]]" pubspec.yaml >/dev/null 2>&1; then
    echo "FAIL: forbidden dep in pubspec.yaml: ${dep}"
    grep -E "^[[:space:]]+${dep}:[[:space:]]" pubspec.yaml | sed 's/^/    /'
    found=1
  fi
done

if [ $found -eq 0 ]; then
  echo "OK: no forbidden network code in lib/ or pubspec.yaml."
  exit 0
fi

echo ""
echo "Static no-network check FAILED. See docs.md \"Network lockdown\"."
exit 1
