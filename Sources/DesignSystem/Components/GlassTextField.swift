import SwiftUI

/// A frosted glass text field with optional secure masking and clear button.
public struct GlassTextField: View {
    private let placeholder: LocalizedStringKey
    @Binding private var text: String
    private let isSecure: Bool
    private let systemImage: String?
    @State private var isRevealed: Bool = false

    public init(
        _ placeholder: LocalizedStringKey,
        text: Binding<String>,
        isSecure: Bool = false,
        systemImage: String? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.isSecure = isSecure
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundColor(.secondary)
                    .font(.body)
            }

            if isSecure && !isRevealed {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
            }

            if isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            } else if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs + 2)
        .glassSurface(cornerRadius: DesignTokens.Radii.medium, material: .ultraThinMaterial)
    }
}
