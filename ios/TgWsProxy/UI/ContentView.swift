import SwiftUI
import Charts
import UIKit

enum AppTab: CaseIterable {
    case home, settings, logs, info

    var title: String {
        switch self {
        case .home: "Главная".tgLoc
        case .settings: "Настройки".tgLoc
        case .logs: "Логи".tgLoc
        case .info: "Информация".tgLoc
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .settings: "slider.horizontal.3"
        case .logs: "doc.text.fill"
        case .info: "info.circle.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var proxy: ProxyViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var tab: AppTab = {
        switch ProcessInfo.processInfo.environment["TGWS_TAB"] {
        case "settings": return .settings
        case "logs": return .logs
        case "info": return .info
        default: return .home
        }
    }()
    @State private var menuOpen = ProcessInfo.processInfo.environment["TGWS_MENU"] == "1"

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppBackground(active: proxy.isRunning)

            VStack(spacing: 12) {
                header
                Group {
                    switch tab {
                    case .home: HomeView()
                    case .settings: SettingsView()
                    case .logs: LogsTabView()
                    case .info: InfoView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 8)

            if menuOpen {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.snappy) { menuOpen = false } }
            }

            FloatingNavMenu(selection: $tab, isOpen: $menuOpen)
                .padding(.trailing, 18)
                .padding(.bottom, 24)
        }
        .tint(.tgAccent)
        .task {
            LogStore.shared.startCapturing()
            let envStart = ProcessInfo.processInfo.environment["TGWS_AUTOSTART"] == "1"
            if (envStart || settings.autoStart), !proxy.isRunning {
                proxy.start()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(tab.title)
                .font(.title2.bold())
            Spacer()
        }
        .animation(.snappy, value: tab)
        .padding(.horizontal, 20)
    }

}

private struct FloatingNavMenu: View {
    @Binding var selection: AppTab
    @Binding var isOpen: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if isOpen {
                VStack(spacing: 2) {
                    ForEach(AppTab.allCases, id: \.self) { item in
                        row(item)
                        if item != AppTab.allCases.last {
                            Divider().opacity(0.4)
                        }
                    }
                }
                .padding(6)
                .frame(width: 220)
                .card(padding: 6, cornerRadius: 20)
                .transition(
                    .scale(scale: 0.88, anchor: .bottomTrailing).combined(with: .opacity)
                )
            }

            Button {
                Haptics.impact(.medium)
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                    isOpen.toggle()
                }
            } label: {
                Image(systemName: isOpen ? "xmark" : selection.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.tgAccent))
                    .shadow(color: Color.tgAccent.opacity(0.4), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
        }
    }

    private func row(_ item: AppTab) -> some View {
        let selected = item == selection
        return Button {
            Haptics.impact(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selection = item
                isOpen = false
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.callout)
                    .frame(width: 22)
                Text(item.title)
                    .font(.subheadline.weight(selected ? .semibold : .regular))
                Spacer(minLength: 12)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(selected ? Color.tgAccent : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.tgAccent.opacity(0.14))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct HomeView: View {
    @EnvironmentObject private var proxy: ProxyViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                if let warning = proxy.backgroundWarning {
                    backgroundWarning(warning)
                }
                statusCard
                if proxy.isRunning {
                    TrafficChartCard(samples: proxy.traffic)
                }
                metricsCard
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var hero: some View {
        VStack(spacing: 16) {
            PowerButton(isOn: proxy.isRunning, isBusy: proxy.state == .starting) {
                Haptics.impact()
                proxy.toggle()
            }
            Text(proxy.statusTitle)
                .font(.title3.weight(.semibold))
            connectButton
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var statusCard: some View {
        VStack(spacing: 12) {
            InfoRow(title: "Режим", value: proxy.modeTitle, systemImage: "shield.lefthalf.filled")
            Divider()
            InfoRow(
                title: "Адрес",
                value: "\(proxy.configuration.bindAddress):\(proxy.configuration.port)",
                systemImage: "network"
            )
        }
        .card()
    }

    private var metricsCard: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            MetricTile(title: "Получено", value: proxy.stats.downloaded, icon: "arrow.down")
            MetricTile(title: "Отправлено", value: proxy.stats.uploaded, icon: "arrow.up")
            MetricTile(
                title: "Ошибки",
                value: proxy.stats.errors,
                icon: "exclamationmark.triangle",
                color: proxy.stats.errors == "0" ? .tgAccent : .orange
            )
        }
        .card(padding: 10)
    }


    private var connectButton: some View {
        Button {
            if let url = proxy.telegramURL() { openURL(url) }
        } label: {
            HStack(spacing: 8) {
                Image("TelegramIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("Открыть в Telegram".tgLoc)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .disabled(!proxy.isRunning)
        .padding(.horizontal, 10)
    }

    private func backgroundWarning(_ text: String) -> some View {
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .card(padding: 12)
        }
        .buttonStyle(.plain)
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .tgAccent

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.callout.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(verbatim: title.tgLoc)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
    }
}


private struct TrafficChartCard: View {
    let samples: [TrafficSample]

    private static let fmt = ByteCountFormatter()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Скорость".tgLoc)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let last = samples.last {
                    HStack(spacing: 12) {
                        rate("arrow.down", last.down, .tgAccent)
                        rate("arrow.up", last.up, .tgConnected)
                    }
                }
            }

            if samples.count < 2 {
                Text("Сбор данных…".tgLoc)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 110)
            } else {
                Chart {
                    ForEach(samples) { s in
                        AreaMark(
                            x: .value("t", s.time),
                            y: .value("Загрузка", s.down)
                        )
                        .foregroundStyle(.linearGradient(
                            colors: [Color.tgAccent.opacity(0.45), Color.tgAccent.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .interpolationMethod(.catmullRom)
                    }
                    ForEach(samples) { s in
                        LineMark(
                            x: .value("t", s.time),
                            y: .value("Отдача", s.up)
                        )
                        .foregroundStyle(Color.tgConnected)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Self.speed(v) + "/с".tgLoc)
                                    .font(.system(size: 8))
                            }
                        }
                    }
                }
                .frame(height: 110)
            }
        }
        .card()
    }

    private func rate(_ icon: String, _ bytes: Double, _ color: Color) -> some View {
        Label(
            Self.speed(bytes) + "/с".tgLoc,
            systemImage: icon
        )
            .font(.caption.monospacedDigit())
            .foregroundStyle(color)
    }

    private static func speed(_ bytes: Double) -> String {
        bytes < 1 ? "0 Б" : fmt.string(fromByteCount: Int64(bytes))
    }
}

private struct PowerButton: View {
    let isOn: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isOn ? Color.tgConnected : Color.tgAccent)
                    .frame(width: 120, height: 120)

                if isBusy {
                    ProgressView().controlSize(.large).tint(.white)
                } else {
                    Image(systemName: isOn ? "stop.fill" : "power")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .animation(.easeInOut(duration: 0.25), value: isOn)
    }
}
