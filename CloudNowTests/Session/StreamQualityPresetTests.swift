@testable import CloudNow
import Foundation
import Testing

@Suite("GFN streaming quality presets")
struct StreamQualityPresetTests {
    private static let ultimateContext = StreamQualityPresetContext(
        entitledResolutions: [
            EntitledResolution(widthInPixels: 1280, heightInPixels: 720, framesPerSecond: 120),
            EntitledResolution(widthInPixels: 1920, heightInPixels: 1080, framesPerSecond: 240),
            EntitledResolution(widthInPixels: 2560, heightInPixels: 1080, framesPerSecond: 120),
            EntitledResolution(widthInPixels: 3840, heightInPixels: 2160, framesPerSecond: 120),
        ],
        availableResolutions: ["1280x720", "1920x1080", "2560x1080", "3840x2160"],
        maximumDisplayFramesPerSecond: 60
    )

    @Test("Existing settings without preset fields decode as Custom with the native network default")
    func legacyDecodingDefaults() throws {
        let json = Data(#"{"resolution":"3840x2160","fps":120,"maxBitrateKbps":80000}"#.utf8)

        let settings = try JSONDecoder().decode(StreamSettings.self, from: json)

        #expect(settings.qualityPreset == .custom)
        #expect(settings.networkAdjustment == .optimalLatency)
        #expect(settings.prefilterMode == .off)
        #expect(!settings.hudSharpening)
        #expect(!settings.jitterBufferPacing)
        #expect(settings.resolution == "3840x2160")
        #expect(settings.maxBitrateKbps == 80000)
    }

    @Test("Preset fields round-trip and unknown presets fall back to Custom")
    func presetRoundTrip() throws {
        var settings = StreamSettings()
        settings.qualityPreset = .cinematic
        settings.networkAdjustment = .optimalQuality
        settings.prefilterMode = .custom
        settings.prefilterDenoiseLevel = 4
        settings.prefilterSharpnessLevel = 7
        settings.hudSharpening = true
        settings.jitterBufferPacing = true

        let decoded = try JSONDecoder().decode(
            StreamSettings.self,
            from: JSONEncoder().encode(settings)
        )
        let unknown = try JSONDecoder().decode(
            StreamSettings.self,
            from: Data(#"{"qualityPreset":"ultraMax"}"#.utf8)
        )

        #expect(decoded == settings)
        #expect(decoded.framePacingMode == .jitterBuffer)
        #expect(unknown.qualityPreset == .custom)
    }

    @Test(
        "Legacy adjust-for-poor-network flag maps onto the native mode",
        arguments: [(true, NetworkAdjustmentMode.optimalLatency), (false, .off)]
    )
    func legacyNetworkAdjustment(stored: Bool, expected: NetworkAdjustmentMode) throws {
        let json = Data(#"{"adjustForPoorNetwork":\#(stored)}"#.utf8)

        let settings = try JSONDecoder().decode(StreamSettings.self, from: json)

        #expect(settings.networkAdjustment == expected)
    }

    @Test("Prefilter levels clamp to the native 0-10 range")
    func prefilterLevelClamping() throws {
        let json = Data(#"{"prefilterMode":9,"prefilterDenoiseLevel":42,"prefilterSharpnessLevel":-3}"#.utf8)

        let settings = try JSONDecoder().decode(StreamSettings.self, from: json)

        #expect(settings.prefilterMode == .off)
        #expect(settings.prefilterDenoiseLevel == 10)
        #expect(settings.prefilterSharpnessLevel == 0)
    }

    @Test(
        "Presets send the native CloudMatch profile",
        arguments: [
            (StreamQualityPreset.custom, 0),
            (.balanced, 1),
            (.competitive, 2),
            (.dataSaver, 3),
            (.cinematic, 4),
        ]
    )
    func nativeProfile(preset: StreamQualityPreset, expected: Int) {
        #expect(preset.nativeProfile == expected)
    }

    @Test("Data Saver requests 720p60 at 12 Mbps with network adaptation")
    func dataSaver() {
        let settings = StreamQualityPresetPolicy.apply(.dataSaver, to: StreamSettings(), context: Self.ultimateContext)

        #expect(settings.qualityPreset == .dataSaver)
        #expect(settings.resolution == "1280x720")
        #expect(settings.fps == 60)
        #expect(settings.maxBitrateKbps == 12000)
        #expect(settings.colorPreference == .forceSDR8)
        #expect(settings.chromaFormat == .yuv420)
        #expect(settings.networkAdjustment == .optimalLatency)
        #expect(settings.prefilterMode == .off)
    }

    @Test("Balanced takes the plan's best resolution and frame rate at the auto bitrate")
    func balanced() {
        let settings = StreamQualityPresetPolicy.apply(.balanced, to: StreamSettings(), context: Self.ultimateContext)

        #expect(settings.resolution == "3840x2160")
        #expect(settings.fps == 60)
        #expect(settings.maxBitrateKbps == StreamSettings.maxSelectableBitrateKbps)
        #expect(settings.colorPreference == .automatic)
        #expect(settings.chromaFormat == .yuv420)
        #expect(settings.networkAdjustment == .optimalLatency)
    }

    @Test("Competitive takes the highest frame rate the display allows")
    func competitiveFrameRate() {
        let display60 = StreamQualityPresetPolicy.apply(.competitive, to: StreamSettings(), context: Self.ultimateContext)
        let display120 = StreamQualityPresetPolicy.apply(
            .competitive,
            to: StreamSettings(),
            context: StreamQualityPresetContext(
                entitledResolutions: Self.ultimateContext.entitledResolutions,
                availableResolutions: Self.ultimateContext.availableResolutions,
                maximumDisplayFramesPerSecond: 120
            )
        )

        #expect(display60.resolution == "1920x1080")
        #expect(display60.fps == 60)
        #expect(display120.fps == 120)
        #expect(display120.colorPreference == .forceSDR8)
    }

    @Test("Cinematic picks the highest 16:9 resolution with HDR and 4:4:4")
    func cinematic() {
        let settings = StreamQualityPresetPolicy.apply(.cinematic, to: StreamSettings(), context: Self.ultimateContext)

        #expect(settings.resolution == "3840x2160")
        #expect(settings.fps == 60)
        #expect(settings.maxBitrateKbps == StreamSettings.maxSelectableBitrateKbps)
        #expect(settings.codec == .h265)
        #expect(settings.colorPreference == .preferHDR)
        #expect(settings.chromaFormat == .yuv444)
        #expect(settings.networkAdjustment == .optimalQuality)
        #expect(settings.prefilterMode == .auto)
        #expect(settings.hudSharpening)
    }

    @Test(
        "Highest-resolution presets stop at the TV's output height",
        arguments: [
            (StreamQualityPreset.cinematic, 2160, "3840x2160"),
            (.balanced, 2160, "3840x2160"),
            (.cinematic, 1080, "1920x1080"),
            (.cinematic, 480, "1280x720"),
        ]
    )
    func displayHeightCap(preset: StreamQualityPreset, displayHeight: Int, expected: String) {
        let context = StreamQualityPresetContext(
            entitledResolutions: nil,
            availableResolutions: ["1280x720", "1920x1080", "3840x2160", "5120x2880"],
            maximumDisplayFramesPerSecond: 60,
            maximumDisplayHeight: displayHeight
        )

        let settings = StreamQualityPresetPolicy.apply(preset, to: StreamSettings(), context: context)

        #expect(settings.resolution == expected)
    }

    @Test("Switching away from Cinematic clears its AI filter and HUD sharpening")
    func presetsResetVideoFilter() {
        let cinematic = StreamQualityPresetPolicy.apply(.cinematic, to: StreamSettings(), context: Self.ultimateContext)

        let competitive = StreamQualityPresetPolicy.apply(.competitive, to: cinematic, context: Self.ultimateContext)

        #expect(competitive.prefilterMode == .off)
        #expect(!competitive.hudSharpening)
        #expect(competitive.networkAdjustment == .optimalLatency)
    }

    @Test("Presets stay inside a Free-tier account's resolutions and frame rates")
    func freeTierClamping() {
        let context = StreamQualityPresetContext(
            entitledResolutions: [
                EntitledResolution(widthInPixels: 1280, heightInPixels: 720, framesPerSecond: 60),
                EntitledResolution(widthInPixels: 1920, heightInPixels: 1080, framesPerSecond: 60),
            ],
            availableResolutions: ["1280x720", "1920x1080"],
            maximumDisplayFramesPerSecond: 60
        )

        let cinematic = StreamQualityPresetPolicy.apply(.cinematic, to: StreamSettings(), context: context)
        let competitive = StreamQualityPresetPolicy.apply(.competitive, to: StreamSettings(), context: context)

        #expect(cinematic.resolution == "1920x1080")
        #expect(competitive.fps == 60)
    }

    @Test("Custom only records the selection")
    func customKeepsValues() {
        var settings = StreamSettings()
        settings.qualityPreset = .balanced
        settings.resolution = "2560x1440"
        settings.maxBitrateKbps = 35000

        let custom = StreamQualityPresetPolicy.apply(.custom, to: settings, context: Self.ultimateContext)

        #expect(custom.qualityPreset == .custom)
        #expect(custom.resolution == "2560x1440")
        #expect(custom.maxBitrateKbps == 35000)
    }

    @Test("Hourly data estimate follows the bitrate ceiling")
    func dataEstimate() {
        #expect(StreamQualityPresetPolicy.estimatedGigabytesPerHour(bitrateKbps: 50000) == 22.5)
        #expect(StreamQualityPresetPolicy.estimatedGigabytesPerHour(bitrateKbps: 100_000) == 45)
    }

    @Test(
        "Bitrate steps rejoin the 5 Mbps grid inside the 5-100 Mbps range",
        arguments: [
            (12000, 5000, 15000),
            (12000, -5000, 10000),
            (15000, 5000, 20000),
            (15000, -5000, 10000),
            (5000, -5000, 5000),
            (100_000, 5000, 100_000),
        ]
    )
    func bitrateStepping(start: Int, delta: Int, expected: Int) {
        #expect(GFNBitrateControl.steppedBitrate(start, delta: delta) == expected)
    }
}
