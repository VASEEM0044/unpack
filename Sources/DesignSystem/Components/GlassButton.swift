import SwiftUI

/// A tactile glassmorphic button with micro-interactions, spring press dynamics, and haptics.
public struct GlassButton: View {
    public enum Style {
        case prominent
        case standard
        case destructive
    }

    private let title: LocalizedStringKey
    private let systemImage: String?
    private let style: Style
    private let action: () -> Void

    public init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        style: Style = .standard,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                }
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .background(backgroundView)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radii.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radii.medium, style: .continuous)
                    .strokeBorder(strokeGradient, lineWidth: DesignTokens.Strokes.hairline)
            )
            .shadow(
                color: style == .prominent ? DesignTokens.Shadows.glowColor : DesignTokens.Shadows.ambientColor,
                radius: style == .prominent ? 12 : 6,
                x: 0,
                y: style == .prominent ? 4 : 2
            )
        }
        .buttonStyle(GlassPressButtonStyle())
        .sensoryFeedback(.impact(weight: .light), trigger: true)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .prominent:
            Color.accentColor
                .opacity(0.88)
        case .standard:
            Rectangle()
                .fill(.ultraThinMaterial)
        case .destructive:
            Color.red
                .opacity(0.82)
        }
    }

    private var strokeGradient: LinearGradient {
        switch style {
        case .prominent:
            return LinearGradient(
                colors: [Color.white.opacity(0.4), Color.white.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .standard:
            return DesignTokens.Strokes.specularBorder
        case .destructive:
            return LinearGradient(
                colors: [Color.white.opacity(0.4), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct GlassPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(DesignTokens.AnimationCurves.smoothSpring, value: configuration.isPressed)
    }
}
