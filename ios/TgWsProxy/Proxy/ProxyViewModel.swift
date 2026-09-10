import Foundation
import SwiftUI

@MainActor
final class ProxyViewModel: ObservableObject {
    enum State: Equatable {
        case stopped
        case starting
        case running
        case failed(String)
    }

    @Published private(set) var state: State = .stopped
    @Published private(set) var stats = ProxyStats.empty
    @Published private(set) var traffic: [TrafficSample] = []
    @Published private(set) var cloudflareDomains: [String] = []
    @Published var configuration: ProxyConfiguration {
        didSet { persistConfiguration() }
    }

    private var lastSample: (up: Double, down: Double, at: Date)?
    private static let trafficWindow = 40

    private var statsTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var startAttempt = 0
    private let engine: ProxyEngine = ProxyEngineFactory.make()
    private static let settingsKey = "proxy.configuration.v1"
    private static let maxReconnectAttempts = 3

    private var reconnectEnabled: Bool {
        UserDefaults.standard.object(forKey: "app.reconnect") as? Bool ?? true
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.settingsKey),
           var value = try? JSONDecoder().decode(ProxyConfiguration.self, from: data) {
            value.normalize()
            configuration = value
        } else {
            configuration = ProxyConfiguration()
        }
        reloadCloudflareDomains()
    }

    var isRunning: Bool {
        state == .running
    }

    var statusTitle: String {
        switch state {
        case .stopped: "Не подключено".tgLoc
        case .starting: "Запуск…".tgLoc
        case .running: "Прокси работает".tgLoc
        case .failed: "Ошибка запуска".tgLoc
        }
    }

    var statusDetail: String {
        switch state {
        case .stopped:
            "Локальный MTProto".tgLoc + " · \(configuration.bindAddress):\(configuration.port)"
        case .starting:
            "Поднимаем Rust-ядро и WebSocket-пул".tgLoc
        case .running:
            "Telegram → localhost → WSS → Telegram DC".tgLoc
        case .failed(let message):
            message
        }
    }

    var modeTitle: String { engine.mode.title }

    var diagnosticsContext: String {
        let c = configuration
        let s = stats
        return """
        Состояние: \(isRunning ? "запущен" : "остановлен")
        Режим: \(modeTitle)
        Адрес: \(c.bindAddress):\(c.port)
        Размер пула: \(c.poolSize)
        Cloudflare: \(c.cloudflareEnabled ? "вкл" : "выкл") \(c.cloudflareDomain)
        DC override: \(c.dcAddresses.isEmpty ? "—" : c.dcAddresses)
        Статистика: всего \(s.total), активных \(s.active), ws \(s.webSockets), \
        ↑\(s.uploaded) ↓\(s.downloaded), ошибок \(s.errors)
        """
    }

    var backgroundNote: String {
        if engine.runsInBackground {
            return "Системный VPN-туннель удерживает прокси активным в фоне.".tgLoc
        }
        if BackgroundKeeper.isEnabled {
            if BackgroundKeeper.shared.isAuthorizedForBackground {
                return "Прокси удерживается в фоне через геопозицию.".tgLoc
            }
            return "Чтобы прокси не засыпал, разрешите доступ к геопозиции в режиме «Всегда» в настройках iOS.".tgLoc
        }
        return "Локальный прокси работает, пока приложение открыто. Включите удержание фона в настройках или используйте сборку с VPN-туннелем.".tgLoc
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    func start(isRetry: Bool = false) {
        guard state != .starting, !isRunning else { return }
        if !isRetry { startAttempt = 0 }
        reconnectTask?.cancel()
        state = .starting

        let configuration = configuration
        Task {
            let result = await engine.start(configuration)

            if result == 0 {
                startAttempt = 0
                didStart()
            } else {
                handleStartFailure(result)
            }
        }
    }

    func stop() {
        Task { await stopAndWait() }
    }

    func stopAndWait(notify: Bool = true) async {
        guard state != .stopped else { return }
        let wasRunning = isRunning
        reconnectTask?.cancel()
        reconnectTask = nil
        statsTask?.cancel()
        statsTask = nil
        startAttempt = 0
        state = .stopped
        await engine.stop()
        BackgroundKeeper.shared.deactivate()
        stats = .empty
        traffic = []
        lastSample = nil
        if notify, wasRunning {
            NotificationManager.post(title: "TG WS Proxy", body: "Прокси остановлен")
        }
    }

    func applyConfiguration(
        _ newConfiguration: ProxyConfiguration,
        start requestedStart: Bool?
    ) async {
        let shouldResume = requestedStart ?? isRunning
        if state != .stopped {
            await stopAndWait(notify: false)
        }
        configuration = newConfiguration
        if shouldResume {
            start()
        }
    }

    private func handleStartFailure(_ result: Int32) {
        let message = NativeProxyError.startFailed(result).localizedDescription
        if reconnectEnabled, startAttempt < Self.maxReconnectAttempts {
            startAttempt += 1
            state = .starting
            reconnectTask?.cancel()
            reconnectTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                self?.start(isRetry: true)
            }
        } else {
            didFail(message)
        }
    }

    func telegramURL() -> URL? {
        let secret = "dd" + configuration.secret
        var components = URLComponents()
        components.scheme = "tg"
        components.host = "proxy"
        components.queryItems = [
            URLQueryItem(name: "server", value: configuration.bindAddress),
            URLQueryItem(name: "port", value: String(configuration.port)),
            URLQueryItem(name: "secret", value: secret)
        ]
        return components.url
    }

    func regenerateSecret() {
        guard !isRunning else { return }
        configuration.secret = ProxyConfiguration.makeSecret()
    }

    func reloadCloudflareDomains() {
        cloudflareDomains = NativeProxy.cloudflareDomains()
    }

    func refreshCloudflareDomains() async -> Bool {
        let refreshed = await NativeProxy.refreshCloudflareDomains()
        reloadCloudflareDomains()
        return refreshed
    }

    private func didStart() {
        state = .running
        if !engine.runsInBackground {
            BackgroundKeeper.shared.activate()
        }
        lastSample = nil
        traffic = []
        Haptics.notify(.success)
        NotificationManager.post(title: "TG WS Proxy", body: "Прокси запущен")
        statsTask?.cancel()
        statsTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let s = await self.engine.stats()
                self.stats = s
                self.recordTraffic(s)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func recordTraffic(_ s: ProxyStats) {
        let now = Date()
        if let last = lastSample {
            let dt = max(now.timeIntervalSince(last.at), 0.001)
            let up = max((s.uploadedBytes - last.up) / dt, 0)
            let down = max((s.downloadedBytes - last.down) / dt, 0)
            traffic.append(TrafficSample(time: now, up: up, down: down))
            if traffic.count > Self.trafficWindow {
                traffic.removeFirst(traffic.count - Self.trafficWindow)
            }
        }
        lastSample = (s.uploadedBytes, s.downloadedBytes, now)
    }

    private func didFail(_ message: String) {
        state = .failed(message)
        Haptics.notify(.error)
        NotificationManager.post(title: "TG WS Proxy", body: "Ошибка: \(message)")
    }

    private func persistConfiguration() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.standard.set(data, forKey: Self.settingsKey)
    }
}

