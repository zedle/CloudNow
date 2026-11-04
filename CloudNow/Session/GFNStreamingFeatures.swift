import Foundation

/// Native GeForce NOW `dynamicStreamingMode`: how the server adapts when the network degrades.
/// Raw values are the wire values sent in NVST `vqos.dynamicStreamingMode`.
nonisolated enum NetworkAdjustmentMode: Int, Codable, CaseIterable, Sendable {
    case off = 0
    /// Holds frame rate and lowers resolution first (native "prefer FPS").
    case optimalLatency = 1
    /// Holds resolution and lowers frame rate first (native "prefer resolution").
    case optimalQuality = 2

    /// Unknown future values fall back to the native default.
    nonisolated init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(Int.self)) ?? Self.optimalLatency.rawValue
        self = Self(rawValue: raw) ?? .optimalLatency
    }

    @MainActor var label: String {
        switch self {
        case .off: L10n.text("network_adjust_off")
        case .optimalLatency: L10n.text("network_adjust_optimal_latency")
        case .optimalQuality: L10n.text("network_adjust_optimal_quality")
        }
    }
}

/// Native server-side AI video prefilter (denoise and sharpen before encoding).
/// Raw values are the CloudMatch `prefilterMode` and NVST `prefilterParams.prefilterMode` values.
nonisolated enum VideoPrefilterMode: Int, Codable, CaseIterable, Sendable {
    case off = 0
    case auto = 1
    case custom = 2

    static let levelRange = 0 ... 10

    static func clampedLevel(_ level: Int) -> Int {
        min(max(level, levelRange.lowerBound), levelRange.upperBound)
    }

    nonisolated init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(Int.self)) ?? Self.off.rawValue
        self = Self(rawValue: raw) ?? .off
    }

    /// Value NVIDIA's membership service lists under `SUPPORTED_DL_PREFILTERING`.
    var entitlementValue: String {
        switch self {
        case .off: "OFF"
        case .auto: "AUTO"
        case .custom: "CUSTOM"
        }
    }

    @MainActor var label: String {
        switch self {
        case .off: L10n.text("off")
        case .auto: L10n.text("automatic")
        case .custom: L10n.text("quality_preset_custom")
        }
    }
}

/// Streaming features the membership grants, from the MES `features.features` list.
/// Nil members mean the service did not report the feature.
nonisolated struct GFNStreamingFeatureEntitlements: Codable, Equatable, Sendable {
    var prefilterModes: Set<VideoPrefilterMode>?
    var hudStreaming: Bool?

    func allows(_ mode: VideoPrefilterMode) -> Bool {
        mode == .off || prefilterModes?.contains(mode) == true
    }
}

/// Values sent in CloudMatch `requestedStreamingFeatures` and the NVST SDP, derived from the
/// stored settings and the membership entitlements the way the native client does.
nonisolated struct GFNRequestedStreamingFeatures: Equatable, Sendable {
    let profile: Int
    let enabledL4S: Bool
    let networkAdjustment: NetworkAdjustmentMode
    let prefilterMode: VideoPrefilterMode
    let prefilterDenoiseLevel: Int
    let prefilterSharpnessLevel: Int
    let hudStreamingMode: Int

    init(settings: StreamSettings, entitlements: GFNStreamingFeatureEntitlements?) {
        profile = settings.qualityPreset.nativeProfile
        networkAdjustment = settings.networkAdjustment
        // The native client disables L4S while network adjustment is off.
        enabledL4S = settings.enableL4S && settings.networkAdjustment != .off
        let prefilter = entitlements?.allows(settings.prefilterMode) == true ? settings.prefilterMode : .off
        prefilterMode = prefilter
        prefilterDenoiseLevel = prefilter == .custom ? settings.prefilterDenoiseLevel : 0
        prefilterSharpnessLevel = prefilter == .custom ? settings.prefilterSharpnessLevel : 0
        // 1 is the native QP_MAP HUD streaming mode.
        hudStreamingMode = settings.hudSharpening && entitlements?.hudStreaming == true ? 1 : 0
    }
}
