import Foundation

public enum SessionType: String, Codable, Equatable, Sendable {
    case pushToTalk
    case longDraft
}

public enum OutputMode: String, Codable, Equatable, Sendable {
    case cursorPaste
    case clipboardDraft
    case fallbackCopy
    case floatingDraft
}

public struct OutputPolicy: Codable, Equatable, Sendable {
    public var autoPasteEnabled: Bool
    public var restoreClipboardAfterPaste: Bool
    public var downgradeToClipboardWhenFocusChanges: Bool
    public var pasteSecureFields: Bool
    public var preferClipboardForLowConfidence: Bool
    public var forcePasteWhenFocusLowConfidenceForBundleIds: [String]

    public init(
        autoPasteEnabled: Bool = true,
        restoreClipboardAfterPaste: Bool = false,
        downgradeToClipboardWhenFocusChanges: Bool = true,
        pasteSecureFields: Bool = false,
        preferClipboardForLowConfidence: Bool = true,
        forcePasteWhenFocusLowConfidenceForBundleIds: [String] = []
    ) {
        self.autoPasteEnabled = autoPasteEnabled
        self.restoreClipboardAfterPaste = restoreClipboardAfterPaste
        self.downgradeToClipboardWhenFocusChanges = downgradeToClipboardWhenFocusChanges
        self.pasteSecureFields = pasteSecureFields
        self.preferClipboardForLowConfidence = preferClipboardForLowConfidence
        self.forcePasteWhenFocusLowConfidenceForBundleIds = forcePasteWhenFocusLowConfidenceForBundleIds
    }

    public static let `default` = OutputPolicy()

    enum CodingKeys: String, CodingKey {
        case autoPasteEnabled
        case restoreClipboardAfterPaste
        case downgradeToClipboardWhenFocusChanges
        case pasteSecureFields
        case preferClipboardForLowConfidence
        case forcePasteWhenFocusLowConfidenceForBundleIds
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = OutputPolicy.default
        autoPasteEnabled = try values.decodeIfPresent(Bool.self, forKey: .autoPasteEnabled) ?? defaults.autoPasteEnabled
        restoreClipboardAfterPaste = try values.decodeIfPresent(Bool.self, forKey: .restoreClipboardAfterPaste) ?? defaults.restoreClipboardAfterPaste
        downgradeToClipboardWhenFocusChanges = try values.decodeIfPresent(Bool.self, forKey: .downgradeToClipboardWhenFocusChanges) ?? defaults.downgradeToClipboardWhenFocusChanges
        pasteSecureFields = try values.decodeIfPresent(Bool.self, forKey: .pasteSecureFields) ?? defaults.pasteSecureFields
        preferClipboardForLowConfidence = try values.decodeIfPresent(Bool.self, forKey: .preferClipboardForLowConfidence) ?? defaults.preferClipboardForLowConfidence
        forcePasteWhenFocusLowConfidenceForBundleIds = try values.decodeIfPresent([String].self, forKey: .forcePasteWhenFocusLowConfidenceForBundleIds) ?? defaults.forcePasteWhenFocusLowConfidenceForBundleIds
    }
}

public enum OutputModeRouter {
    public static func decide(
        snapshot: FocusSnapshot,
        sessionType: SessionType,
        focusChangedDuringRecording: Bool = false,
        policy: OutputPolicy = .default
    ) -> OutputMode {
        if sessionType == .longDraft {
            return .floatingDraft
        }

        if focusChangedDuringRecording && policy.downgradeToClipboardWhenFocusChanges {
            return .clipboardDraft
        }

        if snapshot.isSecureTextField && !policy.pasteSecureFields {
            return .clipboardDraft
        }

        guard policy.autoPasteEnabled else {
            return .clipboardDraft
        }

        if snapshot.confidence == .low,
           let bundleId = snapshot.frontmostAppBundleId,
           policy.forcePasteWhenFocusLowConfidenceForBundleIds.contains(bundleId) {
            return .cursorPaste
        }

        if snapshot.isEditable && snapshot.canPaste {
            switch snapshot.confidence {
            case .high, .medium:
                return .cursorPaste
            case .low:
                return policy.preferClipboardForLowConfidence ? .clipboardDraft : .cursorPaste
            }
        }

        return .clipboardDraft
    }
}
