#!/bin/bash
# Wrapper around codesign that strips provenance xattr first
# Fixes "resource fork, Finder information, or similar detritus not allowed" on macOS Sequoia

for arg in "$@"; do
  if [[ -e "$arg" && ! "$arg" == -* ]]; then
    xattr -cr "$arg" 2>/dev/null || true
  fi
done

/usr/bin/codesign "$@"
