import SwiftUI

/// Frosted modal prompt for decrypting password-protected archives with optional Face ID Keychain storage.
public struct PasswordPromptView: View {
    @Binding public var password: String
    @Binding public var saveToKeychain: Bool
    public let errorMessage: String?
    public let onUnlock: () -> Void
    public let onCancel: () -> Void

    public init(
        password: Binding<String>,
        saveToKeychain: Binding<Bool>,
        errorMessage: String? = nil,
        onUnlock: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._password = password
        self._saveToKeychain = saveToKeychain
        self.errorMessage = errorMessage
        self.onUnlock = onUnlock
        self.onCancel = onCancel
    }

    public var body: some View {
        GlassCard(cornerRadius: DesignTokens.Radii.large, padding: DesignTokens.Spacing.lg) {
            VStack(spacing: DesignTokens.Spacing.md) {
                // Lock Icon
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "lock.fill")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.accentColor)
                }

                // Heading
                VStack(spacing: DesignTokens.Spacing.xxs) {
                    Text("Password Protected")
                        .font(.headline)
                    Text("Enter the password to inspect and extract contents.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Secure Field
                GlassTextField(
                    "Archive Password",
                    text: $password,
                    isSecure: true,
                    systemImage: "key.fill"
                )

                // Error Message if any
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                // Keychain & Face ID toggle
                Toggle(isOn: $saveToKeychain) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "faceid")
                            .font(.body)
                        Text("Save to Keychain")
                            .font(.subheadline)
                    }
                }
                .tint(.accentColor)
                .padding(.horizontal, DesignTokens.Spacing.xs)

                // Actions
                HStack(spacing: DesignTokens.Spacing.sm) {
                    GlassButton("Cancel", style: .standard) {
                        onCancel()
                    }

                    GlassButton("Unlock", style: .prominent) {
                        onUnlock()
                    }
                    .disabled(password.isEmpty)
                }
            }
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
}
