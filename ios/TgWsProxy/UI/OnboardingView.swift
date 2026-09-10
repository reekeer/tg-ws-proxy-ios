import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 14) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.tgAccent.opacity(0.25), radius: 18, y: 8)

                    Text("TG WS Proxy".tgLoc)
                        .font(.largeTitle.bold())
                    Text("Локальный MTProto-прокси для Telegram на быстром Rust-ядре".tgLoc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 14) {
                    FeatureRow(icon: "bolt.fill", title: "Один тап",
                               text: "Запусти прокси и открой его в Telegram одной кнопкой.")
                    FeatureRow(icon: "lock.shield.fill", title: "Приватность",
                               text: "Трафик идёт через WSS/Cloudflare к дата-центрам Telegram.")
                    FeatureRow(icon: "arrow.triangle.2.circlepath", title: "Всегда свежее ядро",
                               text: "Rust-ядро синхронизируется с upstream.")
                }
                .padding(.horizontal, 8)
                .card(padding: 18)
                .padding(.horizontal, 16)

                Spacer()

                Button {
                    Haptics.impact()
                    withAnimation { settings.onboardingDone = true }
                } label: {
                    Text("Начать".tgLoc)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .tint(.tgAccent)
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.tgAccent)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title.tgLoc).font(.callout.weight(.semibold))
                Text(verbatim: text.tgLoc).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
