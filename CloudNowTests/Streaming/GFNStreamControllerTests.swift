@testable import CloudNow
import Foundation
import Testing

@Suite("GFN stream configuration")
@MainActor
struct GFNStreamControllerTests {
    @Test(
        "NVST retains 4K stream settings and selected chroma with codec fallback",
        arguments: [
            (VideoCodec.automatic, ChromaFormat.yuv420, 0),
            (.automatic, .yuv444, 1),
            (.h265, .yuv420, 0),
            (.h265, .yuv444, 1),
            (.h264, .yuv444, 0),
            (.av1, .yuv444, 0),
        ]
    )
    func nvstChromaRequest(codec: VideoCodec, chroma: ChromaFormat, expected: Int) throws {
        var settings = StreamSettings()
        settings.resolution = "3840x2160"
        settings.fps = 120
        settings.maxBitrateKbps = 100_000
        settings.codec = codec
        settings.chromaFormat = chroma
        settings.colorPreference = .forceSDR8
        let controller = GFNStreamController()

        let sdp = controller.buildNvstSdp(
            settings: settings,
            iceUfrag: "fixture-user",
            icePwd: "fixture-password",
            dtlsFingerprint: "fixture-fingerprint",
            microphoneEnabled: false
        )
        let video = try #require(sdp.components(separatedBy: "m=video 0 RTP/AVP\r\n").last)
            .components(separatedBy: "m=audio 0 RTP/AVP")[0]
        let chromaAttributes = video.components(separatedBy: "\r\n")
            .filter { $0.hasPrefix("a=video.chromaFormat:") }

        #expect(chromaAttributes == ["a=video.chromaFormat:\(expected)"])
        #expect(video.contains("a=video.clientViewportWd:3840\r\n"))
        #expect(video.contains("a=video.clientViewportHt:2160\r\n"))
        #expect(video.contains("a=video.maxFPS:120\r\n"))
        #expect(video.contains("a=vqos.bw.maximumBitrateKbps:100000\r\n"))
        #expect(video.contains("a=video.bitDepth:8\r\n"))
        #expect(sdp.contains("a=general.iceUserNameFragment:fixture-user\r\n"))
        #expect(sdp.contains("a=general.icePassword:fixture-password\r\n"))
        #expect(sdp.contains("a=general.dtlsFingerprint:fixture-fingerprint\r\n"))
    }

    @Test(
        "NVST network adaptation sends the native dynamic streaming mode",
        arguments: [
            (NetworkAdjustmentMode.off, 0),
            (.optimalLatency, 1),
            (.optimalQuality, 1),
        ]
    )
    func nvstNetworkAdjustment(mode: NetworkAdjustmentMode, expectedDrc: Int) {
        var settings = StreamSettings()
        settings.networkAdjustment = mode

        let sdp = buildSdp(settings)

        #expect(sdp.contains("a=vqos.dynamicStreamingMode:\(mode.rawValue)\r\n"))
        #expect(sdp.contains("a=vqos.drc.enable:\(expectedDrc)\r\n"))
        #expect(sdp.contains("a=vqos.dfc.enable:0\r\n"))
    }

    @Test("NVST advertises the native adaptive and burst-loss FEC defaults")
    func nvstLossProtection() {
        let sdp = buildSdp(StreamSettings())

        #expect(sdp.contains("a=vqos.fec.repairPercent:5\r\n"))
        #expect(sdp.contains("a=vqos.fec.repairMinPercent:5\r\n"))
        #expect(sdp.contains("a=vqos.fec.repairMaxPercent:40\r\n"))
        #expect(sdp.contains("a=vqos.bllFec.enable:1\r\n"))
        #expect(sdp.contains("a=vqos.bllFec.repairMinPercent:5\r\n"))
    }

    @Test("NVST prefilter parameters require a membership entitlement")
    func nvstPrefilterEntitlement() throws {
        var settings = StreamSettings()
        settings.prefilterMode = .custom
        settings.prefilterDenoiseLevel = 3
        settings.prefilterSharpnessLevel = 6
        let entitled = GFNStreamingFeatureEntitlements(prefilterModes: [.off, .auto, .custom], hudStreaming: true)

        let unknown = buildSdp(settings)
        let allowed = buildSdp(settings, streamingFeatures: entitled)
        let video = try #require(allowed.components(separatedBy: "m=audio").first)

        #expect(!unknown.contains("prefilterParams"))
        #expect(video.contains("a=video.prefilterParams.prefilterMode:2\r\n"))
        #expect(video.contains("a=video.prefilterParams.denoiseLevel:3\r\n"))
        #expect(video.contains("a=video.prefilterParams.sharpnessLevel:6\r\n"))
    }

    private func buildSdp(
        _ settings: StreamSettings,
        streamingFeatures: GFNStreamingFeatureEntitlements? = nil
    ) -> String {
        GFNStreamController().buildNvstSdp(
            settings: settings,
            iceUfrag: "fixture-user",
            icePwd: "fixture-password",
            dtlsFingerprint: "fixture-fingerprint",
            microphoneEnabled: false,
            streamingFeatures: streamingFeatures
        )
    }
}
