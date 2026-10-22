import Foundation

/// Protects against Zip-Slip path traversal vulnerabilities (`../`, absolute paths, and escaping symlinks).
public enum ZipSlipGuard {
    
    /// Validates an entry's relative path against the designated extraction root.
    /// Returns the safe, fully qualified destination URL if legitimate.
    /// Throws `ArchiveSecurityError.zipSlipDetected` or `ArchiveSecurityError.forbiddenSymlinkTarget` if unsafe.
    public static func validateAndResolve(
        entryPath: String,
        destinationDirectory: URL
    ) throws -> URL {
        // 1. Basic sanitization: reject empty paths
        let trimmed = entryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ArchiveSecurityError.sanitizedPathEmpty(original: entryPath)
        }

        // 2. Reject explicit parent directory traversal tokens before resolution
        let components = trimmed.components(separatedBy: "/")
        for component in components {
            if component == ".." {
                throw ArchiveSecurityError.zipSlipDetected(entryPath: entryPath)
            }
        }

        // 3. Normalize destination directory
        let canonicalDestination = destinationDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let destinationPath = canonicalDestination.path(percentEncoded: false)

        // 4. Clean entry path: strip leading slashes or volume specifiers
        var cleanPath = trimmed
        while cleanPath.hasPrefix("/") || cleanPath.hasPrefix("\\") {
            cleanPath.removeFirst()
        }

        let targetURL = canonicalDestination
            .appending(path: cleanPath, directoryHint: trimmed.hasSuffix("/") ? .isDirectory : .notDirectory)
            .standardizedFileURL

        let targetPath = targetURL.path(percentEncoded: false)

        // 5. Prefix check on standardized path
        let safePrefix = destinationPath.hasSuffix("/") ? destinationPath : destinationPath + "/"
        guard targetPath == destinationPath || targetPath.hasPrefix(safePrefix) else {
            throw ArchiveSecurityError.zipSlipDetected(entryPath: entryPath)
        }

        // 6. Check existing filesystem items along target path to ensure no existing parent symlink escapes
        if targetURL.hasDirectoryPath == false {
            let parent = targetURL.deletingLastPathComponent().resolvingSymlinksInPath()
            let parentPath = parent.path(percentEncoded: false)
            guard parentPath == destinationPath || parentPath.hasPrefix(safePrefix) else {
                throw ArchiveSecurityError.zipSlipDetected(entryPath: entryPath)
            }
        }

        return targetURL
    }

    /// Validates that a symbolic link target will not resolve outside of the sandbox destination directory.
    public static func validateSymlinkTarget(
        linkTarget: String,
        linkLocation: URL,
        destinationDirectory: URL
    ) throws {
        let canonicalDestination = destinationDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let destinationPath = canonicalDestination.path(percentEncoded: false)
        let safePrefix = destinationPath.hasSuffix("/") ? destinationPath : destinationPath + "/"

        let resolvedURL: URL
        if linkTarget.hasPrefix("/") {
            // Absolute symlink target: treat relative to destination root or reject
            resolvedURL = canonicalDestination.appending(path: String(linkTarget.dropFirst())).standardizedFileURL
        } else {
            // Relative symlink target: evaluate from parent directory of the symlink
            let parentDir = linkLocation.deletingLastPathComponent()
            resolvedURL = parentDir.appending(path: linkTarget).standardizedFileURL
        }

        let resolvedPath = resolvedURL.path(percentEncoded: false)
        guard resolvedPath == destinationPath || resolvedPath.hasPrefix(safePrefix) else {
            throw ArchiveSecurityError.forbiddenSymlinkTarget(target: linkTarget)
        }
    }
}
