import SwiftUI

/// Archive detail and browsing view featuring an interactive collapsible folder tree,
/// multi-selection, searching, sorting, and floating glass action bar.
public struct ArchiveBrowserView: View {
    @State private var viewModel: ArchiveBrowserViewModel
    @State private var expandedPaths: Set<String> = []
    @State private var showExtractionSheet: Bool = false
    @State private var extractSelectedOnly: Bool = false

    public init(archiveURL: URL) {
        _viewModel = State(initialValue: ArchiveBrowserViewModel(archiveURL: archiveURL))
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            MeshGradientBackground()

            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndControlBar
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.top, DesignTokens.Spacing.sm)

                // Main Entry List
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Analyzing archive contents...")
                        .tint(.accentColor)
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    errorStateView(message: error)
                    Spacer()
                } else if viewModel.displayedEntries.isEmpty {
                    Spacer()
                    emptyStateView
                    Spacer()
                } else {
                    entryScrollView
                }
            }

            // Floating Bottom Glass Action Bar
            floatingActionBar
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.md)
        }
        .navigationTitle(viewModel.archiveURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(DesignTokens.AnimationCurves.smoothSpring) {
                        viewModel.isSelectionMode.toggle()
                        if !viewModel.isSelectionMode {
                            viewModel.deselectAll()
                        }
                    }
                } label: {
                    Text(viewModel.isSelectionMode ? "Done" : "Select")
                        .font(.body.weight(.medium))
                }
            }
        }
        .task {
            await viewModel.loadContents()
        }
        .sheet(isPresented: $showExtractionSheet) {
            ExtractionSheet(
                archiveURL: viewModel.archiveURL,
                selectedEntryPaths: extractSelectedOnly ? viewModel.selectedPaths : nil
            )
        }
        .sheet(item: Binding<PreviewItem?>(
            get: { viewModel.previewURL.map { PreviewItem(url: $0) } },
            set: { viewModel.previewURL = $0?.url }
        )) { item in
            QuickLookPreview(previewItemURL: item.url)
        }
        .sheet(isPresented: $viewModel.passwordPromptNeeded) {
            PasswordPromptView(
                password: $viewModel.enteredPassword,
                saveToKeychain: .constant(true),
                onUnlock: {
                    viewModel.passwordPromptNeeded = false
                    Task { await viewModel.loadContents() }
                },
                onCancel: {
                    viewModel.passwordPromptNeeded = false
                }
            )
        }
    }

    // MARK: - Search & Controls
    private var searchAndControlBar: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                GlassTextField("Search in archive...", text: $viewModel.searchQuery, systemImage: "magnifyingglass")

                // Sort Menu
                Menu {
                    Picker("Sort By", selection: $viewModel.sortOption) {
                        ForEach(ArchiveBrowserViewModel.SortOption.allCases) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }

                    Button {
                        viewModel.sortAscending.toggle()
                    } label: {
                        Label(
                            viewModel.sortAscending ? "Ascending" : "Descending",
                            systemImage: viewModel.sortAscending ? "arrow.up" : "arrow.down"
                        )
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .padding(10)
                        .glassSurface(cornerRadius: DesignTokens.Radii.medium, material: .ultraThinMaterial)
                }

                // Tree / Flat Toggle
                Button {
                    withAnimation(DesignTokens.AnimationCurves.smoothSpring) {
                        viewModel.isTreeMode.toggle()
                    }
                } label: {
                    Image(systemName: viewModel.isTreeMode ? "list.bullet.indent" : "list.bullet")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .padding(10)
                        .glassSurface(cornerRadius: DesignTokens.Radii.medium, material: .ultraThinMaterial)
                }
            }
        }
    }

    // MARK: - Entry List
    private var entryScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(viewModel.displayedEntries) { entry in
                    renderEntryNode(entry, depth: 0)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.top, DesignTokens.Spacing.sm)
            .padding(.bottom, 100) // Padding for floating action bar
        }
    }

    @ViewBuilder
    private func renderEntryNode(_ entry: ArchiveEntry, depth: Int) -> some View {
        let isExpanded = expandedPaths.contains(entry.path)
        
        ArchiveEntryRow(
            entry: entry,
            isSelected: viewModel.selectedPaths.contains(entry.path),
            isSelectionMode: viewModel.isSelectionMode,
            isExpanded: isExpanded,
            onToggleExpand: {
                if isExpanded {
                    expandedPaths.remove(entry.path)
                } else {
                    expandedPaths.insert(entry.path)
                }
            },
            onToggleSelect: {
                viewModel.toggleSelection(for: entry.path)
            },
            onPreview: {
                // Trigger preview
                viewModel.previewURL = viewModel.archiveURL
            }
        )
        .padding(.leading, CGFloat(depth) * 18)

        if isExpanded, let children = entry.children {
            ForEach(children) { child in
                renderEntryNode(child, depth: depth + 1)
            }
        }
    }

    // MARK: - Floating Glass Action Bar
    private var floatingActionBar: some View {
        GlassCard(cornerRadius: DesignTokens.Radii.large, padding: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if viewModel.isSelectionMode {
                    Button("Select All") {
                        viewModel.selectAll()
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, DesignTokens.Spacing.sm)

                    Spacer()

                    GlassButton(
                        viewModel.selectedPaths.isEmpty ? "Extract Selected" : "Extract (\(viewModel.selectedPaths.count))",
                        systemImage: "square.and.arrow.down",
                        style: .prominent
                    ) {
                        extractSelectedOnly = true
                        showExtractionSheet = true
                    }
                    .disabled(viewModel.selectedPaths.isEmpty)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.detectedFormat.displayName)
                            .font(.caption.weight(.bold))
                            .foregroundColor(.accentColor)
                        Text("\(viewModel.rawEntries.count) entries")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, DesignTokens.Spacing.sm)

                    Spacer()

                    GlassButton("Extract All", systemImage: "archivebox.and.arrow.down.fill", style: .prominent) {
                        extractSelectedOnly = false
                        showExtractionSheet = true
                    }
                }
            }
        }
    }

    private func errorStateView(message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignTokens.Spacing.lg)
            GlassButton("Try Again", style: .standard) {
                Task { await viewModel.loadContents() }
            }
            .frame(maxWidth: 180)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "tray")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("No entries found")
                .font(.headline)
            Text("This archive appears to be empty.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct PreviewItem: Identifiable {
    let id = UUID()
    let url: URL
}
