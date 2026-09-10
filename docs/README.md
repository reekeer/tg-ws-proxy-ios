<h1 align="center">TG WS Proxy iOS</h1>

<h4 align="center">A local MTProto proxy for Telegram on iPhone: Rust core, WebSocket transport, Live Activity, and background operation without a paid Apple Developer account.</h4>

<p align="center">
  <a href="../README.md">Русский 🇷🇺</a>
</p>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/License-GPLv3-blue?style=for-the-badge&logo=gnu&logoColor=white" alt="GPLv3"></a>
  <img src="https://img.shields.io/badge/iOS-17%2B-black?style=for-the-badge&logo=apple&logoColor=white" alt="iOS 17+">
  <img src="https://img.shields.io/badge/Swift-SwiftUI-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Core-Rust-000000?style=for-the-badge&logo=rust&logoColor=white" alt="Rust">
</p>

---

**TG WS Proxy iOS** runs an MTProto proxy on the phone itself and hands Telegram a local address:

```text
Telegram → 127.0.0.1:1443 → Rust core → WSS / Cloudflare → Telegram DC
```

What leaves the device is ordinary HTTPS traffic to Cloudflare and `*.web.telegram.org`, not a connection to a well-known Telegram data centre address.

> [!CAUTION]
> This is an experimental networking tool. Use it at your own risk: the app has not undergone a security audit.

---

## ⚙️ How it works

### The core

The core is written in Rust and built into a static library, `libtgwsproxy.a`, which Swift calls through a C FFI (`ios/TgWsProxy/Proxy/NativeProxy.swift`):

1. The core binds a TCP listener on `127.0.0.1:1443` and starts a multi-threaded `tokio` runtime.
2. Telegram opens a connection and sends the 64-byte MTProto handshake; the core decrypts it and works out the target data centre.
3. It then takes a ready WebSocket from the pool or opens a new one:
   - a direct WSS connection to `kws{N}.web.telegram.org`;
   - a Cloudflare Worker domain (the list refreshes automatically and is cached);
   - a TCP fallback to `149.154.x.x:443` when WebSocket is unavailable.
4. Traffic is bridged both ways with MTProto encryption, and statistics (connections, pool, volume, errors) are pushed to the UI once per second.

The proxy is added to Telegram through a `tg://proxy?server=127.0.0.1&port=1443&secret=dd…` link — the "Open in Telegram" button on the main screen.

### Two modes

| Mode | Where the core lives | When it is used |
|------|----------------------|-----------------|
| Local | inside the app process | builds without the `vpn` component, and as a fallback when the tunnel fails to start |
| VPN tunnel | in the system `PacketTunnelProvider` process | builds with the `vpn` component and a signed Network Extension entitlement |

The tunnel does not route device traffic: `includedRoutes` is empty and everything is excluded. It exists only so iOS keeps the process holding the core alive, and the loopback interface is shared by every process on the device.

If the Network Extension entitlement fails to sign — the usual case with a free Apple ID — the app switches to local mode on its own and says so in the status line.

### Background operation

iOS does not let an ordinary app hold a TCP server in the background: a few seconds after the app is minimised the process is suspended, port `1443` closes, and Telegram falls back to "Connecting…".

To make local mode survive backgrounding, the app subscribes to coarse location updates (`ios/TgWsProxy/Proxy/BackgroundKeeper.swift`). To the system this looks like active navigation, so the process is not frozen. No coordinates are stored or transmitted anywhere — only the subscription itself matters.

The hold turns on together with the proxy in local mode and turns off when it stops. The switch is under **Settings → Behaviour → "Keep the proxy alive in the background"**.

> [!IMPORTANT]
> After installing, open **iOS Settings → TG WS Proxy → Location** and pick **"Always"**.
> With "While Using the App", iOS freezes the process the moment the app is minimised.

Compared with background audio, this approach keeps the connection through phone calls and voice messages, because location is isolated from the audio system, and it needs no manual restarts. The trade-off is noticeably faster battery drain.

---

## 📦 Installing and building

Ready-made IPAs are built in GitHub Actions (`.github/workflows/build.yml`) in two variants:

- `tg-ws-proxy-sideload-free` — no entitlements, installs with any Apple ID, stays alive in the background through location;
- `tg-ws-proxy-sideload-full` — widgets, Live Activity, Control Center and Network Extension; needs a profile with App Groups and Network Extension.

Local builds (Xcode plus Rust with the `aarch64-apple-ios` target):

```sh
./build.sh -p side -c none          # sideload, app only
./build.sh -p side -c wd,la,cc,vpn  # sideload with every component
./build.sh -p sim --install         # simulator
./build.sh -h                       # platforms and components
```

Platforms: `sim`, `lc` (LiveContainer), `side` (Sideloadly / iLoader / TrollStore), `alt` (AltStore / SideStore).
Components: `wd` — widget, `la` — Live Activity, `cc` — Control Center, `vpn` — Network Extension, `none` — app only.

LiveContainer cannot load embedded extensions, so components are disabled automatically for the `lc` platform.

A detailed walkthrough of every installation method lives in [ARCHITECTURE.ru.md](ARCHITECTURE.ru.md).

---

## 🔄 Core synchronisation

The Rust core comes from [amurcanov/tg-ws-proxy-android](https://github.com/amurcanov/tg-ws-proxy-android), wired in as a submodule under `vendor/`. Once a week `.github/workflows/upstream-sync.yml` runs `scripts/sync-rust-upstream.sh`: it copies fresh sources into `src-wrapper/`, applies `scripts/patches/ios-ffi.patch` with the iOS-specific differences, checks the build for the host and for `aarch64-apple-ios`, runs the FFI smoke test, and opens a pull request.

The same thing by hand:

```sh
./scripts/sync-rust-upstream.sh
./scripts/run-ffi-smoke.sh
```

---

## 🧬 Origins and credits

- [Flowseal/tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy) — the original idea of bypassing restrictions over WebSocket and the first version of the core.
- [amurcanov/tg-ws-proxy-android](https://github.com/amurcanov/tg-ws-proxy-android) — the Rust core and the Android app, used here as upstream.
- [Adolfsmikler](https://github.com/Adolfsmikler) — background operation on a free Apple ID. Proposed and got working the CoreLocation process hold that replaced the audio hacks, which is what keeps the proxy running after the app is minimised, and set up the cloud IPA builds in GitHub Actions.

---

## 🤖 AI Disclaimer

> [!NOTE]
> Part of the build scripts, the patches for recent Xcode versions and the CI/CD setup were written together with AI models. The authors take no responsibility for hidden bugs, Rust core memory leaks or future breakage.
