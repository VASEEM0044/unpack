import SwiftUI
import Observation

/// ViewModel managing user preferences, security quotas, appearance tokens, and Keychain credentials.
@Observable
@MainActor
public final class SettingsViewModel {
    public enum AppearanceMode: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        public var id: String { rawValue }
    }

    // App Preferences
    public var autoDeleteAfterExtraction: Bool {
        didSet { UserDefaults.standard.set(autoDeleteAfterExtraction, forKey: "autoDeleteAfterExtraction") }
    }

    public var enableHaptics: Bool {
        didSet { UserDefaults.standard.set(enableHaptics, forKey: "enableHaptics") }
    }

    public var appearanceMode: AppearanceMode {
        didSet { UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode") }
    }

    // Security Quota Settings
    public var maxUncompressedGigabytes: Double {
        didSet { UserDefaults.standard.set(maxUncompressedGigabytes, forKey: "maxUncompressedGigabytes") }
    }

    public var maxFileCountLimit: Int {
        didSet { UserDefaults.standard.set(maxFileCountLimit, forKey: "maxFileCountLimit") }
    }

    public var maxCompressionRatioLimit: Double {
        didSet { UserDefaults.standard.set(maxCompressionRatioLimit, forKey: "maxCompressionRatioLimit") }
    }

    public var allowSecurityOverrides: Bool {
        didSet { UserDefaults.standard.set(allowSecurityOverrides, forKey: "allowSecurityOverrides") }
    }

    public var savedPasswordIdentifiers: [String] = []

    public init() {
        self.autoDeleteAfterExtraction = UserDefaults.standard.bool(forKey: "autoDeleteAfterExtraction")
        self.enableHaptics = UserDefaults.standard.object(forKey: "enableHaptics") as? Bool ?? true
        
        let savedMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? AppearanceMode.system.rawValue
        self.appearanceMode = AppearanceMode(rawValue: savedMode) ?? .system

        let savedGB = UserDefaults.standard.double(forKey: "maxUncompressedGigabytes")
        self.maxUncompressedGigabytes = savedGB > 0 ? savedGB : 50.0

        let savedCount = UserDefaults.standard.integer(forKey: "maxFileCountLimit")
        self.maxFileCountLimit = savedCount > 0 ? savedCount : 25_000

        let savedRatio = UserDefaults.standard.double(forKey: "maxCompressionRatioLimit")
        self.maxCompressionRatioLimit = savedRatio > 0 ? savedRatio : 100.0

        self.allowSecurityOverrides = UserDefaults.standard.bool(forKey: "allowSecurityOverrides")

        refreshSavedPasswords()
    }

    public func refreshSavedPasswords() {
        savedPasswordIdentifiers = KeychainPasswordManager.shared.listSavedArchiveIdentifiers()
    }

    public func removeSavedPassword(identifier: String) {
        try? KeychainPasswordManager.shared.deletePassword(for: identifier)
        refreshSavedPasswords()
    }

    public func clearAllSavedPasswords() {
        for id in savedPasswordIdentifiers {
            try? KeychainPasswordManager.shared.deletePassword(for: id)
        }
        refreshSavedPasswords()
    }
}
