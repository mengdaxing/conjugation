#!/usr/bin/env bash
set -euo pipefail
# Skip's archive step also needs an explicit NDK when using a nonstandard location.
real_skip="$(command -v skip)"
if [[ "${1:-}" == android && "${2:-}" == build && -n "${ANDROID_NDK_HOME:-}" ]]; then
    exec "$real_skip" android build --ndk "$ANDROID_NDK_HOME" "${@:3}"
fi
exec "$real_skip" "$@"