struct TrafficSample: Identifiable {
    let id = UUID()
    let time: Date
    let up: Double
    let down: Double
}

struct ProxyStats {
    var uploaded: String
    var downloaded: String
    var active: String
    var webSockets: String
    var total: String
    var tcpFallback: String
    var cloudflare: String
    var errors: String
    var pool: String
    var uploadedBytes: Double
    var downloadedBytes: Double

    static let empty = ProxyStats(raw: "")

    init(rawValue: String) { self = ProxyStats(raw: rawValue) }

    private init(raw: String) {
        uploaded = Self.value(after: "up=", in: raw, fallback: "0 B")
        downloaded = Self.value(after: "down=", in: raw, fallback: "0 B")
        active = Self.value(after: "active=", in: raw, fallback: "0")
        webSockets = Self.value(after: "ws=", in: raw, fallback: "0")
        total = Self.value(after: "total=", in: raw, fallback: "0")
        tcpFallback = Self.value(after: "tcp_fb=", in: raw, fallback: "0")
        cloudflare = Self.value(after: "cf=", in: raw, fallback: "0")
        errors = Self.value(after: "err=", in: raw, fallback: "0")
        pool = Self.value(after: "pool=", in: raw, fallback: "0/0")
        uploadedBytes = Self.bytes(from: Self.value(after: "up=", in: raw, fallback: "0B"))
        downloadedBytes = Self.bytes(from: Self.value(after: "down=", in: raw, fallback: "0B"))
    }

    private static func bytes(from s: String) -> Double {
        let multipliers: [(String, Double)] = [
            ("TB", 1099511627776), ("GB", 1073741824),
            ("MB", 1048576), ("KB", 1024), ("B", 1)
        ]
        for (suffix, mult) in multipliers where s.hasSuffix(suffix) {
            return (Double(s.dropLast(suffix.count)) ?? 0) * mult
        }
        return Double(s) ?? 0
    }

    private static func value(after key: String, in source: String, fallback: String) -> String {
        guard let range = source.range(of: key) else { return fallback }
        let suffix = source[range.upperBound...]
        return suffix.prefix { !$0.isWhitespace }.description
    }
}
