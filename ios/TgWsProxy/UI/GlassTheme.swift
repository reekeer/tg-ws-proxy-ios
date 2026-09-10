import SwiftUI

extension Color {
    static var tgAccent: Color { AccentChoice.current.color }

    static let tgConnected = Color(red: 0.18, green: 0.78, blue: 0.44)
}

private struct LiquidGlassKey: EnvironmentKey { static let defaultValue = true }

extension EnvironmentValues {
    var liquidGlassEnabled: Bool {
        get { self[LiquidGlassKey.self] }
        set { self[LiquidGlassKey.self] = newValue }
    }
}

struct AppBackground: View {
    var active: Bool = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            Circle()
                .fill((active ? Color.tgConnected : Color.tgAccent).opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 120)
                .offset(x: 0, y: -360)
                .animation(.easeInOut(duration: 0.6), value: active)
        }
        .ignoresSafeArea()
    }
}

struct CardModifier: ViewModifier {
    @Environment(\.liquidGlassEnabled) private var liquidGlass
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return surface(content: content, shape: shape)
            .overlay {
                shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            }
    }

    @ViewBuilder
    private func surface(content: Content, shape: RoundedRectangle) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *), liquidGlass {
            content
                .padding(padding)
                .glassEffect(.regular, in: shape)
        } else {
            content
                .padding(padding)
                .background(.ultraThinMaterial, in: shape)
        }
#else
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: shape)
#endif
    }
}

extension View {
    func card(padding: CGFloat = 16, cornerRadius: CGFloat = 20) -> some View {
        modifier(CardModifier(padding: padding, cornerRadius: cornerRadius))
    }

    func glassBar() -> some View {
        modifier(GlassBarModifier())
    }
}

private struct GlassBarModifier: ViewModifier {
    @Environment(\.liquidGlassEnabled) private var liquidGlass

    @ViewBuilder
    func body(content: Content) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *), liquidGlass {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
        }
#else
        content
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
#endif
    }
}


struct InfoRow: View {
    let title: String
    let value: String
    var systemImage: String? = nil
    var valueColor: Color = .primary

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.callout)
                    .foregroundStyle(Color.tgAccent)
                    .frame(width: 22)
            }
            Text(verbatim: title.tgLoc)
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
                .font(.callout.monospacedDigit())
        }
        .font(.callout)
    }
}
