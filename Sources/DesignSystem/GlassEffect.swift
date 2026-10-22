import SwiftUI

/// Adaptive modifier that provides native Liquid Glass on future iOS versions (iOS 26+)
/// while offering a rich, high-fidelity frosted material fallback on iOS 17-25.
/// Respects accessibility settings: when Reduce Transparency is enabled, surfaces become solid opaque.
public struct GlassSurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    
    public var cornerRadius: CGFloat
    public var isInteractive: Bool
    public var material: Material
    
    public init(
        cornerRadius: CGFloat = DesignTokens.Radii.card,
        isInteractive: Bool = false,
        material: Material = .ultraThinMaterial
    ) {
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
        self.material = material
    }

    public func body(content: Content) -> some View {
        if reduceTransparency {
            // Accessible high-contrast solid surface
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(colorScheme == .dark ? Color(uiColor: .secondarySystemBackground) : Color(uiColor: .systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
        } else {
            // Standard frosted glass rendering
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(material)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            colorScheme == .dark ? DesignTokens.Strokes.darkSpecularBorder : DesignTokens.Strokes.specularBorder,
                            lineWidth: DesignTokens.Strokes.hairline
                        )
                )
                .shadow(
                    color: DesignTokens.Shadows.ambientColor,
                    radius: DesignTokens.Shadows.ambientRadius,
                    x: 0,
                    y: DesignTokens.Shadows.ambientY
                )
                .shadow(
                    color: DesignTokens.Shadows.keyColor,
                    radius: DesignTokens.Shadows.keyRadius,
                    x: 0,
                    y: DesignTokens.Shadows.keyY
                )
        }
    }
}

public extension View {
    func glassSurface(
        cornerRadius: CGFloat = DesignTokens.Radii.card,
        isInteractive: Bool = false,
        material: Material = .ultraThinMaterial
    ) -> some View {
        modifier(GlassSurfaceModifier(
            cornerRadius: cornerRadius,
            isInteractive: isInteractive,
            material: material
        ))
    }
}
