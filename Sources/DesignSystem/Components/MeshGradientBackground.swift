import SwiftUI

/// A subtle, organic ambient mesh background designed to sit beneath frosted glass elements.
/// Features gentle floating gradient orbs that adapt gracefully between Light and Dark mode.
public struct MeshGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @State private var animateOrbs: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // Base layer
            (colorScheme == .dark ? Color(uiColor: .systemBackground) : Color(uiColor: .secondarySystemBackground))
                .ignoresSafeArea()

            if !reduceMotion {
                // Floating subtle ambient light orbs
                GeometryReader { proxy in
                    let width = proxy.size.width
                    let height = proxy.size.height

                    // Orb 1: Accent (Cool Cyan / Indigo)
                    Circle()
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
                        .frame(width: width * 0.85, height: width * 0.85)
                        .blur(radius: 60)
                        .offset(
                            x: animateOrbs ? width * 0.2 : -width * 0.1,
                            y: animateOrbs ? height * 0.1 : -height * 0.1
                        )

                    // Orb 2: Warm Violet / Purple
                    Circle()
                        .fill(Color.purple.opacity(colorScheme == .dark ? 0.18 : 0.10))
                        .frame(width: width * 0.75, height: width * 0.75)
                        .blur(radius: 70)
                        .offset(
                            x: animateOrbs ? -width * 0.15 : width * 0.25,
                            y: animateOrbs ? height * 0.5 : height * 0.3
                        )

                    // Orb 3: Mint / Soft Green
                    Circle()
                        .fill(Color.mint.opacity(colorScheme == .dark ? 0.12 : 0.08))
                        .frame(width: width * 0.6, height: width * 0.6)
                        .blur(radius: 50)
                        .offset(
                            x: animateOrbs ? width * 0.1 : -width * 0.2,
                            y: animateOrbs ? height * 0.75 : height * 0.85
                        )
                }
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                        animateOrbs = true
                    }
                }
            }
        }
    }
}
