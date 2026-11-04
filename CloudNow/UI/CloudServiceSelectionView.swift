import SwiftUI

struct CloudServiceSelectionView: View {
    @Environment(CloudGamingProviderCoordinator.self) private var providerCoordinator
    @FocusState private var focusedProvider: CloudGamingProvider?

    var body: some View {
        ZStack {
            CloudNowBackdrop(isAnimated: true)
                .environment(\.cloudNowAccent, (focusedProvider ?? .geForceNow).themeAccent)
                .animation(.easeInOut(duration: 0.4), value: focusedProvider)

            VStack(spacing: 56) {
                CloudNowBrandHeader(
                    subtitle: L10n.text("choose_cloud_gaming_service")
                )

                HStack(spacing: 40) {
                    ForEach(CloudGamingProvider.allCases) { provider in
                        let availability = providerCoordinator.capabilities(
                            for: provider
                        ).availability
                        Button {
                            providerCoordinator.select(provider)
                        } label: {
                            CloudServiceChoiceLabel(
                                provider: provider,
                                isFocused: focusedProvider == provider,
                                availability: availability
                            )
                        }
                        .buttonStyle(.plain)
                        .focusEffectDisabled()
                        .focused($focusedProvider, equals: provider)
                        .disabled(!availability.isSupported)
                        .accessibilityLabel(provider.displayName)
                        .accessibilityValue(
                            availability.unavailableReason.map {
                                L10n.text($0.localizationKey)
                            } ?? ""
                        )
                        .accessibilityIdentifier("service-choice.\(provider.rawValue)")
                    }
                }
                .defaultFocus($focusedProvider, .geForceNow)

                Text(L10n.text("accounts_stay_signed_in_when_switching_services"))
                    .font(.caption)
                    .foregroundStyle(CloudNowTheme.secondaryText)
            }
            .padding(80)
        }
        .accessibilityIdentifier("service-chooser")
    }
}

struct XboxCloudConfigurationRequiredView: View {
    @Environment(CloudGamingProviderCoordinator.self) private var providerCoordinator

    var body: some View {
        ZStack {
            CloudNowBackdrop(isAnimated: true)

            VStack(spacing: 36) {
                Image(systemName: CloudGamingProvider.xboxCloudGaming.systemImage)
                    .font(.system(size: 72))
                    .foregroundStyle(CloudNowTheme.xboxGreen)
                    .shadow(color: CloudNowTheme.xboxGreen.opacity(0.7), radius: 24)

                VStack(spacing: 12) {
                    Text(CloudGamingProvider.xboxCloudGaming.displayName)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                    Text(L10n.text("awaiting_official_xbox_cloud_support"))
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(
                    availabilityMessage
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 920)

                HStack(spacing: 24) {
                    Button {
                        providerCoordinator.select(.geForceNow)
                    } label: {
                        Label(L10n.text("use_geforce_now"), systemImage: "sparkles.tv")
                    }
                    .buttonStyle(CloudNowGlowButtonStyle(accentOverride: CloudNowTheme.geForceNowGreen))

                    Button(L10n.text("choose_another_service")) {
                        providerCoordinator.select(nil)
                    }
                    .buttonStyle(CloudNowGlowButtonStyle(isProminent: false))
                }
            }
            .padding(80)
        }
        .cloudNowTheme(accent: CloudNowTheme.xboxGreen)
        .accessibilityIdentifier("service-shell.xbox-cloud-gaming")
    }

    private var availabilityMessage: String {
        providerCoordinator.capabilities(
            for: .xboxCloudGaming
        ).availability.unavailableReason.map {
            L10n.text($0.localizationKey)
        } ?? L10n.text("xbox_cloud_runtime_inactive_message")
    }
}

struct CloudNowBrandHeader: View {
    let subtitle: String

    @Environment(\.cloudNowAccent) private var accent

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "play.tv.fill")
                .font(.system(size: 84, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: accent.opacity(0.65), radius: 30)
                .accessibilityHidden(true)
            Text(L10n.text("app_name"))
                .font(.system(size: 64, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white, accent],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: accent.opacity(0.35), radius: 20)
            Text(subtitle)
                .font(.title3)
                .foregroundStyle(CloudNowTheme.secondaryText)
        }
    }
}

private struct CloudServiceChoiceLabel: View {
    let provider: CloudGamingProvider
    let isFocused: Bool
    let availability: CloudCapability<CloudProviderAvailabilityCapability>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let accent = provider.themeAccent
        VStack(spacing: 16) {
            Image(systemName: provider.systemImage)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(isFocused ? .black : accent)
                .shadow(color: accent.opacity(isFocused ? 0 : 0.6), radius: 14)
            Text(provider.displayName)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let reason = availability.unavailableReason {
                Text(L10n.text(reason.localizationKey))
                    .font(.caption)
                    .foregroundStyle(isFocused ? .black.opacity(0.7) : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(isFocused ? .black : .white)
        .padding(.horizontal, 28)
        .frame(width: 430, height: 200)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    isFocused
                        ? AnyShapeStyle(LinearGradient(
                            colors: [accent, accent.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(CloudNowTheme.glassFill)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    isFocused ? Color.white.opacity(0.8) : accent.opacity(0.35),
                    lineWidth: isFocused ? 3 : 1.5
                )
        }
        .shadow(color: accent.opacity(isFocused ? 0.6 : 0), radius: 36, y: 10)
        .scaleEffect(isFocused && !reduceMotion ? 1.06 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isFocused)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
