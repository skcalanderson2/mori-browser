#!/bin/bash
# Embed the CEF framework into the app bundle as a *versioned* macOS framework.
#
# CEF ships a flat framework (binary + Libraries/ + Resources/ with no Versions/
# and no top-level Info.plist), which Xcode's code-signing step rejects. We
# reassemble it into the canonical Versions/A layout with the expected symlinks,
# then ad-hoc sign it so the app's deep signature validates.
set -euo pipefail

FW_NAME="Chromium Embedded Framework"
SRC="${SRCROOT}/third_party/cef/Release/${FW_NAME}.framework"
DEST_ROOT="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}"
DEST="${DEST_ROOT}/${FW_NAME}.framework"

if [ ! -d "${SRC}" ]; then
  echo "error: CEF framework not found at ${SRC}" >&2
  exit 1
fi

# Skip the (expensive) ~300MB copy if the embedded binary is already current,
# but still fall through to (re-)sign below — the signing identity can change
# between configurations (Debug Apple Development vs Release Developer ID) even
# when the copied bits are unchanged.
if [ -f "${DEST}/Versions/A/${FW_NAME}" ] && \
   [ "${DEST}/Versions/A/${FW_NAME}" -nt "${SRC}/${FW_NAME}" ]; then
  echo "CEF framework already embedded and current; re-signing only."
else
  echo "Assembling versioned CEF framework -> ${DEST}"
  if [ -e "${DEST}" ]; then
    trash "${DEST}"
  fi
  mkdir -p "${DEST}/Versions/A"

  ditto "${SRC}/${FW_NAME}" "${DEST}/Versions/A/${FW_NAME}"
  ditto "${SRC}/Libraries"  "${DEST}/Versions/A/Libraries"
  ditto "${SRC}/Resources"  "${DEST}/Versions/A/Resources"

  # Canonical framework symlinks.
  ln -sfh A                              "${DEST}/Versions/Current"
  ln -sfh "Versions/Current/${FW_NAME}"  "${DEST}/${FW_NAME}"
  ln -sfh Versions/Current/Libraries     "${DEST}/Libraries"
  ln -sfh Versions/Current/Resources     "${DEST}/Resources"
fi

# Sign the framework with the same identity Xcode is using for the app, so the
# app's deep signature validates (falling back to ad-hoc if none is set). Under
# hardened runtime the framework must also carry the runtime flag.
IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-${CODE_SIGN_IDENTITY:--}}"
SIGN_FLAGS=(--force --sign "${IDENTITY}")
if [ "${ENABLE_HARDENED_RUNTIME:-NO}" = "YES" ]; then
  SIGN_FLAGS+=(--options runtime)
fi
codesign "${SIGN_FLAGS[@]}" "${DEST}" >/dev/null 2>&1 || \
  codesign "${SIGN_FLAGS[@]}" "${DEST}"

echo "CEF framework embedded and signed (${IDENTITY})."
