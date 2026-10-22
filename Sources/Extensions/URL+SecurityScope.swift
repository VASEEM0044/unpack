import Foundation

public extension URL {
    /// Safely executes a block while holding security-scoped access to this URL,
    /// ensuring `stopAccessingSecurityScopedResource()` is always called on exit.
    func withSecurityScope<R>(_ block: (URL) throws -> R) rethrows -> R {
        let isScoped = self.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                self.stopAccessingSecurityScopedResource()
            }
        }
        return try block(self)
    }

    /// Asynchronous security scope wrapper.
    func withSecurityScopeAsync<R>(_ block: (URL) async throws -> R) async rethrows -> R {
        let isScoped = self.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                self.stopAccessingSecurityScopedResource()
            }
        }
        return try await block(self)
    }
}
