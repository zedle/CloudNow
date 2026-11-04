import SwiftUI

/// Native-style Streaming Quality preset picker: one glass tile per preset plus a summary of
/// the values the stream will request.
struct GFNStreamQualityPresetRow: View {
    let selection: StreamQualityPreset
    let settings: StreamSettings
    let onSelect: (StreamQualityPreset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 20) {
                ForEach(StreamQualityPreset.allCases, id: \.self) { preset in
                    Button {
                        onSelect(preset)
                    } label: {
                        Label(preset.label, systemImage: preset.systemImage)
                    }
                    .buttonStyle(GFNQualityPresetTileStyle(isSelected: preset == selection))
                    .accessibilityAddTraits(preset == selection ? .isSelected : [])
                    .accessibilityHint(preset.description)
                    .accessibilityIdentifier("settings.stream-quality.preset.\(preset.rawValue)")
                }
            }
            .focusSection()

            VStack(alignment: .leading, spacing: 6) {
                Text(selection.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(summary)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.white)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.stream-quality.preset.summary")
        }
        .padding(.vertical, 12)
        .listRowBackground(Color.clear)
    }

    private var summary: String {
        [
            settings.resolution,
            "\(settings.fps) fps",
            "\(settings.maxBitrateKbps / 1000) Mbps",
            GFNBitrateControl.dataEstimate(bitrateKbps: settings.maxBitrateKbps),
        ].joined(separator: "  ·  ")
    }
}

private struct GFNQualityPresetTileStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        GFNQualityPresetTile(configuration: configuration, isSelected: isSelected)
    }
}

private struct GFNQualityPresetTile: View {
    let configuration: ButtonStyleConfiguration
    let isSelected: Bool

    @Environment(\.isFocused) private var isFocused
    @Environment(\.cloudNowAccent) private var accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        configuration.label
            .labelStyle(GFNQualityPresetTileLabelStyle())
            .foregroundStyle(isFocused ? .black : (isSelected ? accent : .white))
            .frame(width: 210, height: 130)
            .background {
                shape.fill(
                    isFocused
                        ? AnyShapeStyle(LinearGradient(
                            colors: [accent, accent.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        : AnyShapeStyle(isSelected ? accent.opacity(0.14) : CloudNowTheme.glassFill)
                )
            }
            .overlay {
                shape.strokeBorder(
                    isFocused ? .white.opacity(0.8) : (isSelected ? accent : CloudNowTheme.glassStroke),
                    lineWidth: isFocused || isSelected ? 2 : 1
                )
            }
            .shadow(color: accent.opacity(isFocused ? 0.6 : (isSelected ? 0.3 : 0)), radius: isFocused ? 26 : 14)
            .scaleEffect(isFocused && !reduceMotion ? 1.07 : (configuration.isPressed ? 0.97 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isFocused)
    }
}

private struct GFNQualityPresetTileLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 12) {
            configuration.icon
                .font(.system(size: 34, weight: .semibold))
            configuration.title
                .font(.callout.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
    }
}

/// Max-bitrate control drawn as a glowing meter between minus and plus buttons, with the
/// native client's hourly data estimate.
struct GFNBitrateControl: View {
    @Binding var bitrateKbps: Int

    @Environment(\.cloudNowAccent) private var accent

    private let range = StreamSettings.minSelectableBitrateKbps ... StreamSettings.maxSelectableBitrateKbps
    private let step = StreamSettings.bitrateStepKbps

    static func dataEstimate(bitrateKbps: Int) -> String {
        let gigabytes = StreamQualityPresetPolicy.estimatedGigabytesPerHour(bitrateKbps: bitrateKbps)
        return L10n.format(
            "quality_data_estimate",
            gigabytes.formatted(.number.precision(.fractionLength(1)))
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.text("max_bitrate"))
                Spacer()
                Text("\(bitrateKbps / 1000) Mbps")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(accent)
                    .shadow(color: accent.opacity(0.6), radius: 10)
            }

            HStack(spacing: 24) {
                adjustButton(systemImage: "minus", delta: -step)
                    .disabled(bitrateKbps <= range.lowerBound)
                    .accessibilityIdentifier("settings.stream-quality.bitrate.decrease")

                meter

                adjustButton(systemImage: "plus", delta: step)
                    .disabled(bitrateKbps >= range.upperBound)
                    .accessibilityIdentifier("settings.stream-quality.bitrate.increase")
            }
            .focusSection()

            Text(Self.dataEstimate(bitrateKbps: bitrateKbps))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.stream-quality.bitrate")
    }

    private var fraction: CGFloat {
        let span = CGFloat(range.upperBound - range.lowerBound)
        return CGFloat(min(max(bitrateKbps, range.lowerBound), range.upperBound) - range.lowerBound) / span
    }

    private var meter: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(CloudNowTheme.glassFill)
                    .overlay { Capsule().strokeBorder(CloudNowTheme.glassStroke, lineWidth: 1) }
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [CloudNowTheme.secondaryGlow, accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(18, proxy.size.width * fraction))
                    .shadow(color: accent.opacity(0.7), radius: 12)
            }
        }
        .frame(height: 18)
        .animation(.easeOut(duration: 0.18), value: bitrateKbps)
        .accessibilityHidden(true)
    }

    /// Steps to the next multiple of the step size so off-grid preset values rejoin the grid.
    static func steppedBitrate(_ bitrateKbps: Int, delta: Int) -> Int {
        let step = StreamSettings.bitrateStepKbps
        let range = StreamSettings.minSelectableBitrateKbps ... StreamSettings.maxSelectableBitrateKbps
        let next = delta > 0
            ? (bitrateKbps / step + 1) * step
            : (bitrateKbps - 1) / step * step
        return min(max(next, range.lowerBound), range.upperBound)
    }

    private func adjustButton(systemImage: String, delta: Int) -> some View {
        Button {
            bitrateKbps = Self.steppedBitrate(bitrateKbps, delta: delta)
        } label: {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
        }
        .buttonStyle(CloudNowGlowButtonStyle(isProminent: false))
    }
}

