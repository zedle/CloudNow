import SwiftUI

/// CloudNow "Neon Glass" palette: near-black base, frosted surfaces, and a provider accent
/// that glows on focus. Shared chrome reads the accent from the environment so GeForce NOW
/// renders NVIDIA green and Xbox renders Xbox green without provider checks in the views.
enum CloudNowTheme {
    static let base = Color(red: 0.016, green: 0.02, blue: 0.024)
    static let geForceNowGreen = Color(red: 0.463, green: 0.725, blue: 0)
    static let xboxGreen = Color(red: 0.24, green: 0.8, blue: 0.29)
    static let secondaryGlow = Color(red: 0, green: 0.62, blue: 0.56)
    static let glassFill = Color.white.opacity(0.06)
    static let glassFillFocused = Color.white.opacity(0.12)
    static let glassStroke = Color.white.opacity(0.12)
    static let secondaryText = Color.white.opacity(0.62)
}

extension EnvironmentValues {
    @Entry var cloudNowAccent: Color = CloudNowTheme.geForceNowGreen
}

extension CloudGamingProvider {
    var themeAccent: Color {
        switch self {
        case .geForceNow: CloudNowTheme.geForceNowGreen
        case .xboxCloudGaming: CloudNowTheme.xboxGreen
        }
    }
}

extension View {
    /// Applies the dark Neon Glass appearance and the provider accent to a whole subtree.
    func cloudNowTheme(accent: Color) -> some View {
        environment(\.cloudNowAccent, accent)
            .tint(accent)
    }

    /// Frosted glass surface with a hairline edge that lights up in the accent when highlighted.
    func cloudNowGlass(cornerRadius: CGFloat = 24, isHighlighted: Bool = false) -> some View {
        modifier(CloudNowGlassModifier(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
    }
}

private struct CloudNowGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isHighlighted: Bool
    @Environment(\.cloudNowAccent) private var accent

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(isHighlighted ? CloudNowTheme.glassFillFocused : CloudNowTheme.glassFill, in: shape)
            .overlay {
                shape.strokeBorder(
                    isHighlighted ? accent.opacity(0.9) : CloudNowTheme.glassStroke,
                    lineWidth: isHighlighted ? 2 : 1
                )
            }
            .shadow(color: accent.opacity(isHighlighted ? 0.45 : 0), radius: 24)
    }
}

/// Full-screen ambient backdrop. Only menu-only screens animate it; the tab shell keeps it
/// static because a stream is presented on top of that shell.
struct CloudNowBackdrop: View {
    var isAnimated = false

    @Environment(\.cloudNowAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDrifted = false

    var body: some View {
        ZStack {
            CloudNowTheme.base
            RadialGradient(
                colors: [accent.opacity(0.24), accent.opacity(0.06), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 1100
            )
            .offset(x: isDrifted ? 140 : -60, y: isDrifted ? 60 : -40)
            RadialGradient(
                colors: [CloudNowTheme.secondaryGlow.opacity(0.14), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 1200
            )
            .offset(x: isDrifted ? -80 : 40, y: isDrifted ? -40 : 30)
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard isAnimated, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                isDrifted = true
            }
        }
    }
}

/// Capsule button that fills with the accent and glows when focused. Prominent buttons show
/// an accent outline at rest so the primary action reads first on the screen.
struct CloudNowGlowButtonStyle: ButtonStyle {
    var isProminent = true
    var accentOverride: Color?

    func makeBody(configuration: Configuration) -> some View {
        CloudNowGlowButtonBody(
            configuration: configuration,
            isProminent: isProminent,
            accentOverride: accentOverride
        )
    }
}

private struct CloudNowGlowButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let isProminent: Bool
    let accentOverride: Color?

    @Environment(\.isFocused) private var isFocused
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.cloudNowAccent) private var environmentAccent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color {
        accentOverride ?? environmentAccent
    }

    var body: some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .padding(.horizontal, 36)
            .padding(.vertical, 18)
            .background {
                Capsule().fill(fill)
            }
            .overlay {
                Capsule().strokeBorder(stroke, lineWidth: isFocused ? 2 : 1.5)
            }
            .shadow(color: accent.opacity(isFocused ? 0.65 : 0), radius: isFocused ? 26 : 0)
            .scaleEffect(scale)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isFocused)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private var foreground: Color {
        if isFocused {
            return .black
        }
        return isProminent ? accent : .white
    }

    private var fill: AnyShapeStyle {
        guard isFocused else { return AnyShapeStyle(CloudNowTheme.glassFill) }
        return AnyShapeStyle(
            LinearGradient(
                colors: [accent, accent.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var stroke: Color {
        if isFocused {
            return .white.opacity(0.75)
        }
        return isProminent ? accent.opacity(0.75) : CloudNowTheme.glassStroke
    }

    private var scale: CGFloat {
        if configuration.isPressed {
            return 0.97
        }
        return isFocused && !reduceMotion ? 1.06 : 1
    }
}

/// Row title with a short glowing accent bar, used above catalog rails.
struct CloudNowSectionTitle: View {
    let title: String
    @Environment(\.cloudNowAccent) private var accent

    var body: some View {
        HStack(spacing: 14) {
            Capsule()
                .fill(accent)
                .frame(width: 6, height: 30)
                .shadow(color: accent.opacity(0.8), radius: 8)
                .accessibilityHidden(true)
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
        }
    }
}
