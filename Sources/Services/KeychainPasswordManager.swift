import Foundation
import Security
import LocalAuthentication

/// Manages secure persistence of archive passwords in the iOS Keychain with optional Face ID / Touch ID validation.
public final class KeychainPasswordManager: @unchecked Sendable {
    public static let shared = KeychainPasswordManager()

    private let service = "com.unpack.archive-passwords"

    private init() {}

    /// Saves a password for a specific archive.
    public func savePassword(_ password: String, for archiveIdentifier: String) throws {
        guard let data = password.data(using: .utf8) else { return }

        // Remove any existing entry first
        try? deletePassword(for: archiveIdentifier)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: archiveIdentifier,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ArchiveSecurityError.corruptArchive(message: "Failed to persist password in Keychain (Status: \(status)).")
        }
    }

    /// Retrieves a password from Keychain, with optional biometric authentication.
    public func retrievePassword(for archiveIdentifier: String, requireBiometrics: Bool = false) async throws -> String? {
        if requireBiometrics {
            let context = LAContext()
            var authError: NSError?
            if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
                let reason = String(localized: "Authenticate with Face ID to retrieve saved archive password.")
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                guard success else {
                    throw ArchiveSecurityError.unauthorized(reason: "Face ID authentication failed.")
                }
            }
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: archiveIdentifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// Deletes a password from the Keychain.
    public func deletePassword(for archiveIdentifier: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: archiveIdentifier
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Lists all archive identifiers that have saved passwords.
    public func listSavedArchiveIdentifiers() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let items = item as? [[String: Any]] else {
            return []
        }

        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
}
