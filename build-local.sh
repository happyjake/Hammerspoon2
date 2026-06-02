#!/usr/bin/env bash
#
# Build "Hammerspoon 2" locally, signed with YOUR own Apple Development identity,
# WITHOUT committing your Apple Developer Team ID to this (public) repo.
#
# Signing settings are read from the git-ignored Signing.local.xcconfig. Passing
# them via -xcconfig overrides the repo's committed DEVELOPMENT_TEAM at build time,
# so no personal ID ever lives in a tracked file.
#
# Setup (one time):
#   cp Signing.local.xcconfig.example Signing.local.xcconfig
#   # then edit Signing.local.xcconfig and set DEVELOPMENT_TEAM
#
# Usage:
#   ./build-local.sh                 # build the app
#   ./build-local.sh clean build     # extra xcodebuild args are passed through
set -euo pipefail
cd "$(dirname "$0")"

XCCONFIG="Signing.local.xcconfig"
if [[ ! -f "$XCCONFIG" ]]; then
  echo "error: $XCCONFIG not found." >&2
  echo "  cp Signing.local.xcconfig.example $XCCONFIG" >&2
  echo "  then set DEVELOPMENT_TEAM to your Apple Developer Team ID." >&2
  exit 1
fi

# Default action is a plain build; callers may override with their own args.
if [[ $# -eq 0 ]]; then
  set -- build
fi

exec xcodebuild \
  -target "Hammerspoon 2" \
  -scheme "Development" \
  -destination 'platform=macOS' \
  -xcconfig "$XCCONFIG" \
  "$@"
