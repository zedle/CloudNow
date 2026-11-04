import Foundation

/// GeForce NOW streaming-quality presets, mirroring the native client's Streaming Quality
/// picker. A preset only seeds the individual stream settings; editing any of those settings
/// afterwards moves the selection to `.custom`.
nonisolated enum StreamQualityPreset: String, Codable, CaseIterable, Sendable {
    case balanced
    case dataSaver
    case competitive
    case cinematic
    case custom

    /// Unknown future values fall back to Custom so the stored stream settings stay authoritative.
    nonisolated init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = Self(rawValue: raw) ?? .custom
    }

    /// Native CloudMatch `profile` value.
    var nativeProfile: Int {
        switch self {
        case .custom: 0
        case .balanced: 1
        case .competitive: 2
        case .dataSaver: 3
        case .cinematic: 4
        }
    }

    var systemImage: String {
        switch self {
        case .balanced: "dial.medium.fill"
        case .dataSaver: "leaf.fill"
        case .competitive: "bolt.fill"
        case .cinematic: "film.fill"
        case .custom: "slider.horizontal.3"
        }
    }

    @MainActor var label: String {
        switch self {
        case .balanced: L10n.text("quality_preset_balanced")
        case .dataSaver: L10n.text("quality_preset_data_saver")
        case .competitive: L10n.text("quality_preset_competitive")
        case .cinematic: L10n.text("quality_preset_cinematic")
        case .custom: L10n.text("quality_preset_custom")
        }
    }

    @MainActor var description: String {
        switch self {
        case .balanced: L10n.text("quality_preset_balanced_description")
        case .dataSaver: L10n.text("quality_preset_data_saver_description")
        case .competitive: L10n.text("quality_preset_competitive_description")
        case .cinematic: L10n.text("quality_preset_cinematic_description")
        case .custom: L10n.text("quality_preset_custom_description")
        }
    }
}

/// Account and display limits a preset must respect when it is applied.
nonisolated struct StreamQualityPresetContext: Equatable, Sendable {
    let entitledResolutions: [EntitledResolution]?
    /// Resolutions the account may request, as `WIDTHxHEIGHT` labels.
    let availableResolutions: [String]
    let maximumDisplayFramesPerSecond: Int
    /// Output-mode height in pixels. Presets never request more lines than the TV shows,
    /// because the extra decode and downscale cost frame pacing without adding detail.
    var maximumDisplayHeight: Int?
}

nonisolated enum StreamQualityPresetPolicy {
    private enum ResolutionTarget {
        case height(Int)
        case highest
    }

    private enum FrameRateTarget {
        case fixed(Int)
        case highest
    }

    private struct Profile {
        let resolution: ResolutionTarget
        let frameRate: FrameRateTarget
        let maxBitrateKbps: Int
        let codec: VideoCodec
        let colorPreference: ColorModePreference
        let chromaFormat: ChromaFormat
        let networkAdjustment: NetworkAdjustmentMode
        var prefilterMode: VideoPrefilterMode = .off
        var hudSharpening = false
    }

    /// Mirrors the native client's server-provided streaming profiles. "Auto" bitrate maps
    /// to the highest selectable ceiling.
    private static func profile(for preset: StreamQualityPreset) -> Profile? {
        switch preset {
        case .dataSaver:
            Profile(
                resolution: .height(720),
                frameRate: .fixed(60),
                maxBitrateKbps: 12000,
                codec: .automatic,
                colorPreference: .forceSDR8,
                chromaFormat: .yuv420,
                networkAdjustment: .optimalLatency
            )
        case .balanced:
            Profile(
                resolution: .highest,
                frameRate: .highest,
                maxBitrateKbps: StreamSettings.maxSelectableBitrateKbps,
                codec: .automatic,
                colorPreference: .automatic,
                chromaFormat: .yuv420,
                networkAdjustment: .optimalLatency
            )
        case .competitive:
            Profile(
                resolution: .height(1080),
                frameRate: .highest,
                maxBitrateKbps: StreamSettings.maxSelectableBitrateKbps,
                codec: .automatic,
                colorPreference: .forceSDR8,
                chromaFormat: .yuv420,
                networkAdjustment: .optimalLatency
            )
        case .cinematic:
            Profile(
                resolution: .highest,
                frameRate: .fixed(60),
                maxBitrateKbps: StreamSettings.maxSelectableBitrateKbps,
                codec: .h265,
                colorPreference: .preferHDR,
                chromaFormat: .yuv444,
                networkAdjustment: .optimalQuality,
                prefilterMode: .auto,
                hudSharpening: true
            )
        case .custom:
            nil
        }
    }

    /// Returns `settings` with the preset's values applied inside the account and display
    /// limits. Custom only records the selection and leaves every other value untouched.
    static func apply(
        _ preset: StreamQualityPreset,
        to settings: StreamSettings,
        context: StreamQualityPresetContext
    ) -> StreamSettings {
        var result = settings
        result.qualityPreset = preset
        guard let profile = profile(for: preset) else { return result }

        result.resolution = resolution(
            for: profile.resolution,
            available: context.availableResolutions,
            maximumHeight: context.maximumDisplayHeight
        ) ?? settings.resolution
        result.fps = frameRate(for: profile.frameRate, resolution: result.resolution, context: context)
            ?? settings.fps
        result.maxBitrateKbps = profile.maxBitrateKbps
        result.codec = profile.codec
        result.colorPreference = profile.colorPreference
        result.chromaFormat = profile.chromaFormat
        result.networkAdjustment = profile.networkAdjustment
        result.prefilterMode = profile.prefilterMode
        result.hudSharpening = profile.hudSharpening
        return result
    }

    /// Upper bound of data used by one hour at the given bitrate, in gigabytes.
    static func estimatedGigabytesPerHour(bitrateKbps: Int) -> Double {
        Double(bitrateKbps) * 3600 / 8 / 1_000_000
    }

    private static func resolution(
        for target: ResolutionTarget,
        available: [String],
        maximumHeight: Int?
    ) -> String? {
        let parsed = available.compactMap { label -> (label: String, width: Int, height: Int)? in
            let parts = label.split(separator: "x").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return (label, parts[0], parts[1])
        }
        let widescreen = parsed.filter { $0.width * 9 == $0.height * 16 }
        let sorted = (widescreen.isEmpty ? parsed : widescreen)
            .sorted { ($0.height, $0.width) < ($1.height, $1.width) }
        let displayable = sorted.filter { candidate in
            maximumHeight.map { candidate.height <= $0 } ?? true
        }
        let candidates = displayable.isEmpty ? Array(sorted.prefix(1)) : displayable
        switch target {
        case .highest:
            return candidates.last?.label
        case let .height(height):
            return (candidates.last { $0.height <= height } ?? candidates.first)?.label
        }
    }

    private static func frameRate(
        for target: FrameRateTarget,
        resolution: String,
        context: StreamQualityPresetContext
    ) -> Int? {
        let available = GFNSettingsEligibilityPolicy.frameRates(
            entitledResolutions: context.entitledResolutions,
            selectedResolution: resolution,
            maximumFramesPerSecond: context.maximumDisplayFramesPerSecond
        )
        .filter(\.isAvailable)
        .map(\.framesPerSecond)
        .sorted()
        switch target {
        case .highest:
            return available.last
        case let .fixed(framesPerSecond):
            return available.last { $0 <= framesPerSecond } ?? available.first
        }
    }
}
