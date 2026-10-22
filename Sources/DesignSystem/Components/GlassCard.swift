import SwiftUI

/// A reusable glassmorphic container card.
/// Automatically handles blur, specular edge highlight, and responsive shadows.
public struct GlassCard<Content: View>: View {
    private let cornerRadius: CGFloat
    private let padding: CGFloat
    private let material: Material
    private let content: Content

    public init(
        cornerRadius: CGFloat = DesignTokens.Radii.card,
        padding: CGFloat = DesignTokens.Spacing.md,
        material: Material = .ultraThinMaterial,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.material = material
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .glassSurface(cornerRadius: cornerRadius, material: material)
    }
}
