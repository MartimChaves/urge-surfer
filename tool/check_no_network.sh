#!/usr/bin/env bash
# Fails if the app could make a network request after the page has loaded.
# See docs.md "No network" for what this does and does not prove.

set -uo pipefail

files=(index.html styles.css src/*.js)

if [ ! -f index.html ]; then
  echo "Error: index.html not found. Run from repo root." >&2
  exit 2
fi

patterns=(
  "absolute URL|https?://|[\"'(]//[a-zA-Z0-9]"
  "fetch|\\bfetch[[:space:]]*\\("
  "XMLHttpRequest|\\bXMLHttpRequest\\b"
  "WebSocket|\\bWebSocket\\b"
  "EventSource|\\bEventSource\\b"
  "sendBeacon|\\bsendBeacon\\b"
  "RTCPeerConnection|\\bRTCPeerConnection\\b"
  "form submission|<form\\b"
)

found=0
for entry in "${patterns[@]}"; do
  label="${entry%%|*}"
  regex="${entry#*|}"
  matches=$(grep -rEn "$regex" "${files[@]}" 2>/dev/null || true)
  if [ -n "$matches" ]; then
    echo "FAIL: forbidden ($label)"
    echo "$matches" | sed 's/^/    /'
    found=1
  fi
done

if [ $found -eq 0 ]; then
  echo "OK: the app references no remote hosts and no networking APIs."
  exit 0
fi

echo ""
echo "Static no-network check FAILED. See docs.md \"No network\"."
exit 1
