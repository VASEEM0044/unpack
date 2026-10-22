import SwiftUI

/// Settings view providing controls for default storage paths, security quotas, Keychain credentials, and appearance.
public struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var isSelectingDefaultFolder: Bool = false
    @State private var showClearPasswordsConfirmation: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()

                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        // Destination Directory Card
                        destinationDirectoryCard

                        // Automation & Preferences
                        preferencesCard

                        // Security & Quotas Card
                        securityQuotasCard

                        // Keychain Saved Passwords Card
                        keychainPasswordsCard

                        // Sideloading / Environment Info
                        sideloadingInfoCard
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.md)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isSelectingDefaultFolder) {
                DocumentPicker(mode: .selectFolder) { urls in
                    if let folder = urls.first {
                        SecurityScopedFileManager.shared.preferredExtractionDirectory = folder
                    }
                }
            }
            .confirmationDialog(
                "Clear all saved passwords?",
                isPresented: $showClearPasswordsConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All Passwords", role: .destructive) {
                    viewModel.clearAllSavedPasswords()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Destination Directory
    private var destinationDirectoryCard: some View {
        GlassCard(cornerRadius: DesignTokens.Radii.card) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Default Extraction Destination")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)

                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)
                    Text(SecurityScopedFileManager.shared.preferredExtractionDirectory.lastPathComponent)
                        .font(.body.weight(.medium))
                    Spacer()
                    Button("Change") {
                        isSelectingDefaultFolder = true
                    }
                    .font(.caption.weight(.semibold))

                    Button("Reset") {
                        SecurityScopedFileManager.shared.resetToDefaultExtractionDirectory()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Preferences
    private var preferencesCard: some View {
        GlassCard(cornerRadius: DesignTokens.Radii.card) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Toggle("Auto-delete archive after extraction", isOn: $viewModel.autoDeleteAfterExtraction)
                    .tint(.accentColor)

                Divider()

                Toggle("Tactile Haptic Feedback", isOn: $viewModel.enableHaptics)
                    .tint(.accentColor)

                Divider()

                HStack {
                    Text("Appearance")
                    Spacer()
                    Picker("Appearance", selection: $viewModel.appearanceMode) {
                        ForEach(SettingsViewModel.AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    // MARK: - Security & Quotas
    private var securityQuotasCard: some View {
        GlassCard(cornerRadius: DesignTokens.Radii.card) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(.green)
                    Text("Decompression Quotas & Limits")
                        .font(.subheadline.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Max Uncompressed Size:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(viewModel.maxUncompressedGigabytes)) GB")
                            .font(.caption.weight(.bold))
                    }
                    Slider(value: $viewModel.maxUncompressedGigabytes, in: 5...200, step: 5)
                        .tint(.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Max File Count Limit:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(viewModel.maxFileCountLimit) files")
                            .font(.caption.weight(.bold))
                    }
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.maxFileCountLimit) },
                            set: { viewModel.maxFileCountLimit = Int($0) }
                        ),
                        in: 5_000...100_000,
                        step: 5_000
                    )
                    .tint(.accentColor)
                }

                Toggle("Allow Security Limit Overrides", isOn: $viewModel.allowSecurityOverrides)
                    .tint(.red)
            }
        }
    }

    // MARK: - Keychain Passwords
    private var keychainPasswordsCard: some View {
        GlassCard(cornerRadius: DesignTokens.Radii.card) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(.orange)
                    Text("Keychain Password Vault")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if !viewModel.savedPasswordIdentifiers.isEmpty {
                        Button("Clear All") {
                            showClearPasswordsConfirmation = true
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }

                if viewModel.savedPasswordIdentifiers.isEmpty {
                    Text("No archive passwords currently saved in Keychain.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 4) {
                        ForEach(viewModel.savedPasswordIdentifiers, id: \.self) { identifier in
                            HStack {
                                Text(identifier)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                Spacer()
                                Button {
                                    viewModel.removeSavedPassword(identifier: identifier)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sideloading / TrollStore Environment Info
    private var sideloadingInfoCard: some View {
        GlassCard(cornerRadius: DesignTokens.Radii.card) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Environment & Build")
                        .font(.subheadline.weight(.semibold))
                }

                Text("Built with Swift 6 Strict Concurrency and native glassmorphism. Optimized for uninhibited sideloading via TrollStore, AltStore, and SideStore.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text("File Sharing in Files app:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Enabled (On My iPhone)")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.green)
                }
            }
        }
    }
}
