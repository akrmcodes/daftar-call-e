#!/usr/bin/env bash

set -euo pipefail

keystore_path="${HOME}/.android/debug.keystore"
alias_name="androiddebugkey"
store_password="android"

if [[ -z "${JAVA_HOME:-}" ]] && [[ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi

if [[ -n "${JAVA_HOME:-}" ]] && [[ -x "${JAVA_HOME}/bin/keytool" ]]; then
  export PATH="${JAVA_HOME}/bin:${PATH}"
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool was not found on PATH. Install a JDK and try again." >&2
  exit 1
fi

if [[ ! -f "${keystore_path}" ]]; then
  echo "Debug keystore not found at ${keystore_path}" >&2
  exit 1
fi

sha1_line="$({
  keytool -list -v \
    -alias "${alias_name}" \
    -keystore "${keystore_path}" \
    -storepass "${store_password}" \
    -keypass "${store_password}"
} | awk -F': ' '/SHA1:/ {print $2; exit}')"

if [[ -z "${sha1_line}" ]]; then
  echo "Unable to extract a SHA-1 fingerprint from ${keystore_path}." >&2
  exit 1
fi

echo "Debug SHA-1: ${sha1_line}"
