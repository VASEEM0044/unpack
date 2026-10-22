import Foundation

/// Supported archive file formats with magic byte signatures and capability descriptors.
public enum ArchiveFormat: String, CaseIterable, Identifiable, Sendable {
    case zip
    case rar
    case sevenZip = "7z"
    case tar
    case tarGz = "tar.gz"
    case tarBz2 = "tar.bz2"
    case tarXz = "tar.xz"
    case gz
    case bz2
    case xz
    case iso
    case cab
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .zip: return "ZIP"
        case .rar: return "RAR"
        case .sevenZip: return "7-Zip (7z)"
        case .tar: return "TAR"
        case .tarGz: return "TAR.GZ"
        case .tarBz2: return "TAR.BZ2"
        case .tarXz: return "TAR.XZ"
        case .gz: return "GZip (GZ)"
        case .bz2: return "BZip2 (BZ2)"
        case .xz: return "XZ"
        case .iso: return "ISO 9660"
        case .cab: return "Microsoft Cabinet (CAB)"
        case .unknown: return "Unknown Archive"
        }
    }

    /// Whether Unpack supports creating archives in this format.
    public var supportsCreation: Bool {
        switch self {
        case .zip, .sevenZip, .tar, .tarGz:
            return true
        default:
            return false // RAR creation is proprietary; others are extract-only
        }
    }

    /// Whether this format supports password encryption.
    public var supportsEncryption: Bool {
        switch self {
        case .zip, .rar, .sevenZip:
            return true
        default:
            return false
        }
    }

    /// Detects format using file extension and inspects the first 16 bytes for magic signatures.
    public static func detect(at url: URL) -> ArchiveFormat {
        // First try magic byte signature detection
        if let fileHandle = try? FileHandle(forReadingFrom: url) {
            defer { try? fileHandle.close() }
            if let headerData = try? fileHandle.read(upToCount: 16), headerData.count >= 4 {
                let bytes = [UInt8](headerData)
                
                // ZIP magic bytes: PK\x03\x04 or PK\x05\x06 (empty) or PK\x07\x08 (spanned)
                if bytes[0] == 0x50 && bytes[1] == 0x4B {
                    return .zip
                }
                
                // RAR magic: Rar!\x1A\x07\x00 (RAR4) or Rar!\x1A\x07\x01\x00 (RAR5)
                if bytes.count >= 7 && bytes[0] == 0x52 && bytes[1] == 0x61 && bytes[2] == 0x72 && bytes[3] == 0x21 && bytes[4] == 0x1A && bytes[5] == 0x07 {
                    return .rar
                }

                // 7z magic: 7z\xBC\xAF\x27\x1C
                if bytes.count >= 6 && bytes[0] == 0x37 && bytes[1] == 0x7A && bytes[2] == 0xBC && bytes[3] == 0xAF && bytes[4] == 0x27 && bytes[5] == 0x1C {
                    return .sevenZip
                }

                // GZ magic: \x1F\x8B
                if bytes[0] == 0x1F && bytes[1] == 0x8B {
                    let ext = url.pathExtension.lowercased()
                    return (ext == "tgz" || url.lastPathComponent.lowercased().hasSuffix(".tar.gz")) ? .tarGz : .gz
                }

                // BZ2 magic: BZh
                if bytes[0] == 0x42 && bytes[1] == 0x5A && bytes[2] == 0x68 {
                    let ext = url.pathExtension.lowercased()
                    return (ext == "tbz2" || url.lastPathComponent.lowercased().hasSuffix(".tar.bz2")) ? .tarBz2 : .bz2
                }

                // XZ magic: \xFD7zXZ\x00
                if bytes.count >= 6 && bytes[0] == 0xFD && bytes[1] == 0x37 && bytes[2] == 0x7A && bytes[3] == 0x58 && bytes[4] == 0x5A && bytes[5] == 0x00 {
                    let ext = url.pathExtension.lowercased()
                    return (ext == "txz" || url.lastPathComponent.lowercased().hasSuffix(".tar.xz")) ? .tarXz : .xz
                }

                // CAB magic: MSCF
                if bytes[0] == 0x4D && bytes[1] == 0x53 && bytes[2] == 0x43 && bytes[3] == 0x46 {
                    return .cab
                }
            }
        }

        // Fallback to filename extension parsing
        let filename = url.lastPathComponent.lowercased()
        if filename.hasSuffix(".tar.gz") || filename.hasSuffix(".tgz") { return .tarGz }
        if filename.hasSuffix(".tar.bz2") || filename.hasSuffix(".tbz2") { return .tarBz2 }
        if filename.hasSuffix(".tar.xz") || filename.hasSuffix(".txz") { return .tarXz }
        
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "zip", "cbz": return .zip
        case "rar", "cbr": return .rar
        case "7z", "cb7": return .sevenZip
        case "tar": return .tar
        case "gz": return .gz
        case "bz2": return .bz2
        case "xz": return .xz
        case "iso": return .iso
        case "cab": return .cab
        default: return .unknown
        }
    }
}