/// Native AI Video Filter (server prefilter) and HUD sharpening rows, gated by membership.
struct GFNVideoFilterControls: View {
    @Binding var prefilterMode: VideoPrefilterMode
    @Binding var denoiseLevel: Int
    @Binding var sharpnessLevel: Int
    @Binding var hudSharpening: Bool
    let entitlements: GFNStreamingFeatureEntitlements?

    var body: some View {
        CloudNowSettingSelectionRow(
            L10n.text("ai_video_filter"),
            description: L10n.text("ai_video_filter_description"),
            selection: $prefilterMode,
            accessibilityIdentifier: "settings.stream-quality.ai-video-filter",
            options: VideoPrefilterMode.allCases.map { mode in
                CloudNowSettingOption(
                    value: mode,
                    title: mode.label,
                    accessibilityIdentifier: "\(mode.rawValue)",
                    unavailability: entitlements?.allows(mode) == true || mode == .off
                        ? nil
                        : CloudNowSettingUnavailability(reason: L10n.text("not_in_membership"))
                )
            }
        )

        if prefilterMode == .custom {
            levelRow("prefilter_denoise", selection: $denoiseLevel, identifier: "denoise")
            levelRow("prefilter_sharpen", selection: $sharpnessLevel, identifier: "sharpen")
        }

        Toggle(isOn: $hudSharpening) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text("hud_sharpening"))
                Text(L10n.text(entitlements?.hudStreaming == true ? "hud_sharpening_description" : "not_in_membership"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
        .disabled(entitlements?.hudStreaming != true)
        .accessibilityIdentifier("settings.stream-quality.hud-sharpening")
    }

    private func levelRow(_ titleKey: String, selection: Binding<Int>, identifier: String) -> some View {
        CloudNowSettingSelectionRow(
            L10n.text(titleKey),
            selection: selection,
            accessibilityIdentifier: "settings.stream-quality.ai-video-filter.\(identifier)",
            options: VideoPrefilterMode.levelRange.map { level in
                CloudNowSettingOption(value: level, title: "\(level)", accessibilityIdentifier: "\(level)")
            }
        )
    }
}
