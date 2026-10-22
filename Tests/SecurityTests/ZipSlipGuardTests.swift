import XCTest
@testable import Unpack

final class ZipSlipGuardTests: XCTestCase {
    var destinationURL: URL!

    override func setUp() {
        super.setUp()
        destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZipSlipTest_\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: destinationURL)
        super.tearDown()
    }

    func testLegitimatePathIsAccepted() throws {
        let safePath = "documents/photos/vacation.jpg"
        let resolvedURL = try ZipSlipGuard.validateAndResolve(
            entryPath: safePath,
            destinationDirectory: destinationURL
        )
        XCTAssertTrue(resolvedURL.path.hasPrefix(destinationURL.resolvingSymlinksInPath().path))
        XCTAssertTrue(resolvedURL.path.hasSuffix("documents/photos/vacation.jpg"))
    }

    func testParentDirectoryTraversalThrowsZipSlip() {
        let maliciousPath = "../../etc/passwd"
        XCTAssertThrowsError(
            try ZipSlipGuard.validateAndResolve(entryPath: maliciousPath, destinationDirectory: destinationURL)
        ) { error in
            guard case ArchiveSecurityError.zipSlipDetected = error else {
                XCTFail("Expected zipSlipDetected error but got \(error)")
                return
            }
        }
    }

    func testHiddenParentTraversalThrowsZipSlip() {
        let maliciousPath = "safe_dir/../../../var/mobile/Library"
        XCTAssertThrowsError(
            try ZipSlipGuard.validateAndResolve(entryPath: maliciousPath, destinationDirectory: destinationURL)
        ) { error in
            guard case ArchiveSecurityError.zipSlipDetected = error else {
                XCTFail("Expected zipSlipDetected error but got \(error)")
                return
            }
        }
    }

    func testAbsoluteRootPathIsContainedOrStripped() throws {
        let absolutePath = "/var/root/secret.txt"
        let resolved = try ZipSlipGuard.validateAndResolve(entryPath: absolutePath, destinationDirectory: destinationURL)
        XCTAssertTrue(resolved.path.hasPrefix(destinationURL.resolvingSymlinksInPath().path))
    }

    func testSymlinkOutsideDestinationThrowsForbidden() {
        let linkLocation = destinationURL.appendingPathComponent("sub/symlink")
        let outsideTarget = "../../../../private/var"

        XCTAssertThrowsError(
            try ZipSlipGuard.validateSymlinkTarget(
                linkTarget: outsideTarget,
                linkLocation: linkLocation,
                destinationDirectory: destinationURL
            )
        ) { error in
            guard case ArchiveSecurityError.forbiddenSymlinkTarget = error else {
                XCTFail("Expected forbiddenSymlinkTarget error but got \(error)")
                return
            }
        }
    }
}
