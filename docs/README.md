<h1 align="center">TG WS Proxy iOS (Workflow Fix Fork)</h1>

<h4 align="center">Local MTProto proxy for Telegram on iOS featuring a Rust core, Live Activity, and an embedded Silent Audio sandbox bypass. Built via GitHub Actions.</h4>

<p align="center">
  <a href="../README.md">Русский 🇷🇺</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPLv3-blue?style=for-the-badge&logo=gnu&logoColor=white" alt="GPLv3"></a>
  <img src="https://img.shields.io/badge/iOS-17%2B-black?style=for-the-badge&logo=apple&logoColor=white" alt="iOS 17+">
  <img src="https://img.shields.io/badge/Swift-SwiftUI-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Core-Rust-000000?style=for-the-badge&logo=rust&logoColor=white" alt="Rust">
</p>

---

**TG WS Proxy iOS** runs the Rust version of TG WS Proxy on an iPhone and provides Telegram with a local MTProto endpoint:

```text
Telegram → 127.0.0.1:1443 → Rust TG WS Proxy → WSS / Cloudflare → Telegram DC
```

> [!CAUTION]
> **This is an experimental networking tool. Use it entirely at your own risk. The application has not undergone a security audit.**

---

## 🤖 AI Disclaimer
> [!NOTE]
> All build script fixes, Xcode 16.2+ compiler patches, iOS sandbox bypasses, and CI/CD automation setups in this fork were implemented in close collaboration with the **Gemini AI**. The author is not responsible for any hidden bugs or future breakages.

---

## ⚡ Fork Features (What's Fixed)
This repository fixes critical compilation errors found in the original project under recent Xcode versions (16.2+), removes the breaking `.glassEffect` UI modifier, and adds automated cloud build scripts 
via **GitHub Actions** without requiring a physical Mac computer.
## 📦 Free Apple ID Background Sandbox Bypass (Important!)

In the original project, background execution on a free developer account was impossible because the system VPN (`NetworkExtension`) dropped after 8 seconds due to missing paid signature entitlements.

This fork introduces an **Automated Background Location Engine Patch (CoreLocation)** that completely solves this problem without using clunky audio hacks! When building with the **`-c la`** flag, the script automatically injects a background GPS tracker into the Swift code. To iOS, the app looks like an active navigation tool, which prevents process suspension and allows the Rust core to run indefinitely.

### 🚨 CRITICALLY IMPORTANT CONFIGURATION (INSTRUCTIONS):
To prevent the proxy from sleeping in the background, you must adjust your iOS settings after the first installation:
1. Open the system **Settings** app on your iPhone.
2. Scroll down to the app list and select **TgWsProxy**.
3. Tap on **Location**.
4. **YOU MUST CHANGE THE PERMISSION TO "ALWAYS"!**
*If left on "While Using the App", iOS will freeze the proxy process the exact second you minimize the app or lock your screen.*

### ✨ Advantages of the GPS Fix Over Audio Hacks:
- ✅ **Full Call Stability:** Phone calls and VoIP calls in other apps NO LONGER break the proxy loop because iOS location tracking is entirely separated from the audio system.
- ✅ **Media & Voice Note Stability:** Recording/playing voice messages, "round video notes," and videos in Telegram no longer interrupt the proxy connection.
- ✅ **True Autonomy:** No manual restarts (Stop/Start) required — the background connection stays alive continuously.

### ⚠️ Known Trade-offs:
1. **Battery Drain:** Continuous background GPS tracking combined with the active Rust core will drain your device's battery significantly faster. It is recommended for devices with healthy battery life or while connected to a power source.

---

## 🧬 Origins, Sources and Credits

This project is the result of combining, modifying, and fixing a chain of open-source solutions:

- [Flowseal/tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy) — The original concept, the idea of bypassing restrictions via WebSocket, and the baseline proxy core.
- [amurcanov/tg-ws-proxy-android](https://github.com/amurcanov/tg-ws-proxy-android) — The actively maintained Rust core fork and Android version, used in this project as the upstream repository for automated weekly syncs.
- [reekeer/tg-ws-proxy-ios](https://github.com/reekeer/tg-ws-proxy-ios) — The original native Swift/SwiftUI graphical wrapper and Apple framework integration.
-

---

<p align="center"><sub>Workflow modification and bugfixes prepared by <a href="https://github.com">Adolfsmikler</a></sub></p>
