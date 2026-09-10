#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

PLATFORM=""
COMPONENTS=""
INSTALL=0
CONFIGURATION="Release"
OUTPUT_DIR="$ROOT/dist"

usage() {
  cat <<'EOF'
TG WS Proxy build tool

Usage:
  ./build.sh -p <platform> [-c <components>] [--install] [--debug]

Platforms:
  sim          iOS Simulator; components default to vpn
  lc           LiveContainer; app-only, extensions are not supported
  side         Sideload / Sideloadly / iLoader / TrollStore
  alt          AltStore / SideStore

Components:
  vpn          Packet Tunnel / Network Extension
  none         app-only; the proxy is held in the background by CoreLocation

Options:
  -p, --platform       sim | lc | side | alt
  -c, --components     vpn | none
      --install        install and launch on the currently booted simulator
      --debug          Debug build (default: Release)
  -h, --help           show this help

Notes:
  - LiveContainer cannot load app extensions; vpn is disabled for lc.
  - On a free Apple ID the Network Extension entitlement usually fails to
    sign; build with -c none for that case.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -p|--platform)
      [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
      PLATFORM="$2"; shift 2 ;;
    -c|--components)
      [ "$#" -ge 2 ] || { echo "Missing value for $1" >&2; exit 2; }
      COMPONENTS="$2"; shift 2 ;;
    --install)
      INSTALL=1; shift ;;
    --debug)
      CONFIGURATION="Debug"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2 ;;
  esac
done

[ -n "$PLATFORM" ] || { usage; exit 2; }

: "${DEVELOPER_DIR:=$(xcode-select -p)}"
if [ -z "$DEVELOPER_DIR" ] || [ "$DEVELOPER_DIR" = "/Library/Developer/CommandLineTools" ]; then
  for CANDIDATE in /Applications/Xcode.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer; do
    if [ -d "$CANDIDATE" ]; then
      DEVELOPER_DIR="$CANDIDATE"
      break
    fi
  done
fi
export DEVELOPER_DIR

if [ -z "$DEVELOPER_DIR" ] || [ ! -d "$DEVELOPER_DIR" ]; then
  echo "Xcode developer directory not found. Run: sudo xcode-select -s /Applications/Xcode.app" >&2
  exit 1
fi

export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:$DEVELOPER_DIR/usr/bin:$PATH"

if [ "$PLATFORM" = "sim" ] && [ -z "$COMPONENTS" ]; then
  COMPONENTS="vpn"
elif [ -z "$COMPONENTS" ]; then
  COMPONENTS="none"
fi

case "$COMPONENTS" in
  vpn) WITH_VPN=1 ;;
  none) WITH_VPN=0 ;;
  *)
    echo "Unknown component: $COMPONENTS" >&2
    usage
    exit 2
    ;;
esac

case "$PLATFORM" in
  sim)
    SDK="iphonesimulator"
    DESTINATION="generic/platform=iOS Simulator"
    BUNDLE_ID="com.delewer.tgwsproxy.sim"
    ;;
  lc)
    SDK="iphoneos"
    DESTINATION="generic/platform=iOS"
    BUNDLE_ID="com.delewer.tgwsproxy.lc"
    if [ "$WITH_VPN" -eq 1 ]; then
      echo "warning: LiveContainer cannot load extensions; disabling vpn." >&2
      WITH_VPN=0
      COMPONENTS="none"
    fi
    ;;
  side)
    SDK="iphoneos"
    DESTINATION="generic/platform=iOS"
    BUNDLE_ID="com.delewer.tgwsproxy.sideload"
    ;;
  alt)
    SDK="iphoneos"
    DESTINATION="generic/platform=iOS"
    BUNDLE_ID="com.delewer.tgwsproxy.altstore"
    ;;
  *)
    echo "Unknown platform: $PLATFORM" >&2
    usage
    exit 2
    ;;
esac

if [ "$INSTALL" -eq 1 ] && [ "$PLATFORM" != "sim" ]; then
  echo "--install is supported only for --platform sim" >&2
  exit 2
fi

NAME="${PLATFORM}-${COMPONENTS}"
DD="$ROOT/.build/dynamic/$NAME"
PRODUCTS="$DD/Build/Products/${CONFIGURATION}-${SDK}"
APP="$PRODUCTS/TgWsProxy.app"
APP_FLAGS=""
ENTITLEMENTS=""

if [ "$WITH_VPN" -eq 1 ]; then
  APP_FLAGS="TGWS_TUNNEL_AVAILABLE"
  ENTITLEMENTS="ios/TgWsProxy/TgWsProxyVPN.entitlements"
fi

echo "TG WS Proxy iOS dynamic build"
echo "  platform:   $PLATFORM ($SDK)"
echo "  components: $COMPONENTS"
echo "  config:     $CONFIGURATION"
echo "  bundle id:  $BUNDLE_ID"
echo "  output:     $DD"
echo "  rust core:  src-wrapper -> libtgwsproxy.a"

common_xcodebuild() {
  xcodebuild \
    -project TgWsProxy.xcodeproj \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DD" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    "$@"
}

if [ "$WITH_VPN" -eq 1 ]; then
  echo ">>> Building PacketTunnel"
  common_xcodebuild \
    -scheme PacketTunnel \
    PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}.tunnel" \
    build
fi

echo ">>> Building app"
if [ -n "$ENTITLEMENTS" ]; then
  common_xcodebuild \
    -scheme TgWsProxy \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS="\$(inherited) $APP_FLAGS" \
    build
else
  common_xcodebuild \
    -scheme TgWsProxy \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS="\$(inherited) $APP_FLAGS" \
    build
fi

[ -d "$APP" ] || { echo "App not found: $APP" >&2; exit 1; }
rm -rf "$APP/PlugIns"

if [ "$WITH_VPN" -eq 1 ]; then
  mkdir -p "$APP/PlugIns"
  cp -R "$PRODUCTS/PacketTunnel.appex" "$APP/PlugIns/"
fi

if [ "$PLATFORM" = "sim" ]; then
  echo "Built simulator app: $APP"
  if [ "$INSTALL" -eq 1 ]; then
    UDID="$(xcrun simctl list devices booted -j | /usr/bin/python3 -c '
import json,sys
d=json.load(sys.stdin)
for devices in d["devices"].values():
    for device in devices:
        if device.get("state") == "Booted":
            print(device["udid"]); raise SystemExit
')"
    [ -n "$UDID" ] || { echo "No booted simulator. Boot one in Device Hub first." >&2; exit 1; }
    echo ">>> Installing on $UDID"
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl install "$UDID" "$APP"
    xcrun simctl launch "$UDID" "$BUNDLE_ID"
    echo "Installed and launched. Embedded extensions:"
    if [ -d "$APP/PlugIns" ]; then
      find "$APP/PlugIns" -mindepth 1 -maxdepth 1 -type d -name '*.appex' -print
    else
      echo "  (none)"
    fi
  fi
else
  mkdir -p "$OUTPUT_DIR"
  STAGE="$OUTPUT_DIR/.stage-$NAME"
  rm -rf "$STAGE"
  mkdir -p "$STAGE/Payload"
  cp -R "$APP" "$STAGE/Payload/"
  if [ "$WITH_VPN" -eq 1 ]; then
    IPA="$OUTPUT_DIR/TgWsProxy-vpn.ipa"
  else
    IPA="$OUTPUT_DIR/TgWsProxy-free.ipa"
  fi
  rm -f "$IPA"
  (cd "$STAGE" && zip -q -r "$IPA" Payload)
  rm -rf "$STAGE"
  echo "Built IPA: $IPA"
fi
