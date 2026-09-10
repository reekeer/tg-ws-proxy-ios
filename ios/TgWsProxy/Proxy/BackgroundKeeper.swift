import CoreLocation
import Foundation

final class BackgroundKeeper: NSObject, ObservableObject {
    static let shared = BackgroundKeeper()

    private let manager = CLLocationManager()
    private(set) var isActive = false

    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    var isAuthorizedForBackground: Bool {
        authorizationStatus == .authorizedAlways
    }

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.activityType = .other
        authorizationStatus = manager.authorizationStatus
    }

    func activate() {
        guard !isActive else { return }
        isActive = true
        requestAuthorization()
        applyBackgroundMode()
        manager.startUpdatingLocation()
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    private func requestAuthorization() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    private func applyBackgroundMode() {
        manager.allowsBackgroundLocationUpdates = isAuthorizedForBackground
    }
}

extension BackgroundKeeper: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        guard isActive else { return }
        applyBackgroundMode()
        requestAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .locationUnknown { return }
        fputs("BackgroundKeeper: \(error.localizedDescription)\n", stderr)
    }
}
