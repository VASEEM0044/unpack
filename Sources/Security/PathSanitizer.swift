import Foundation

/// Sanitizes relative archive entry paths, preventing character injection,
/// reserved system filenames, overly long components, and Unicode encoding anomalies.
public enum PathSanitizer {
    
    private static let forbiddenCharacters = CharacterSet(charactersIn: "\0\r\n\t:*?\"<>|")
        .union(.controlCharacters)
        .union(.illegalCharacters)

    private static let reservedWindowsNames: Set<String> = [
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
    ]

    private static let maxComponentLength = 255

    /// Sanitizes an entry path extracted from archive headers.
    public static func sanitize(entryPath: String) -> String {
        // 1. Normalize Windows backslashes to standard Unix separators
        var normalized = entryPath.replacingOccurrences(of: "\\", with: "/")

        // 2. Normalize to Unicode Canonical Composition (NFC)
        normalized = normalized.precomposedStringWithCanonicalMapping

        // 3. Split components and sanitize each piece individually
        let isDir = normalized.hasSuffix("/")
        let components = normalized.components(separatedBy: "/")
        
        var safeComponents: [String] = []

        for component in components {
            // Trim leading/trailing whitespace
            var cleanComponent = component.trimmingCharacters(in: .whitespaces)

            // Remove null bytes and control/forbidden characters
            cleanComponent = cleanComponent.unicodeScalars
                .filter { !forbiddenCharacters.contains($0) }
                .map { String($0) }
                .joined()

            // Skip empty or relative tokens
            if cleanComponent.isEmpty || cleanComponent == "." || cleanComponent == ".." {
                continue
            }

            // Check for reserved filenames (case-insensitive)
            let upper = cleanComponent.uppercased()
            let baseName = (upper as NSString).deletingPathExtension
            if reservedWindowsNames.contains(baseName) {
                cleanComponent = "_" + cleanComponent
            }

            // Clamp length to 255 characters to avoid filesystem errors
            if cleanComponent.utf8.count > maxComponentLength {
                let ext = (cleanComponent as NSString).pathExtension
                if !ext.isEmpty {
                    let maxBase = maxComponentLength - (ext.utf8.count + 1)
                    let base = String(cleanComponent.prefix(maxBase))
                    cleanComponent = "\(base).\(ext)"
                } else {
                    cleanComponent = String(cleanComponent.prefix(maxComponentLength))
                }
            }

            safeComponents.append(cleanComponent)
        }

        var result = safeComponents.joined(separator: "/")
        if isDir && !result.isEmpty && !result.hasSuffix("/") {
            result += "/"
        }

        return result
    }
}
