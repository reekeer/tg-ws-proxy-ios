<h1 align="center">TG WS Proxy iOS</h1>

<h4 align="center">Локальный MTProto-прокси для Telegram на iPhone: Rust-ядро, WebSocket-транспорт и работа в фоне без платного Apple Developer.</h4>

<p align="center">
  <a href="docs/README.md">English 🌐</a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPLv3-blue?style=for-the-badge&logo=gnu&logoColor=white" alt="GPLv3"></a>
  <img src="https://img.shields.io/badge/iOS-17%2B-black?style=for-the-badge&logo=apple&logoColor=white" alt="iOS 17+">
  <img src="https://img.shields.io/badge/Swift-SwiftUI-F05138?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Core-Rust-000000?style=for-the-badge&logo=rust&logoColor=white" alt="Rust">
</p>

---

**TG WS Proxy iOS** поднимает MTProto-прокси прямо на телефоне и отдаёт Telegram локальный адрес:

```text
Telegram → 127.0.0.1:1443 → Rust-ядро → WSS / Cloudflare → Telegram DC
```

Наружу уходит обычный HTTPS-трафик к Cloudflare и к `*.web.telegram.org`, а не соединение с известным адресом дата-центра Telegram.

> [!CAUTION]
> Это экспериментальный сетевой инструмент. Используйте на свой риск: приложение не проходило аудит безопасности.

---

## ⚙️ Как это работает

### Ядро

Ядро написано на Rust и собирается в статическую библиотеку `libtgwsproxy.a`, которую Swift вызывает через C FFI (`ios/TgWsProxy/Proxy/NativeProxy.swift`). Порядок работы:

1. Ядро биндит TCP-слушатель на `127.0.0.1:1443` и запускает многопоточный `tokio`-рантайм.
2. Telegram открывает соединение и присылает 64-байтный MTProto-handshake; ядро расшифровывает его и определяет целевой дата-центр.
3. Дальше ядро берёт готовое соединение из пула WebSocket или устанавливает новое:
   - прямой WSS к `kws{N}.web.telegram.org`;
   - домен Cloudflare Worker (список обновляется автоматически и кэшируется);
   - TCP fallback на `149.154.x.x:443`, если WebSocket недоступен.
4. Трафик бриджуется в обе стороны с шифрованием MTProto, статистика (соединения, пул, объём, ошибки) отдаётся в интерфейс раз в секунду.

Подключение добавляется в Telegram ссылкой `tg://proxy?server=127.0.0.1&port=1443&secret=dd…` — кнопкой «Открыть в Telegram» на главном экране.

### Два режима

| Режим | Где живёт ядро | Когда используется |
|-------|----------------|--------------------|
| Локальный | внутри процесса приложения | сборка без компонента `vpn`, а также fallback, если туннель не поднялся |
| VPN-туннель | в системном процессе `PacketTunnelProvider` | сборка с компонентом `vpn` и подписанным entitlement Network Extension |

Туннель не маршрутизирует трафик устройства: `includedRoutes` пустой, весь трафик исключён. Он нужен только для того, чтобы iOS держала процесс с ядром живым, а loopback-интерфейс доступен всем процессам на устройстве.

Если entitlement Network Extension не подписался (типичная ситуация для бесплатного Apple ID), приложение само переключается в локальный режим — интерфейс показывает это в статусе.

### Фоновая работа

iOS не даёт обычному приложению держать TCP-сервер в фоне: через несколько секунд после сворачивания процесс приостанавливается, порт `1443` закрывается, и Telegram уходит в «Connecting…».

Чтобы локальный режим переживал сворачивание, приложение подписывается на обновления геопозиции с минимальной точностью (`ios/TgWsProxy/Proxy/BackgroundKeeper.swift`). Для системы это выглядит как активная навигация, и процесс не замораживается. Координаты нигде не сохраняются и никуда не передаются — важен сам факт подписки.

Удержание включается автоматически вместе с прокси в локальном режиме и выключается при остановке. Переключатель — **Настройки → Поведение → «Удерживать прокси в фоне»**.

> [!IMPORTANT]
> После установки откройте **Настройки iOS → TG WS Proxy → Геопозиция** и выберите **«Всегда»**.
> В режиме «При использовании» iOS замораживает процесс сразу после сворачивания приложения.

Плюсы этого способа по сравнению с фоновым аудио: звонки и голосовые сообщения не ломают соединение, потому что геолокация изолирована от аудиосистемы, и ручные перезапуски не нужны. Минус — заметно более быстрый расход батареи.

---

## 📦 Установка и сборка

Готовые IPA собираются в GitHub Actions (`.github/workflows/build.yml`), два варианта:

- `TgWsProxy-free.ipa` — без entitlements, ставится с любым Apple ID, в фоне держится через геопозицию;
- `TgWsProxy-vpn.ipa` — с Network Extension, в фоне держится системным туннелем; нужен профиль с `packet-tunnel-provider`.

Оба варианта прикладываются к каждому релизу — там же разбор, какой выбрать.

Локальная сборка (нужны Xcode и Rust с таргетом `aarch64-apple-ios`):

```sh
./build.sh -p side -c none   # TgWsProxy-free.ipa
./build.sh -p side -c vpn    # TgWsProxy-vpn.ipa
./build.sh -p sim --install  # симулятор
./build.sh -h                # платформы и компоненты
```

Платформы: `sim`, `lc` (LiveContainer), `side` (Sideloadly / iLoader / TrollStore), `alt` (AltStore / SideStore).
Компоненты: `vpn` — Network Extension, `none` — только приложение.

LiveContainer не умеет загружать вложенные расширения, поэтому для платформы `lc` компонент `vpn` отключается автоматически.

Подробный разбор поведения в каждом способе установки — в [docs/ARCHITECTURE.ru.md](docs/ARCHITECTURE.ru.md).

---

## 🔄 Синхронизация ядра

Rust-ядро приходит из [amurcanov/tg-ws-proxy-android](https://github.com/amurcanov/tg-ws-proxy-android) — репозиторий подключён сабмодулем в `vendor/`. Раз в неделю `.github/workflows/upstream-sync.yml` запускает `scripts/sync-rust-upstream.sh`: копирует свежие исходники в `src-wrapper/`, накладывает `scripts/patches/ios-ffi.patch` с отличиями iOS-сборки, проверяет компиляцию под хост и `aarch64-apple-ios`, прогоняет FFI-смоук-тест и открывает pull request.

Запустить то же самое вручную:

```sh
./scripts/sync-rust-upstream.sh
./scripts/run-ffi-smoke.sh
```

---

## 🧬 Происхождение и благодарности

- [Flowseal/tg-ws-proxy](https://github.com/Flowseal/tg-ws-proxy) — исходная идея обхода блокировок через WebSocket и первая версия ядра.
- [amurcanov/tg-ws-proxy-android](https://github.com/amurcanov/tg-ws-proxy-android) — Rust-ядро и Android-версия, используются как upstream.
- [Adolfsmikler](https://github.com/Adolfsmikler) — фоновая работа на бесплатном Apple ID. Предложил и довёл до рабочего состояния удержание процесса через CoreLocation вместо аудио-хаков, благодаря чему прокси остаётся включённым после сворачивания приложения, а также настроил облачную сборку IPA в GitHub Actions.

---

## 🤖 AI Disclaimer

> [!NOTE]
> Часть сборочных скриптов, патчей под свежие версии Xcode и настройка CI/CD писались в соавторстве с нейросетями. За скрытые ошибки, утечки памяти Rust-ядра и будущие поломки авторы ответственности не несут.
