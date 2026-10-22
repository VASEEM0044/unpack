import SwiftUI

/// Modal sheet managing extraction configuration, destination selection, and real-time streaming progress.
public struct ExtractionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ExtractionViewModel

    public init(archiveURL: URL, selectedEntryPaths: Set<String>? = nil) {
        _viewModel = State(initialValue: ExtractionViewModel(
            archiveURL: archiveURL,
            selectedEntryPaths: selectedEntryPaths
        ))
    }

    public var body: some View {
        ZStack {
            MeshGradientBackground()

            VStack(spacing: DesignTokens.Spacing.lg) {
                // Header
                headerView

                // Dynamic State Body
                switch viewModel.state {
                case .configuring:
                    configurationView
                case .extracting(let progress):
                    progressView(progress: progress)
                case .passwordRequired:
                    passwordRequiredView
                case .completed(let destination):
                    completedView(destination: destination)
                case .failed(let message):
                    failedView(message: message)
                }

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $viewModel.isSelectingDestinationFolder) {
            DocumentPicker(mode: .selectFolder) { urls in
                if let folder = urls.first {
                    viewModel.destinationDirectory = folder
                    SecurityScopedFileManager.shared.saveCustomDestinationBookmark(url: folder)
                }
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            FileIconView(filename: viewModel.archiveURL.lastPathComponent, isDirectory: false, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.archiveURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                Text(viewModel.selectedEntryPaths == nil ? "Extracting all contents" : "Extracting \(viewModel.selectedEntryPaths!.count) selected items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    private var configurationView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Destination Card
            GlassCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Destination Folder")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                        Text(viewModel.destinationDirectory.lastPathComponent)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        Spacer()
                        Button("Change") {
                            viewModel.isSelectingDestinationFolder = true
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }

            // Options Card
            GlassCard {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    Toggle("Extract to subfolder", isOn: $viewModel.createSubfolder)
                        .tint(.accentColor)

                    Divider()

                    HStack {
                        Text("Collision Policy")
                            .font(.body)
                        Spacer()
                        Picker("Policy", selection: $viewModel.overwritePolicy) {
                            ForEach(OverwritePolicy.allCases) { policy in
                                Text(policy.title).tag(policy)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }

            // Start Button
            GlassButton("Start Unpacking", systemImage: "sparkles", style: .prominent) {
                viewModel.startExtraction()
            }
            .padding(.top, DesignTokens.Spacing.sm)
        }
    }

    private func progressView(progress: ExtractionProgress) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            GlassProgressRing(progress: progress.fractionCompleted, size: 90, lineWidth: 8)
                .padding(.top, DesignTokens.Spacing.sm)

            VStack(spacing: 4) {
                Text(progress.currentFilename.isEmpty ? "Preparing..." : progress.currentFilename)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    if !progress.formattedSpeed.isEmpty {
                        Text(progress.formattedSpeed)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let eta = progress.estimatedTimeRemaining {
                        Text("• ETA \(eta)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            GlassProgressBar(progress: progress.fractionCompleted, height: 12)

            GlassButton("Cancel", style: .destructive) {
                viewModel.cancel()
            }
            .frame(maxWidth: 160)
        }
    }

    private var passwordRequiredView: some View {
        PasswordPromptView(
            password: $viewModel.password,
            saveToKeychain: $viewModel.savePasswordToKeychain,
            errorMessage: "Wrong password. Please try again.",
            onUnlock: {
                viewModel.startExtraction()
            },
            onCancel: {
                viewModel.cancel()
            }
        )
    }

    private func completedView(destination: URL) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.18))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.green)
            }
            .padding(.top, DesignTokens.Spacing.sm)

            Text("Extraction Complete")
                .font(.title2.weight(.bold))

            Text("All items have been safely extracted to '\(destination.lastPathComponent)'.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: DesignTokens.Spacing.sm) {
                ShareLink(item: destination) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Folder")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .glassSurface(cornerRadius: DesignTokens.Radii.medium, material: .ultraThinMaterial)
                }

                GlassButton("Done", style: .prominent) {
                    dismiss()
                }
            }
            .padding(.top, DesignTokens.Spacing.sm)
        }
        .sensoryFeedback(.success, trigger: true)
    }

    private func failedView(message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)

            Text("Extraction Failed")
                .font(.title3.weight(.bold))

            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            GlassButton("Dismiss", style: .standard) {
                dismiss()
            }
            .frame(maxWidth: 160)
        }
        .sensoryFeedback(.error, trigger: true)
    }
}
