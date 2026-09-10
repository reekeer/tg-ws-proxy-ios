import SwiftUI

struct InfoView: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                about
                links
                Text("GPLv3 (ядро) · MIT (оригинал)".tgLoc)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var about: some View {
        VStack(spacing: 10) {
            Image("TelegramIcon")
                .resizable()
                .scaledToFit()
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("TG WS Proxy".tgLoc)
                .font(.title3.bold())
            Text(verbatim: version)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 20)
    }

    private var links: some View {
        VStack(spacing: 0) {
            LinkRow(
                title: "Репозиторий",
                subtitle: "reekeer/tg-ws-proxy-ios",
                systemImage: "iphone",
                url: "https://github.com/reekeer/tg-ws-proxy-ios"
            )
            Divider()
            LinkRow(
                title: "Оригинальный проект",
                subtitle: "Flowseal/tg-ws-proxy",
                systemImage: "shippingbox",
                url: "https://github.com/Flowseal/tg-ws-proxy"
            )
            Divider()
            LinkRow(
                title: "Rust-ядро (Android-форк)",
                subtitle: "amurcanov/tg-ws-proxy-android",
                systemImage: "cpu",
                url: "https://github.com/amurcanov/tg-ws-proxy-android"
            )
            Divider()
            LinkRow(
                title: "FAQ",
                subtitle: "Flowseal/tg-ws-proxy · issue #389",
                systemImage: "questionmark.circle",
                url: "https://github.com/Flowseal/tg-ws-proxy/issues/389"
            )
        }
        .card(padding: 6)
    }
}

private struct LinkRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.callout)
                    .foregroundStyle(Color.tgAccent)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title.tgLoc)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Text(verbatim: subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
