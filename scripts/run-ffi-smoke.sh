#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/src-wrapper/Cargo.toml"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/.build/ffi-smoke}"

export PATH="$HOME/.cargo/bin:$PATH"

mkdir -p "$BUILD_DIR"

CARGO_TARGET_DIR="$BUILD_DIR/target" cargo rustc \
  --manifest-path "$MANIFEST_PATH" \
  --locked \
  --lib \
  --release \
  -- \
  --crate-type=staticlib

LIBRARY_PATH="$BUILD_DIR/target/release/libtgwsproxy.a"
if [ ! -f "$LIBRARY_PATH" ]; then
  LIBRARY_PATH="$BUILD_DIR/target/release/deps/libtgwsproxy.a"
fi

if [ ! -f "$LIBRARY_PATH" ]; then
  echo "Cargo completed but libtgwsproxy.a was not found." >&2
  exit 1
fi

case "$(uname -s)" in
  Darwin)
    SYSTEM_LIBS="-framework CoreFoundation -framework Security -framework SystemConfiguration -lc++"
    ;;
  *)
    SYSTEM_LIBS="-lpthread -ldl -lm"
    ;;
esac

# shellcheck disable=SC2086
cc -o "$BUILD_DIR/ffi_smoke" "$ROOT_DIR/tests/ffi_smoke.c" "$LIBRARY_PATH" $SYSTEM_LIBS

"$BUILD_DIR/ffi_smoke"
echo "FFI smoke test passed"
