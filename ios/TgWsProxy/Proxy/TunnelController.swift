#if TGWS_TUNNEL_AVAILABLE
import Foundation
import NetworkExtension

enum TunnelControllerError: Error {
    case unavailable
    case connectionFailed
    case timedOut
}

final class TunnelController {
    static let shared = TunnelController()
    private var manager: NETunnelProviderManager?

    private var providerBundleID: String {
        (Bundle.main.bundleIdentifier ?? "com.delewer.tgwsproxy") + ".tunnel"
    }

    @discardableResult
    func prepare() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        let mgr = managers.first ?? NETunnelProviderManager()
        manager = mgr
        return mgr
    }

    func start(_ configuration: ProxyConfiguration) async throws {
        let mgr = try await prepare()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = providerBundleID
        proto.serverAddress = "127.0.0.1"
        proto.providerConfiguration = [
            "configuration": (try? JSONEncoder().encode(configuration)) ?? Data()
        ]
        mgr.protocolConfiguration = proto
        mgr.localizedDescription = "TG WS Proxy"
        mgr.isEnabled = true
        try await mgr.saveToPreferences()
        try await mgr.loadFromPreferences()
        guard let session = mgr.connection as? NETunnelProviderSession else {
            throw TunnelControllerError.unavailable
        }
        try session.startTunnel()

        for _ in 0..<40 {
            switch session.status {
            case .connected:
                return
            case .invalid, .disconnected:
                if session.status == .disconnected {
                    try? await Task.sleep(for: .milliseconds(200))
                    continue
                }
                throw TunnelControllerError.connectionFailed
            case .disconnecting:
                throw TunnelControllerError.connectionFailed
            case .connecting, .reasserting:
                try await Task.sleep(for: .milliseconds(200))
            @unknown default:
                throw TunnelControllerError.connectionFailed
            }
        }

        session.stopTunnel()
        throw TunnelControllerError.timedOut
    }

    func stop() {
        (manager?.connection as? NETunnelProviderSession)?.stopTunnel()
    }

    func sendMessage(_ command: String) async -> String? {
        guard let session = manager?.connection as? NETunnelProviderSession,
              let data = command.data(using: .utf8) else { return nil }
        return await withCheckedContinuation { continuation in
            do {
                try session.sendProviderMessage(data) { response in
                    continuation.resume(
                        returning: response.flatMap { String(data: $0, encoding: .utf8) }
                    )
                }
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
#endif
