import SwiftUI

/// Modal sheet for creating new archives from files or folders with optional AES-256 encryption.
public struct CompressionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CompressionViewModel

    public init(sourceURLs: [URL]) {
        _viewModel = State(initialValue: CompressionViewModel(sourceURLs: sourceURLs))
    }

    public var body: some View {
        ZStack {
            MeshGradientBackground()

            VStack(spacing: DesignTokens.Spacing.lg) {
                // Header
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Create Archive")
                            .font(.headline)
                        Text("\(viewModel.sourceURLs.count) items selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                switch viewModel.state {
                case .configuring:
                    configurationView
                case .compressing(let progress):
                    progressView(progress: progress)
                case .completed(let url):
                    completedView(archiveURL: url)
                case .failed(let message):
                    failedView(message: message)
                }

                Spacer()
            }
            .padding(DesignTokens.Spacing.lg)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var configurationView: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Archive Name Field
            GlassCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Archive Name")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    GlassTextField("Filename", text: $viewModel.archiveName, systemImage: "pencil")
                }
            }

            // Format & Compression Level
            GlassCard {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Format")
                        Spacer()
                        Picker("Format", selection: $viewModel.selectedFormat) {
                            Text("ZIP").tag(ArchiveFormat.zip)
                            Text("7-Zip (7z)").tag(ArchiveFormat.sevenZip)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 180)
                    }

                    Divider()

                    HStack {
                        Text("Compression Level")
                        Spacer()
                        Picker("Level", selection: $viewModel.compressionLevel) {
                            ForEach(CompressionLevel.allCases) { lvl in
                                Text(lvl.title).tag(lvl)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }

            // Security & Password
            GlassCard {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    GlassTextField(
                        "Optional Password",
                        text: $viewModel.password,
                        isSecure: true,
                        systemImage: "lock.shield.fill"
                    )

                    if !viewModel.password.isEmpty {
                        Toggle("Use AES-256 Encryption", isOn: $viewModel.useAES256)
                            .tint(.accentColor)
                    }
                }
            }

            // Action Button
            GlassButton("Create Archive", systemImage: "sparkles", style: .prominent) {
                viewModel.startCompression()
            }
            .disabled(viewModel.archiveName.isEmpty)
        }
    }

    private func progressView(progress: ExtractionProgress) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            GlassProgressRing(progress: progress.fractionCompleted, size: 84)

            VStack(spacing: 4) {
                Text(progress.currentFilename.isEmpty ? "Compressing..." : progress.currentFilename)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(Int(progress.fractionCompleted * 100))% complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GlassProgressBar(progress: progress.fractionCompleted, height: 10)

            GlassButton("Cancel", style: .destructive) {
                viewModel.cancel()
            }
            .frame(maxWidth: 160)
        }
    }

    private func completedView(archiveURL: URL) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Archive Created")
                .font(.title2.weight(.bold))

            Text("Successfully created '\(archiveURL.lastPathComponent)'.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: DesignTokens.Spacing.sm) {
                ShareLink(item: archiveURL) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .glassSurface(cornerRadius: DesignTokens.Radii.medium, material: .ultraThinMaterial)
                }

                GlassButton("Done", style: .prominent) {
                    dismiss()
                }
            }
        }
    }

    private func failedView(message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 56))
                .foregroundColor(.red)

            Text("Compression Failed")
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
    }
}
