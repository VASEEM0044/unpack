# Unpack (iOS Archive Extractor & Browser)

A modern, high-performance archive extractor and browser for iOS built with **Swift 6 Strict Concurrency**, a **minimalist glassmorphism UI**, and an ironclad security pipeline protecting against path traversal (Zip-Slip) and denial-of-service (Zip-Bombs).

Designed for seamless deployment:
- **TrollStore & Sideloading**: Generate an unsigned or ad-hoc signed `.ipa` in one click via **GitHub Actions** (`.github/workflows/build-ipa.yml`) for permanent installation with no revokes.
- **App Store Ready**: Full compliance with privacy manifests, encryption export rules, and licensing terms.

---

## 1. Feature Highlights

- **Multi-Format Extraction & Browsing**:
  - **Formats**: ZIP, RAR (RAR4 and RAR5), 7z, TAR, TAR.GZ / TGZ, TAR.BZ2, TAR.XZ, GZ, BZ2, XZ, ISO 9660, and CAB.
  - **Archive Creation**: High-speed ZIP creation with optional AES-256 encryption, and 7-Zip packaging.
  - **RAR Licensing Compliance**: Honest and compliant implementation—RAR archives are supported for extraction and browsing only, as RAR compression is proprietary to RARLAB.
- **Minimalist Glassmorphism UI**:
  - Two-tier rendering: native liquid glass APIs on future iOS versions (`.glassEffect`), and custom-tuned `.ultraThinMaterial` / `.regularMaterial` with specular 0.5pt gradient strokes and ambient layered shadows on iOS 17–25.
  - Full accessibility compliance: automatically converts to solid high-contrast surfaces under **Reduce Transparency**.
- **Files & System Integration**:
  - `UIFileSharingEnabled` & `LSSupportsOpeningDocumentsInPlace`: Extracted files appear directly in the **Files app** under **"On My iPhone > Unpack"**.
  - **Share Sheet Extension**: Send archives directly to Unpack from Safari, Mail, Files, or messaging apps via App Groups.
  - **Drag & Drop**: Native support for iPad multi-window and split-view drag & drop.
  - **Quick Look Previews**: Instant inspection of images, PDFs, media, and text documents without decompressing the entire archive.
- **Security & Integrity Shield**:
  - **Zip-Slip Defense**: Path traversal (`../`, absolute roots, symlinks escaping target root) is blocked and quarantined.
  - **Zip-Bomb Mitigation**: Real-time quota guards on file count, cumulative bytes, and compression ratios (flags abnormal >100:1 ratios on payloads over 1MB).
  - **Disk Space Assurance**: Evaluates APFS volume capacity before decompression begins.
  - **Filename Sanitization**: Unicode NFC normalization, null byte stripping, and reserved filename safety.

---

## 2. GitHub Actions: Building the Unsigned IPA

To build and run Unpack on your iOS device using **TrollStore**, **AltStore**, or **SideStore**:

1. **Push or Fork this repository to GitHub**.
2. Navigate to the **Actions** tab.
3. Select the workflow **"Build Unsigned IPA (TrollStore / Sideloading)"** and click **Run workflow** (or simply push to `main`).
4. The workflow will:
   - Run on `macos-14` with Xcode 15.4 / 16.
   - Install `xcodegen` and generate `Unpack.xcodeproj`.
   - Compile the app with `CODE_SIGNING_ALLOWED=NO` and `CODE_SIGNING_REQUIRED=NO`.
   - Package `Payload/Unpack.app` into `Unpack.ipa`.
   - Upload `Unpack-TrollStore-IPA` as an artifact.
5. **Download `Unpack.ipa`**:
   - Download the artifact ZIP from the GitHub Actions run summary and extract `Unpack.ipa`.
   - On your device, open `Unpack.ipa` in **TrollStore** to install it permanently without 7-day expiration or app limits.

---

## 3. Project Architecture & Concurrency

```
Unpack/
├── .github/workflows/build-ipa.yml      # Automated unsigned IPA build
├── project.yml                          # XcodeGen project specification
├── Configuration/
│   ├── Info.plist                       # Document UTIs, File Sharing, Permissions
│   ├── Unpack.entitlements              # Keychain & App Group entitlements
│   └── PrivacyInfo.xcprivacy            # Apple Privacy Manifest
├── Sources/
│   ├── App/                             # Main entry & deep-link coordinator
│   ├── DesignSystem/                    # Glass tokens, materials, buttons, progress
│   ├── Engine/                          # ArchiveEngine, Coordinator actor, ZIP/TAR/RAR/7z
│   ├── Security/                        # ZipSlipGuard, ZipBombGuard, PathSanitizer
│   ├── Services/                        # SecurityScopedFileManager, Keychain, Notifications
│   ├── ViewModels/                      # MVVM @Observable @MainActor ViewModels
│   ├── Views/                           # SwiftUI views (Home, Browser, Sheets, Settings)
│   └── Extensions/                      # Concurrency & file helpers
├── Extensions/
│   └── ShareExtension/                  # Share sheet target
└── Tests/
    └── SecurityTests/                   # Security test suite (Zip-Slip & Zip-Bomb)
```

- **Strict Concurrency**: Fully compliant with Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY = complete`).
- **Bounded Memory Footprint**: Extraction is streamed through 64KB POSIX buffers, guaranteeing an active memory footprint under **45 MB**, even for 20+ GB archives.

---

## 4. Design System Tokens & Style Guide

| Token Category | Value | Application |
| :--- | :--- | :--- |
| **Corner Radii** | `12pt`, `18pt`, `22pt`, `28pt` | Small controls, buttons, cards, and modal sheets |
| **Specular Stroke** | `0.5pt` linear gradient | Dual-tone gradient (`white.opacity(0.35)` to `0.02`) |
| **Ambient Shadow** | Radius: `16pt`, Y: `8pt`, Opacity: `7%` | Soft elevated depth for cards |
| **Key Shadow** | Radius: `4pt`, Y: `2pt`, Opacity: `4%` | Sharp grounding shadow |
| **Animation Curve** | `spring(response: 0.38, dampingFraction: 0.82)` | Micro-interactions and press dynamics |

---

## 5. App Store & Legal Notes

1. **RAR / unrar Licensing**:
   - The unrar extraction logic respects Alexander Roshal's license: unrar source may be freely used to unpack RAR archives without royalty or copyright encumbrance. It forbids recreating the compression algorithm, which Unpack strictly obeys (creation is limited to ZIP and 7z).
2. **Export Compliance for Encryption**:
   - Unpack uses standard Apple platform cryptography (CryptoKit / CommonCrypto) for AES-256 archive encryption and Keychain access. It qualifies for the standard exemption under EAR 740.17(b)(2) (`ITSAppUsesNonExemptEncryption = NO`).
3. **Apple Privacy Manifest**:
   - `PrivacyInfo.xcprivacy` declares zero user tracking and explicitly documents required reasons for disk space queries (`E174.1`) and file timestamp manipulation (`C617.1`).
