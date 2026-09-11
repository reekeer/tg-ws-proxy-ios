<h1 align="center">TG WS Proxy iOS</h1>

<h4 align="center">A local MTProto proxy for Telegram on iPhone: Rust core, WebSocket transport, and background operation without a paid Apple Developer account.</h4>

<p align="center">
  <a href="../README.md">Русский 🇷🇺</a>
</p>

<p align="center">
  <a href="../LICENSE"><img src="https://img.shields.io/badge/License-GPLv3-blue?style=for-the-badge&logo=gnu&logoColor=white" alt="GPLv3"></a>
  <img src="https://img.shields.io/badge/iOS-16.0--27.0-black?style=for-the-badge&logo=apple&logoColor=white" alt="iOS 16.0-27.0">
  <img src="https://img.shields.io/badge/Swift-SwiftUI-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Core-Rust-000000?style=for-the-badge&logo=rust&logoColor=white" alt="Rust">
</p>

---

**TG WS Proxy iOS** runs an MTProto proxy on the phone itself and hands Telegram a local address:

```text
Telegram → 127.0.0.1:1443 → Rust core → WSS / Cloudflare → Telegram DC
```

Supports **iOS 16.0 – 27.0**.

> [!CAUTION]
> This is an experimental networking tool. Use it at your own risk: the app has not undergone a security audit.

---

## 📱 Screenshots

<p align="center">
  <img src="images/home-idle.png" width="31%" alt="Home screen, proxy stopped">
  <img src="images/home-running.png" width="31%" alt="Home screen, proxy running">
  <img src="images/settings.png" width="31%" alt="Settings">
</p>

<p align="center"><sub>Home screen · running proxy with live stats · settings</sub></p>

---

## 📥 Installation

### 1. Download the file

From the [releases page](https://github.com/reekeer/tg-ws-proxy-ios/releases/latest), which also carries a full comparison:

| File | Who it is for |
|------|---------------|
| `TgWsProxy-free.ipa` | **anyone unsure.** Installs with any Apple ID |
| `TgWsProxy-vpn.ipa` | paid Apple Developer account or TrollStore only — needs the Network Extension entitlement |

### 2. Install it on the iPhone

<details>
<summary><b>Sideloadly</b> — Windows or Mac, over a cable, free Apple ID</summary>

1. Install [Sideloadly](https://sideloadly.io) on the computer. On Windows it asks for iTunes and iCloud from Apple's site, not the ones from the Microsoft Store.
2. Connect the iPhone by cable and trust the computer.
3. Drag the `.ipa` into the Sideloadly window, enter your Apple ID and press Start.
4. With two-factor authentication enabled you need an [app-specific password](https://account.apple.com).

</details>

<details>
<summary><b>iLoader</b> — computer and a cable, an alternative to Sideloadly</summary>

1. Install iLoader on the computer.
2. Connect the iPhone by cable and trust the computer.
3. Point it at the downloaded `.ipa`, sign in with your Apple ID and start the installation.

The interface changes noticeably between versions, so follow the prompts inside the program. The limits are the same as with Sideloadly: free account, 7 days, three apps.

</details>

<details>
<summary><b>AltStore / SideStore</b> — refreshes the signature on its own</summary>

1. Install AltStore following the [instructions on its site](https://altstore.io) — it needs AltServer running on a computer on the same network — or SideStore if no computer will be around.
2. Inside AltStore pick **+** and choose the downloaded `.ipa`.

The upside is that the signature is renewed automatically while the phone shares a network with the computer, so there is no weekly reinstall by hand.

</details>

<details>
<summary><b>TrollStore</b> — permanent, no 7-day expiry</summary>

Works only on vulnerable iOS versions — check yours against the [TrollStore compatibility list](https://ios.cfw.guide/installing-trollstore/). If it fits, open the `.ipa` in TrollStore and install.

The signature never expires, which makes this the only method where the app does not fall off after a week. It is also where `TgWsProxy-vpn.ipa` works.

</details>

<details>
<summary><b>Xcode</b> — build and install it yourself, needs a Mac</summary>

```sh
git clone --recurse-submodules https://github.com/reekeer/tg-ws-proxy-ios
cd tg-ws-proxy-ios
rustup target add aarch64-apple-ios
open TgWsProxy.xcodeproj
```

In Xcode open the **TgWsProxy → Signing & Capabilities** tab, pick your team and change the Bundle Identifier to one of your own — Xcode will not sign somebody else's identifier. Then connect the iPhone, select it in the device list and press Run.

</details>

> [!NOTE]
> On a free Apple ID the signature lasts **7 days**, after which the app stops opening and has to be installed again. No more than three such apps can be on one account at a time.

### 3. Allow background operation

After the first launch open **iOS Settings → TG WS Proxy → Location** and pick **"Always"**.

Without it iOS freezes the proxy seconds after the app is minimised and Telegram falls back to "Connecting…". Location is only there to stop the system from unloading the process — no coordinates are sent anywhere.

If the app was not installed through Xcode, iOS first asks you to trust the certificate: **Settings → General → VPN & Device Management** → your Apple ID → Trust.

### 4. Connect Telegram

Open the app, press the power button and then **"Open in Telegram"** — the proxy is added for you. All that is left is to confirm the connection in Telegram.

---

## ⚙️ How it works

The Rust core runs an MTProto proxy on `127.0.0.1:1443` inside the app. Telegram connects to it like to any other proxy, and the core carries the traffic out over WebSocket — straight to Telegram's servers or through a Cloudflare Worker, falling back to plain TCP when WebSocket is unavailable.

From the outside this looks like ordinary HTTPS to Cloudflare and `*.web.telegram.org`.

To keep the proxy from dying when the app is minimised, it subscribes to location updates: to iOS the process looks like active navigation and is not suspended. The price is noticeably faster battery drain. The `TgWsProxy-vpn.ipa` build uses a system VPN tunnel instead, which iOS keeps alive by itself.

The full walkthrough lives in [ARCHITECTURE.ru.md](ARCHITECTURE.ru.md) (Russian).

---

## 🛠 Building from source

Needs Xcode and Rust with the `aarch64-apple-ios` target:

```sh
./build.sh                  # TgWsProxy-free.ipa
./build.sh --vpn            # TgWsProxy-vpn.ipa
./build.sh --sim --install  # run in the simulator
```

The Rust core comes from [amurcanov/tg-ws-proxy-android](https://github.com/amurcanov/tg-ws-proxy-android) as a submodule and is pulled in automatically once a week by a separate workflow.

---

## 🧬 Origins and credits

- [Flowseal/tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy) — the original idea of bypassing restrictions over WebSocket and the first version of the core.
- [amurcanov/tg-ws-proxy-android](https://github.com/amurcanov/tg-ws-proxy-android) — the Rust core and the Android app, used here as upstream.
- [Adolfsmikler](https://github.com/Adolfsmikler) — background operation on a free Apple ID. Proposed and got working the CoreLocation process hold that replaced the audio hacks, which is what keeps the proxy running after the app is minimised, and set up the cloud IPA builds in GitHub Actions.

---

## 🤖 AI Disclaimer

> [!NOTE]
> Part of the build scripts, the patches for recent Xcode versions and the CI/CD setup were written together with AI models. The authors take no responsibility for hidden bugs, Rust core memory leaks or future breakage.
