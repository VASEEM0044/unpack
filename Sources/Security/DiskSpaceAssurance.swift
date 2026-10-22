import Foundation

/// Verifies that the host device possesses adequate storage headroom before initiating decompression.
public enum DiskSpaceAssurance {
    
    private static let safetyBufferBytes: Int64 = 50 * 1024 * 1024 // 50 MB safety margin

    /// Evaluates volume capacity for the given target destination.
    /// Throws `ArchiveSecurityError.insufficientDiskSpace` if capacity is below `requiredBytes + safetyBufferBytes`.
    public static func verifyAvailableSpace(
        requiredBytes: Int64,
        at destinationURL: URL
    ) throws {
        guard requiredBytes > 0 else { return }

        let directory = destinationURL.hasDirectoryPath ? destinationURL : destinationURL.deletingLastPathComponent()
        let totalNeeded = requiredBytes + safetyBufferBytes

        do {
            let values = try directory.resourceValues(forKeys: [
                .volumeAvailableCapacityForImportantUsageKey,
                .volumeAvailableCapacityKey
            ])

            let available = values.volumeAvailableCapacityForImportantUsage
                ?? values.volumeAvailableCapacity
                ?? Int64.max

            if available < totalNeeded {
                throw ArchiveSecurityError.insufficientDiskSpace(
                    requiredBytes: totalNeeded,
                    availableBytes: available
                )
            }
        } catch let error as ArchiveSecurityError {
            throw error
        } catch {
            // If storage query fails due to sandbox virtualization, proceed with caution
        }
    }
}
