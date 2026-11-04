@testable import CloudNow
import GameController
import Testing

@Suite("Controller face buttons")
struct ControllerFaceButtonsTests {
    @Test(
        "Nintendo controllers are detected by product category or vendor name",
        arguments: [
            ("Switch Pro Controller", "Pro Controller", true),
            ("Nintendo Switch Joy-Con (L/R)", "Joy-Con (L/R)", true),
            ("HID", "Nintendo Switch 2 Pro Controller", true),
            ("Xbox One", "Xbox Wireless Controller", false),
            ("DualSense", "DualSense Wireless Controller", false),
            ("MFi", "8BitDo SN30 Pro", false),
        ]
    )
    func nintendoDetection(productCategory: String, vendorName: String, expected: Bool) {
        #expect(
            ControllerFaceButtons.usesNintendoLabels(
                productCategory: productCategory,
                vendorName: vendorName
            ) == expected
        )
    }

    @Test("Unknown controllers keep GameController's positions")
    func unknownControllerPassthrough() throws {
        #expect(!ControllerFaceButtons.usesNintendoLabels(productCategory: nil, vendorName: nil))
        let pad = try #require(GCController.withExtendedGamepad().extendedGamepad)
        let face = ControllerFaceButtons(pad)
        #expect(face.a === pad.buttonA)
        #expect(face.b === pad.buttonB)
        #expect(face.x === pad.buttonX)
        #expect(face.y === pad.buttonY)
    }
}
