#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/vendor/tg-ws-proxy-android"
DEST="$ROOT_DIR/src-wrapper"
PATCH="$ROOT_DIR/scripts/patches/ios-ffi.patch"
UPSTREAM_URL="https://github.com/amurcanov/tg-ws-proxy-android.git"
UPSTREAM_REF="${UPSTREAM_REF:-main}"

cd "$ROOT_DIR"

if [ ! -e "$VENDOR_DIR/.git" ]; then
  git submodule update --init --depth 1 vendor/tg-ws-proxy-android
fi

git -C "$VENDOR_DIR" fetch --depth 1 origin "$UPSTREAM_REF"
git -C "$VENDOR_DIR" checkout --detach FETCH_HEAD
COMMIT="$(git -C "$VENDOR_DIR" rev-parse HEAD)"

rm -rf "$DEST/src"
mkdir -p "$DEST/src"
cp "$VENDOR_DIR/Cargo.toml" "$DEST/Cargo.toml"
cp "$VENDOR_DIR/Cargo.lock" "$DEST/Cargo.lock"
cp "$VENDOR_DIR/src/"*.rs "$DEST/src/"

# Патч намеренно минимальный: только функциональные отличия iOS-сборки от
# апстрима. Сначала строгое наложение, затем с допуском по контексту.
apply_ios_patch() {
  if git apply --directory=src-wrapper "$PATCH" 2>/dev/null; then
    return 0
  fi
  if patch -p1 -d "$DEST" --forward --fuzz=3 --dry-run < "$PATCH" >/dev/null 2>&1; then
    patch -p1 -d "$DEST" --forward --fuzz=3 < "$PATCH"
    return 0
  fi
  return 1
}

if ! apply_ios_patch; then
  echo "iOS FFI patch does not apply to upstream $COMMIT." >&2
  echo "Update $PATCH and rerun." >&2
  exit 1
fi

printf '%s\n' "$COMMIT" > "$DEST/UPSTREAM_COMMIT"
printf '%s\n' "$UPSTREAM_URL" > "$DEST/UPSTREAM_URL"

echo "Rust wrapper updated to $COMMIT"
