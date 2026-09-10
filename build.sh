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
  sim          iOS Simulator; components default to wd,la,cc,vpn
  lc           LiveContainer; app-only, extensions are not supported
  side         Sideload / Sideloadly / iLoader / TrollStore
  alt          AltStore / SideStore

Components (comma-separated):
  wd           Home Screen Widget
  la           Live Activity
  cc           Control Center widget (iOS 18+)
  vpn          Packet Tunnel / Network Extension
  none         app-only

Options:
  -p, --platform       sim | lc | side | alt
  -c, --components     e.g. wd,la,cc,vpn
      --install        install and launch on the currently booted simulator
      --debug          Debug build (default: Release)
  -h, --help           show this help

Notes:
  - la enables Live Activity and Dynamic Island together.
  - LiveContainer cannot load app extensions; components are disabled for lc.
  - On a free Apple ID, Network Extension and App Groups may not sign.
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
  COMPONENTS="wd,la,cc,vpn"
elif [ -z "$COMPONENTS" ]; then
  COMPONENTS="none"
fi

has_component() {
  case ",$COMPONENTS," in
    *,"$1",*) return 0 ;;
    *) return 1 ;;
  esac
}

OLD_IFS="$IFS"
IFS=","
for COMPONENT in $COMPONENTS; do
  case "$COMPONENT" in
    wd|la|cc|vpn|none) ;;
    *)
      echo "Unknown component: $COMPONENT" >&2
      usage
      exit 2
      ;;
  esac
done
IFS="$OLD_IFS"

WITH_WIDGET=0
WITH_LIVE=0
WITH_CONTROL=0
WITH_VPN=0
has_component wd && WITH_WIDGET=1
has_component la && WITH_LIVE=1
has_component cc && WITH_CONTROL=1
has_component vpn && WITH_VPN=1

case "$PLATFORM" in
  sim)
    SDK="iphonesimulator"
    DESTINATION="generic/platform=iOS Simulator"
    SUFFIX="sim"
    BUNDLE_ID="com.delewer.tgwsproxy.sim"
    ;;
  lc)
    SDK="iphoneos"
    DESTINATION="generic/platform=iOS"
    SUFFIX="lc"
    BUNDLE_ID="com.delewer.tgwsproxy.lc"
    if [ "$WITH_WIDGET$WITH_LIVE$WITH_CONTROL$WITH_VPN" != "0000" ]; then
      echo "warning: LiveContainer cannot load extensions; disabling all components." >&2
      WITH_WIDGET=0; WITH_LIVE=0; WITH_CONTROL=0; WITH_VPN=0
    fi
    ;;
  side)
    SDK="iphoneos"
    DESTINATION="generic/platform=iOS"
    SUFFIX="sideload"
    BUNDLE_ID="com.delewer.tgwsproxy.sideload"
    ;;
  alt)
    SDK="iphoneos"
    DESTINATION="generic/platform=iOS"
    SUFFIX="altstore"
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
SAFE_NAME="$(printf '%s' "$NAME" | tr ',/' '--')"
DD="$ROOT/.build/dynamic/$SAFE_NAME"
PRODUCTS="$DD/Build/Products/${CONFIGURATION}-${SDK}"
APP="$PRODUCTS/TgWsProxy.app"
APP_FLAGS=""
WIDGET_FLAGS=""
ENTITLEMENTS=""

if [ "$WITH_LIVE" -eq 1 ]; then
  APP_FLAGS="$APP_FLAGS TGWS_LIVE_ACTIVITY_AVAILABLE"
  WIDGET_FLAGS="$WIDGET_FLAGS TGWS_LIVE_ACTIVITY_COMPONENT"
fi
if [ "$WITH_WIDGET" -eq 1 ]; then
  APP_FLAGS="$APP_FLAGS TGWS_WIDGET_AVAILABLE"
  WIDGET_FLAGS="$WIDGET_FLAGS TGWS_HOME_WIDGET_COMPONENT"
fi
if [ "$WITH_CONTROL" -eq 1 ]; then
  APP_FLAGS="$APP_FLAGS TGWS_WIDGET_AVAILABLE"
  WIDGET_FLAGS="$WIDGET_FLAGS TGWS_CONTROL_WIDGET_COMPONENT"
fi
if [ "$WITH_VPN" -eq 1 ]; then
  APP_FLAGS="$APP_FLAGS TGWS_TUNNEL_AVAILABLE"
fi

if [ "$WITH_VPN" -eq 1 ] && { [ "$WITH_WIDGET" -eq 1 ] || [ "$WITH_LIVE" -eq 1 ] || [ "$WITH_CONTROL" -eq 1 ]; }; then
  ENTITLEMENTS="ios/TgWsProxy/TgWsProxy.entitlements"
elif [ "$WITH_VPN" -eq 1 ]; then
  ENTITLEMENTS="ios/TgWsProxy/TgWsProxyVPN.entitlements"
elif [ "$WITH_WIDGET" -eq 1 ] || [ "$WITH_LIVE" -eq 1 ] || [ "$WITH_CONTROL" -eq 1 ]; then
  ENTITLEMENTS="ios/TgWsProxy/TgWsProxyWidgets.entitlements"
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

if [ "$WITH_WIDGET" -eq 1 ] || [ "$WITH_LIVE" -eq 1 ] || [ "$WITH_CONTROL" -eq 1 ]; then
  echo ">>> Building StatusWidgets"
  common_xcodebuild \
    -scheme StatusWidgets \
    PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}.widgets" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS="\$(inherited) $WIDGET_FLAGS" \
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
mkdir -p "$APP/PlugIns"
rm -rf "$APP/PlugIns/PacketTunnel.appex" "$APP/PlugIns/StatusWidgets.appex"

if [ "$WITH_VPN" -eq 1 ]; then
  cp -R "$PRODUCTS/PacketTunnel.appex" "$APP/PlugIns/"
fi
if [ "$WITH_WIDGET" -eq 1 ] || [ "$WITH_LIVE" -eq 1 ] || [ "$WITH_CONTROL" -eq 1 ]; then
  cp -R "$PRODUCTS/StatusWidgets.appex" "$APP/PlugIns/"
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
    find "$APP/PlugIns" -mindepth 1 -maxdepth 1 -type d -name '*.appex' -print
  fi
else
  mkdir -p "$OUTPUT_DIR"
  STAGE="$OUTPUT_DIR/.stage-$SAFE_NAME"
  rm -rf "$STAGE"
  mkdir -p "$STAGE/Payload"
  cp -R "$APP" "$STAGE/Payload/"
  IPA="$OUTPUT_DIR/TgWsProxy-${PLATFORM}-${SAFE_NAME#${PLATFORM}-}.ipa"
  rm -f "$IPA"
  (cd "$STAGE" && zip -q -r "$IPA" Payload)
  rm -rf "$STAGE"
  echo "Built IPA: $IPA"
fi
