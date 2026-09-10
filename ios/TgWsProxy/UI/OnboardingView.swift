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
                }

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

