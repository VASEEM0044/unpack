import SwiftUI

/// Main dashboard displaying Recent Archives, Extracted Items, Quick Import actions, and storage metrics.
public struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var showDocumentPicker: Bool = false
    @State private var showCompressPicker: Bool = false
    @State private var filesToCompress: [URL] = []
    @State private var showCompressionSheet: Bool = false
    @State private var activeArchiveForBrowsing: URL?
    @State private var isTargetedForDrop: Bool = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()

                ScrollView {
                    VStack(spacing: DesignTokens.Spacing.lg) {
                        // Storage & Quick Metrics
                        storageMetricsCard

                        // Quick Actions
                        quickActionsRow

                        // Recent Archives Section
                        recentArchivesSection

                        // Extracted Folders Section
                        extractedItemsSection
                    }
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.md)
                }
            }
            .navigationTitle("Unpack")
            .navigationDestination(item: $activeArchiveForBrowsing) { url in
                ArchiveBrowserView(archiveURL: url)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(mode: .openArchives, allowsMultipleSelection: true) { urls in
                    if let first = urls.first {
                        let staged = SecurityScopedFileManager.shared.stageArchiveForInspection(from: first)
                        viewModel.addRecentArchive(url: staged)
                        activeArchiveForBrowsing = staged
                    }
                }
            }
            .sheet(isPresented: $showCompressPicker) {
                DocumentPicker(mode: .openArchives, allowsMultipleSelection: true) { urls in
                    if !urls.isEmpty {
                        filesToCompress = urls
                        showCompressionSheet = true
                    }
                }
            }
            .sheet(isPresented: $showCompressionSheet) {
                CompressionSheet(sourceURLs: filesToCompress)
            }
            .onDrop(of: [.item], isTargeted: $isTargetedForDrop) { providers in
                handleDrop(providers: providers)
            }
            .onAppear {
                viewModel.refreshExtractedItems()
            }
        }
    }

    // MARK: - Storage Metrics Card
    private var storageMetricsCard: some View {
        GlassCard(cornerRadius: DesignTokens.Radii.large, padding: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    Image(systemName: "internaldrive.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Extracted Storage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ByteCountFormatter.string(fromByteCount: viewModel.totalExtractedSize, countStyle: .file))
                        .font(.title2.weight(.bold))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Extracted Items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.extractedItems.count)")
                        .font(.title3.weight(.semibold))
                }
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsRow: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            GlassCard(cornerRadius: DesignTokens.Radii.card, padding: DesignTokens.Spacing.sm) {
                Button {
                    showDocumentPicker = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.doc.fill")
                            .foregroundColor(.accentColor)
                            .font(.title3)
                        Text("Open Archive")
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }

            GlassCard(cornerRadius: DesignTokens.Radii.card, padding: DesignTokens.Spacing.sm) {
                Button {
                    showCompressPicker = true
                } label: {
                    HStack {
                        Image(systemName: "archivebox.circle.fill")
                            .foregroundColor(.purple)
                            .font(.title3)
                        Text("New Archive")
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Recent Archives Section
    private var recentArchivesSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Text("Recent Archives")
                    .font(.headline)
                Spacer()
                if !viewModel.recentArchives.isEmpty {
                    Button("Clear") {
                        viewModel.clearAllRecents()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            if viewModel.recentArchives.isEmpty {
                emptyPlaceholder(
                    icon: "archivebox",
                    title: "No Recent Archives",
                    subtitle: "Tap 'Open Archive' or drag files here to start."
                )
            } else {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(viewModel.recentArchives, id: \.path) { url in
                        Button {
                            viewModel.addRecentArchive(url: url)
                            activeArchiveForBrowsing = url
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                FileIconView(filename: url.lastPathComponent, isDirectory: false, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(url.lastPathComponent)
                                        .font(.body.weight(.medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(url.deletingLastPathComponent().path)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .glassSurface(cornerRadius: DesignTokens.Radii.medium, material: .ultraThinMaterial)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Extracted Items Section
    private var extractedItemsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("Extracted Items")
                .font(.headline)

            if viewModel.extractedItems.isEmpty {
                emptyPlaceholder(
                    icon: "folder",
                    title: "No Extracted Files",
                    subtitle: "Extracted items appear here and in your Files app."
                )
            } else {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(viewModel.extractedItems, id: \.path) { url in
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            FileIconView(filename: url.lastPathComponent, isDirectory: url.hasDirectoryPath, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent)
                                    .font(.body.weight(.medium))
                                    .lineLimit(1)
                                Text("In Files / Extracted")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            ShareLink(item: url) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .glassSurface(cornerRadius: DesignTokens.Radii.medium, material: .ultraThinMaterial)
                    }
                }
            }
        }
    }

    private func emptyPlaceholder(icon: String, title: String, subtitle: String) -> some View {
        GlassCard(cornerRadius: DesignTokens.Radii.card, padding: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadInPlaceFileRepresentation(forTypeIdentifier: "public.item") { url, inPlace, error in
                if let url {
                    let staged = SecurityScopedFileManager.shared.stageArchiveForInspection(from: url)
                    DispatchQueue.main.async {
                        viewModel.addRecentArchive(url: staged)
                        activeArchiveForBrowsing = staged
                    }
                }
            }
        }
        return true
    }
}
