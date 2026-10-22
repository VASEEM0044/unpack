import SwiftUI

/// Morphing glass progress indicator supporting both horizontal bar and radial ring layouts.
public struct GlassProgressBar: View {
    public let progress: Double // 0.0 to 1.0
    public let isCompleted: Bool
    public let height: CGFloat

    public init(progress: Double, isCompleted: Bool = false, height: CGFloat = 10) {
        self.progress = max(0.0, min(1.0, progress))
        self.isCompleted = isCompleted || progress >= 1.0
        self.height = height
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background Track
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: height)

                // Fill Bar
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isCompleted
                                ? [Color.green.opacity(0.85), Color.mint.opacity(0.95)]
                                : [Color.accentColor.opacity(0.8), Color.accentColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(height, geometry.size.width * CGFloat(progress)), height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                    )
                    .shadow(
                        color: (isCompleted ? Color.green : Color.accentColor).opacity(0.3),
                        radius: 6,
                        x: 0,
                        y: 2
                    )
                    .animation(DesignTokens.AnimationCurves.smoothSpring, value: progress)
                    .animation(DesignTokens.AnimationCurves.morphSpring, value: isCompleted)
            }
        }
        .frame(height: height)
    }
}

/// Radial circular glass progress ring.
public struct GlassProgressRing: View {
    public let progress: Double
    public let size: CGFloat
    public let lineWidth: CGFloat

    public init(progress: Double, size: CGFloat = 64, lineWidth: CGFloat = 6) {
        self.progress = max(0.0, min(1.0, progress))
        self.size = size
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)

            // Progress
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.7), Color.accentColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(DesignTokens.AnimationCurves.smoothSpring, value: progress)

            // Percentage Text
            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
    }
}
