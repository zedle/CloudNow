@testable import CloudNow
import GameController
import Testing

@Suite("Controller face buttons")
struct ControllerFaceButtonsTests {
    @Test(
        "Only Apple's Nintendo product categories use label-based face buttons",
        arguments: [
            ("Switch Pro Controller", true),
            ("Nintendo Switch Joy-Con (L/R)", true),
            ("Nintendo Switch Joy-Con (L)", true),
            ("HID", false),
            ("MFi", false),
            ("Xbox One", false),
            ("DualSense", false),
        ]
    )
    func nintendoDetection(productCategory: String, expected: Bool) {
        #expect(ControllerFaceButtons.usesNintendoLabels(productCategory: productCategory) == expected)
    }

    @Test("Unknown controllers keep GameController's positions")
    func unknownControllerPassthrough() throws {
        #expect(!ControllerFaceButtons.usesNintendoLabels(productCategory: nil))
        let pad = try #require(GCController.withExtendedGamepad().extendedGamepad)
        let face = ControllerFaceButtons(pad)
        #expect(face.a === pad.buttonA)
        #expect(face.b === pad.buttonB)
        #expect(face.x === pad.buttonX)
        #expect(face.y === pad.buttonY)
    }

    @Test("The Nintendo swap setting defaults on and can be turned off")
    func swapSetting() throws {
        let suite = "ControllerFaceButtonsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(ControllerFaceButtons.swapEnabled(in: defaults))
        defaults.set(false, forKey: ControllerFaceButtons.swapSettingKey)
        #expect(!ControllerFaceButtons.swapEnabled(in: defaults))
    }
}
