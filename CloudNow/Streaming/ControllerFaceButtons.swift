import Foundation
@preconcurrency import GameController

/// Face buttons by Xbox position: A bottom, B right, X left, Y top.
///
/// Since iOS/tvOS 16, GameController names Nintendo controllers' face buttons by their printed
/// label, so `buttonA` is the right button on a Switch Pro Controller. Cloud games expect Xbox
/// positions, so Nintendo pads swap A/B and X/Y to keep the bottom button as the game's A.
///
/// Only the product category decides: label naming comes from Apple's Nintendo driver, which sets
/// a Switch category. Generic pads arrive as HID/MFi with positional names, even when their
/// `vendorName` says "Pro Controller" or "Nintendo".
nonisolated struct ControllerFaceButtons {
    let a: GCControllerButtonInput
    let b: GCControllerButtonInput
    let x: GCControllerButtonInput
    let y: GCControllerButtonInput

    init(_ pad: GCExtendedGamepad) {
        if Self.usesNintendoLabels(productCategory: pad.controller?.productCategory) {
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

    static func usesNintendoLabels(productCategory: String?) -> Bool {
        guard let category = productCategory?.lowercased() else { return false }
        return category.contains("switch") || category.contains("joy-con") || category.contains("nintendo")
    }
}
