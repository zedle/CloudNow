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

    @Test("Existing settings without preset fields decode as Custom with network adaptation off")
    func legacyDecodingDefaults() throws {
        let json = Data(#"{"resolution":"3840x2160","fps":120,"maxBitrateKbps":80000}"#.utf8)

        let settings = try JSONDecoder().decode(StreamSettings.self, from: json)

        #expect(settings.qualityPreset == .custom)
        #expect(!settings.adjustForPoorNetwork)
        #expect(settings.resolution == "3840x2160")
        #expect(settings.maxBitrateKbps == 80000)
    }

    @Test("Preset fields round-trip and unknown presets fall back to Custom")
    func presetRoundTrip() throws {
        var settings = StreamSettings()
        settings.qualityPreset = .cinematic
        settings.adjustForPoorNetwork = true

        let decoded = try JSONDecoder().decode(
            StreamSettings.self,
            from: JSONEncoder().encode(settings)
        )
        let unknown = try JSONDecoder().decode(
            StreamSettings.self,
            from: Data(#"{"qualityPreset":"ultraMax"}"#.utf8)
        )

        #expect(decoded.qualityPreset == .cinematic)
        #expect(decoded.adjustForPoorNetwork)
        #expect(unknown.qualityPreset == .custom)
    }

    @Test("Data Saver requests 720p60 at 15 Mbps with network adaptation")
    func dataSaver() {
        let settings = StreamQualityPresetPolicy.apply(.dataSaver, to: StreamSettings(), context: Self.ultimateContext)

        #expect(settings.qualityPreset == .dataSaver)
        #expect(settings.resolution == "1280x720")
        #expect(settings.fps == 60)
        #expect(settings.maxBitrateKbps == 15000)
        #expect(settings.colorPreference == .forceSDR8)
        #expect(settings.chromaFormat == .yuv420)
        #expect(settings.adjustForPoorNetwork)
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
        #expect(!settings.adjustForPoorNetwork)
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
}
