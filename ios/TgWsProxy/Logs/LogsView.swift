import SwiftUI
import UIKit

struct LogsTabView: View {
    @ObservedObject private var store = LogStore.shared
    @EnvironmentObject private var proxy: ProxyViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("\("Строк:".tgLoc) \(store.lines.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                ShareLink(item: store.report(context: proxy.diagnosticsContext)) {
                    Image(systemName: "square.and.arrow.up")
                }
                Button {
                    UIPasteboard.general.string = store.joined()
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .disabled(store.lines.isEmpty)
                Button(role: .destructive) {
                    store.clear()
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(store.lines.isEmpty)
            }
            .padding(.horizontal, 18)

            LogConsole(store: store)
                .card(padding: 0)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
        }
    }


}

struct LogsView: View {
    @ObservedObject private var store = LogStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LogConsole(store: store)
                .navigationTitle("Логи ядра".tgLoc)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Закрыть".tgLoc) { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            ShareLink(item: store.joined()) {
                                Label("Поделиться".tgLoc, systemImage: "square.and.arrow.up")
                            }
                            Button {
                                UIPasteboard.general.string = store.joined()
                            } label: {
                                Label("Копировать всё".tgLoc, systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive) {
                                store.clear()
                            } label: {
                                Label("Очистить".tgLoc, systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
        }
    }
}

private struct LogConsole: View {
    @ObservedObject var store: LogStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    if store.lines.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("Логи пусты".tgLoc)
                                .font(.headline)
                            Text("Запустите прокси, чтобы увидеть вывод Rust-ядра.".tgLoc)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 280)
                    }
                    ForEach(Array(store.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(color(for: line))
                            .textSelection(.enabled)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(12)
            }
            .scrollIndicators(.hidden)
            .onValueChange(of: store.lines.count) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private func color(for line: String) -> Color {
        if line.localizedCaseInsensitiveContains("error") { return .red }
        if line.localizedCaseInsensitiveContains("warn") { return .orange }
        if line.localizedCaseInsensitiveContains("debug") { return .secondary }
        return .primary
    }
}
