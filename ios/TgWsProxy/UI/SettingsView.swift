import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var proxy: ProxyViewModel
    @EnvironmentObject private var settings: AppSettings
    @State private var showLogs = false
    @State private var showPing = false
    @State private var secretCopied = false
    @State private var refreshingDomains = false

    var body: some View {
        Form {
            Section("Язык".tgLoc) {
                Picker(selection: languageBinding) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Text(verbatim: "\(lang.flag)  \(lang.title)").tag(lang)
                    }
                } label: {
                    Label("Язык приложения".tgLoc, systemImage: "globe")
                }
                .pickerStyle(.menu)
            }

            Section("Локальный прокси".tgLoc) {
                HStack {
                    Text("Адрес:".tgLoc)
                    TextField("127.0.0.1", text: $proxy.configuration.bindAddress)
                        .multilineTextAlignment(.trailing)
                        .proxyTextInputBehavior()
                }
                HStack {
                    Text("Порт:".tgLoc)
                    TextField("1443", value: $proxy.configuration.port, format: .number.grouping(.never))
                        .multilineTextAlignment(.trailing)
                        .proxyNumberInputBehavior()
                }
                HStack {
                    Text("Размер пула:".tgLoc)
                    Picker("Размер пула:".tgLoc, selection: $proxy.configuration.poolSize) {
                        ForEach(ProxyConfiguration.allowedPoolSizes, id: \.self) {
                            Text(String($0)).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .disabled(proxy.isRunning)

            Section("Cloudflare".tgLoc) {
                Toggle("Использовать Cloudflare".tgLoc, isOn: $proxy.configuration.cloudflareEnabled)
                TextField("Свой домен (необязательно)".tgLoc, text: $proxy.configuration.cloudflareDomain)
                    .proxyTextInputBehavior()
                DisclosureGroup("\("Домены CF Worker".tgLoc) (\(proxy.cloudflareDomains.count))") {
                    if proxy.cloudflareDomains.isEmpty {
                        Text("Список пуст".tgLoc)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(proxy.cloudflareDomains, id: \.self) { domain in
                            HStack {
                                Image(systemName: "cloud.fill")
                                    .foregroundStyle(.blue)
                                Text(domain)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                Spacer()
                                Button {
                                    UIPasteboard.general.string = domain
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Button {
                    refreshingDomains = true
                    Task {
                        _ = await proxy.refreshCloudflareDomains()
                        refreshingDomains = false
                    }
                } label: {
                    Label(
                        refreshingDomains ? "Обновление…".tgLoc : "Обновить список Workers".tgLoc,
                        systemImage: "arrow.clockwise"
                    )
                }
                .disabled(refreshingDomains)
            }
            .disabled(proxy.isRunning)

            Section("Telegram DC".tgLoc) {
                TextField(
                    "Переопределения адресов".tgLoc,
                    text: $proxy.configuration.dcAddresses,
                    axis: .vertical
                )
                .lineLimit(3...8)
                Text("Пустое значение использует адреса из Rust upstream.".tgLoc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(proxy.isRunning)

            Section("Секрет".tgLoc) {
                Button {
                    UIPasteboard.general.string = "dd" + proxy.configuration.secret
                    secretCopied = true
                    Haptics.notify(.success)
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        secretCopied = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.blue)
                        Text("dd" + proxy.configuration.secret)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: secretCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .foregroundStyle(secretCopied ? .green : .secondary)
                    }
                }
                .buttonStyle(.plain)
                Text(secretCopied ? "Секрет скопирован" : "Нажмите, чтобы скопировать Telegram-секрет")
                    .font(.caption)
                    .foregroundStyle(secretCopied ? .green : .secondary)
                Button("Сгенерировать новый".tgLoc) {
                    proxy.regenerateSecret()
                }
                .disabled(proxy.isRunning)
            }

            Section("Внешний вид".tgLoc) {
                Picker("Тема".tgLoc, selection: Binding(
                    get: { settings.theme },
                    set: { settings.theme = $0 }
                )) {
                    ForEach(AppTheme.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Акцент".tgLoc).font(.callout)
                    HStack(spacing: 14) {
                        ForEach(AccentChoice.allCases, id: \.self) { choice in
                            Circle()
                                .fill(choice.color)
                                .frame(width: 28, height: 28)
                                .overlay {
                                    if settings.accent == choice {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                                .overlay {
                                    Circle().strokeBorder(.white.opacity(settings.accent == choice ? 0.9 : 0), lineWidth: 2)
                                }
                                .onTapGesture {
                                    Haptics.impact(.light)
                                    settings.accent = choice
                                }
                        }
                    }
                }
                Toggle("Liquid Glass".tgLoc, isOn: $settings.liquidGlass)
            }

            Section("Поведение".tgLoc) {
                Toggle("Авто-старт при запуске".tgLoc, isOn: $settings.autoStart)
                Toggle("Авто-переподключение".tgLoc, isOn: $settings.reconnect)
                Toggle("Уведомления".tgLoc, isOn: $settings.notifications)
                Toggle("Вибрация".tgLoc, isOn: $settings.haptics)
                Toggle("Удерживать прокси в фоне".tgLoc, isOn: $settings.backgroundKeeper)
                if settings.backgroundKeeper, !BackgroundKeeper.shared.isAuthorizedForBackground {
                    Button {
                        openLocationSettings()
                    } label: {
                        Label("Геопозиция: нужен режим «Всегда»".tgLoc, systemImage: "location.circle")
                    }
                }
            }

            if settings.restartRequired {
                Section {
                    Button("Перезапустить интерфейс".tgLoc) {
                        settings.restartInterface()
                    }
                }
            }

            Section("Диагностика".tgLoc) {
                Toggle("Подробные логи Rust".tgLoc, isOn: $proxy.configuration.verboseLogging)
                Button {
                    showLogs = true
                } label: {
                    Label("Открыть логи отдельно".tgLoc, systemImage: "rectangle.on.rectangle")
                }
                Button {
                    showPing = true
                } label: {
                    Label("Проверить задержку до DC".tgLoc, systemImage: "wave.3.right")
                }
            }

        }
        .scrollContentBackground(.hidden)
        .onChange(of: settings.notifications) { _, on in
            if on { NotificationManager.requestAuthorization() }
        }
        .onChange(of: settings.backgroundKeeper) { _, enabled in
            if enabled {
                BackgroundKeeper.shared.requestAuthorization()
                if proxy.isRunning { BackgroundKeeper.shared.activate() }
            } else {
                BackgroundKeeper.shared.deactivate()
            }
        }
        .sheet(isPresented: $showLogs) { LogsView() }
        .sheet(isPresented: $showPing) { PingView() }
    }

    private func openLocationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { settings.language },
            set: { newValue in
                guard settings.language != newValue else { return }
                Haptics.impact(.light)
                withAnimation(.snappy) { settings.language = newValue }
            }
        )
    }
}

private extension View {
    @ViewBuilder
    func proxyTextInputBehavior() -> some View {
#if os(iOS)
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
#else
        self
#endif
    }

    @ViewBuilder
    func proxyNumberInputBehavior() -> some View {
#if os(iOS)
        keyboardType(.numberPad)
#else
        self
#endif
    }
}
