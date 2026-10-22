import XCTest
@testable import Unpack

final class PathSanitizerTests: XCTestCase {

    func testStripsNullBytesAndControlCharacters() {
        let dirty = "photos/\0bad_name\r\n\t.png"
        let clean = PathSanitizer.sanitize(entryPath: dirty)
        XCTAssertEqual(clean, "photos/bad_name.png")
    }

    func testConvertsWindowsBackslashesToUnixSlashes() {
        let windowsPath = "folder\\subfolder\\document.pdf"
        let clean = PathSanitizer.sanitize(entryPath: windowsPath)
        XCTAssertEqual(clean, "folder/subfolder/document.pdf")
    }

    func testPrefixesWindowsReservedNames() {
        let reserved = "CON.txt"
        let clean = PathSanitizer.sanitize(entryPath: reserved)
        XCTAssertEqual(clean, "_CON.txt")

        let reservedDir = "data/NUL/file.dat"
        let cleanDir = PathSanitizer.sanitize(entryPath: reservedDir)
        XCTAssertEqual(cleanDir, "data/_NUL/file.dat")
    }

    func testClampsLongFilenames() {
        let longName = String(repeating: "a", count: 300) + ".txt"
        let clean = PathSanitizer.sanitize(entryPath: longName)
        XCTAssertLessThanOrEqual(clean.utf8.count, 255)
        XCTAssertTrue(clean.hasSuffix(".txt"))
    }

    func testNormalizesUnicodeToNFC() {
        // "e\u{0301}" is decomposed "é" (NFD)
        let nfdString = "cafe\u{0301}.txt"
        let clean = PathSanitizer.sanitize(entryPath: nfdString)
        // Normalized NFC "café.txt"
        XCTAssertEqual(clean, "café.txt")
        XCTAssertEqual(clean.count, 8)
    }
}
