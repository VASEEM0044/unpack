import SwiftUI

/// Renders a modern, visually categorized icon for archive files and filesystem entries.
public struct FileIconView: View {
    public let filename: String
    public let isDirectory: Bool
    public let size: CGFloat

    public init(filename: String, isDirectory: Bool, size: CGFloat = 36) {
        self.filename = filename
        self.isDirectory = isDirectory
        self.size = size
    }

    private var ext: String {
        (filename as NSString).pathExtension.lowercased()
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(backgroundColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                        .strokeBorder(backgroundColor.opacity(0.3), lineWidth: 0.5)
                )

            Image(systemName: systemIconName)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundColor(backgroundColor)
        }
        .frame(width: size, height: size)
    }

    private var systemIconName: String {
        if isDirectory {
            return "folder.fill"
        }
        switch ext {
        case "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "iso", "cab", "cbr", "cb7":
            return "archivebox.fill"
        case "pdf":
            return "doc.richtext.fill"
        case "jpg", "jpeg", "png", "heic", "gif", "webp", "svg":
            return "photo.fill"
        case "mp4", "mov", "m4v", "mkv", "avi":
            return "film.fill"
        case "mp3", "m4a", "flac", "wav", "aac":
            return "waveform"
        case "swift", "json", "py", "js", "ts", "html", "css", "c", "cpp", "h", "xml", "yml", "yaml":
            return "curlybraces"
        case "txt", "md", "rtf", "log":
            return "doc.text.fill"
        default:
            return "doc.fill"
        }
    }

    private var backgroundColor: Color {
        if isDirectory {
            return .blue
        }
        switch ext {
        case "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "iso", "cab":
            return .accentColor
        case "pdf":
            return .red
        case "jpg", "jpeg", "png", "heic", "gif", "webp", "svg":
            return .purple
        case "mp4", "mov", "m4v", "mkv", "avi":
            return .pink
        case "mp3", "m4a", "flac", "wav", "aac":
            return .orange
        case "swift", "json", "py", "js", "ts", "html", "css", "c", "cpp", "h", "xml", "yml":
            return .cyan
        case "txt", "md", "rtf":
            return .gray
        default:
            return .secondary
        }
    }
}
