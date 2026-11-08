import Foundation
@preconcurrency import GameController

/// Face buttons by Xbox position: A bottom, B right, X left, Y top.
///
/// Since iOS/tvOS 16, GameController names Nintendo controllers' face buttons by their printed
/// label, so `buttonA` is the right button on a Switch Pro Controller. Cloud games expect Xbox
/// positions, so Nintendo pads swap A/B and X/Y to keep the bottom button as the game's A.
///
/// Only the product category decides: label naming comes from Apple's Nintendo driver, which sets
/// a Switch category. Some generic Pro-style pads spoof Nintendo's vendor and product IDs, get the
/// same "Switch Pro Controller" category, and still need no swap, so the swap is a device-wide
/// Settings toggle (on by default).
nonisolated struct ControllerFaceButtons {
    let a: GCControllerButtonInput
    let b: GCControllerButtonInput
    let x: GCControllerButtonInput
    let y: GCControllerButtonInput

    static let swapSettingKey = "controller.swapNintendoFaceButtons"

    init(_ pad: GCExtendedGamepad, swapEnabled: Bool = Self.swapEnabled()) {
        if swapEnabled, Self.usesNintendoLabels(productCategory: pad.controller?.productCategory) {
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

    static func swapEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: swapSettingKey) as? Bool ?? true
    }

    static func usesNintendoLabels(productCategory: String?) -> Bool {
        guard let category = productCategory?.lowercased() else { return false }
        return category.contains("switch") || category.contains("joy-con") || category.contains("nintendo")
    }
}
