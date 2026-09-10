import CoreLocation
import Foundation

/// Держит процесс приложения живым, пока Rust-ядро слушает 127.0.0.1 внутри
/// самого приложения. iOS не даёт обычному процессу держать TCP-сервер в фоне,
/// но не приостанавливает приложение с активными обновлениями геопозиции.
///
/// Нужен только для локального режима: в туннельном режиме ядро живёт
/// в отдельном процессе PacketTunnelProvider, который система держит сама.
final class BackgroundKeeper: NSObject {
    static let shared = BackgroundKeeper()

    static let settingsKey = "app.backgroundKeeper"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: settingsKey) as? Bool ?? true
    }

    private let manager = CLLocationManager()
    private(set) var isActive = false

    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    /// Фон удержится только с разрешением «Всегда»: при «При использовании»
    /// iOS отзывает обновления сразу после сворачивания приложения.
    var isAuthorizedForBackground: Bool {
        authorizationStatus == .authorizedAlways
    }

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.distanceFilter = 3000
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestAuthorization() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func activate() {
        guard !isActive, Self.isEnabled else { return }
        requestAuthorization()
        manager.allowsBackgroundLocationUpdates = isAuthorizedForBackground
        manager.startUpdatingLocation()
        isActive = true
    }

    func deactivate() {
        guard isActive else { return }
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        isActive = false
    }
}

extension BackgroundKeeper: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isActive else { return }
        manager.allowsBackgroundLocationUpdates = isAuthorizedForBackground
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        fputs("BackgroundKeeper: \(error.localizedDescription)\n", stderr)
    }
}
