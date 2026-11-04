import AVFoundation
import AVKit
import CoreMedia
import UIKit

/// Asks tvOS to switch the TV's output mode for an HDR10 stream. Only has an effect when the
/// user enabled Match Content in Apple TV Settings; otherwise tvOS ignores the criteria and the
/// output keeps its configured format.
@MainActor enum DisplayDynamicRangeRequest {
    static var isMatchingEnabled: Bool {
        displayManager?.isDisplayCriteriaMatchingEnabled ?? false
    }

    /// Requests an HDR10 output at `frameRate` while `hdr10` is true and clears the request
    /// otherwise.
    static func update(hdr10: Bool, width: Int, height: Int, frameRate: Int) {
        guard hdr10, let manager = displayManager, manager.isDisplayCriteriaMatchingEnabled,
              let format = hdr10FormatDescription(width: width, height: height)
        else {
            clear()
            return
        }
        manager.preferredDisplayCriteria = AVDisplayCriteria(
            refreshRate: Float(frameRate),
            formatDescription: format
        )
    }

    /// Returns the TV to the user's configured output format.
    static func clear() {
        guard let manager = displayManager, manager.preferredDisplayCriteria != nil else { return }
        manager.preferredDisplayCriteria = nil
    }

    private static var displayManager: AVDisplayManager? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .avDisplayManager
    }

    private static func hdr10FormatDescription(width: Int, height: Int) -> CMVideoFormatDescription? {
        let extensions: [CFString: Any] = [
            kCMFormatDescriptionExtension_ColorPrimaries: kCMFormatDescriptionColorPrimaries_ITU_R_2020,
            kCMFormatDescriptionExtension_TransferFunction: kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ,
            kCMFormatDescriptionExtension_YCbCrMatrix: kCMFormatDescriptionYCbCrMatrix_ITU_R_2020,
        ]
        var format: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            codecType: kCMVideoCodecType_HEVC,
            width: Int32(width),
            height: Int32(height),
            extensions: extensions as CFDictionary,
            formatDescriptionOut: &format
        )
        return status == noErr ? format : nil
    }
}
