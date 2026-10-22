import SwiftUI

/// Design tokens defining the visual identity of Unpack.
/// Built around a calm, minimalist aesthetic: soft frosted surfaces,
/// subtle ambient glow, specular 0.5pt strokes, and generous corner radii.
public enum DesignTokens {
    // MARK: - Radii
    public enum Radii {
        public static let small: CGFloat = 12
        public static let medium: CGFloat = 18
        public static let card: CGFloat = 22
        public static let large: CGFloat = 28
        public static let pill: CGFloat = 999
    }

    // MARK: - Strokes
    public enum Strokes {
        public static let hairline: CGFloat = 0.5
        public static let thin: CGFloat = 1.0
        public static let focus: CGFloat = 2.0
        
        public static var specularBorder: LinearGradient {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.35),
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.02)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        public static var darkSpecularBorder: LinearGradient {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.18),
                    Color.white.opacity(0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Shadows
    public enum Shadows {
        public static let ambientRadius: CGFloat = 16
        public static let ambientY: CGFloat = 8
        public static let ambientColor: Color = Color.black.opacity(0.07)
        
        public static let keyRadius: CGFloat = 4
        public static let keyY: CGFloat = 2
        public static let keyColor: Color = Color.black.opacity(0.04)
        
        public static let glowRadius: CGFloat = 20
        public static let glowColor: Color = Color.accentColor.opacity(0.25)
    }

    // MARK: - Spacing
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    // MARK: - Animation
    public enum AnimationCurves {
        public static let smoothSpring = Animation.spring(response: 0.38, dampingFraction: 0.82, blendDuration: 0)
        public static let bouncySpring = Animation.spring(response: 0.42, dampingFraction: 0.68, blendDuration: 0)
        public static let morphSpring = Animation.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)
    }
}
