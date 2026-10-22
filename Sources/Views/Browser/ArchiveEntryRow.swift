import SwiftUI

/// Single row representing a file or directory inside an archive.
public struct ArchiveEntryRow: View {
    public let entry: ArchiveEntry
    public let isSelected: Bool
    public let isSelectionMode: Bool
    public let isExpanded: Bool
    public let onToggleExpand: () -> Void
    public let onToggleSelect: () -> Void
    public let onPreview: () -> Void

    public init(
        entry: ArchiveEntry,
        isSelected: Bool = false,
        isSelectionMode: Bool = false,
        isExpanded: Bool = false,
        onToggleExpand: @escaping () -> Void = {},
        onToggleSelect: @escaping () -> Void = {},
        onPreview: @escaping () -> Void = {}
    ) {
        self.entry = entry
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
        self.isExpanded = isExpanded
        self.onToggleExpand = onToggleExpand
        self.onToggleSelect = onToggleSelect
        self.onPreview = onPreview
    }

    public var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Selection Checkbox
            if isSelectionMode {
                Button(action: onToggleSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            // Folder chevron if directory with children
            if entry.isDirectory {
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                }
                .buttonStyle(.plain)
            } else {
                Spacer()
                    .frame(width: 16)
            }

            // File Icon
            FileIconView(filename: entry.filename, isDirectory: entry.isDirectory, size: 36)

            // Name and Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.filename)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if entry.isEncrypted {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }

                HStack(spacing: DesignTokens.Spacing.xs) {
                    if !entry.isDirectory {
                        Text(ByteCountFormatter.string(fromByteCount: entry.uncompressedSize, countStyle: .file))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if entry.compressionRatio > 1.05 {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary.opacity(0.5))

                            Text("\(String(format: "%.1f", entry.compressionRatio))x")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    } else {
                        if let childCount = entry.children?.count {
                            Text("\(childCount) items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Folder")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Preview Action for non-directories
            if !entry.isDirectory && !isSelectionMode {
                Button(action: onPreview) {
                    Image(systemName: "eye")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Circle().fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onToggleSelect()
            } else if entry.isDirectory {
                onToggleExpand()
            } else {
                onPreview()
            }
        }
    }
}
