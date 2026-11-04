import Foundation
@preconcurrency import GameController

/// Face buttons by Xbox position: A bottom, B right, X left, Y top.
///
/// Since iOS/tvOS 16, GameController names Nintendo controllers' face buttons by their printed
/// label, so `buttonA` is the right button on a Switch Pro Controller. Cloud games expect Xbox
/// positions, so Nintendo pads swap A/B and X/Y to keep the bottom button as the game's A.
nonisolated struct ControllerFaceButtons {
    let a: GCControllerButtonInput
    let b: GCControllerButtonInput
    let x: GCControllerButtonInput
    let y: GCControllerButtonInput

    init(_ pad: GCExtendedGamepad) {
        if Self.usesNintendoLabels(
            productCategory: pad.controller?.productCategory,
            vendorName: pad.controller?.vendorName
        ) {
            a = pad.buttonB
            b = pad.buttonA
            x = pad.buttonY
            y = pad.buttonX
        } else {
            a = pad.buttonA
            b = pad.buttonB
            x = pad.buttonX
            y = pad.buttonY
        }
    }

    static func usesNintendoLabels(productCategory: String?, vendorName: String?) -> Bool {
        [productCategory, vendorName].contains { name in
            guard let name = name?.lowercased() else { return false }
            return name.contains("switch") || name.contains("joy-con") || name.contains("nintendo")
        }
    }
}
