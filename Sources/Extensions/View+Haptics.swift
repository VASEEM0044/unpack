import SwiftUI

public extension View {
    /// Applies conditional haptic feedback triggered by changes to a value.
    @ViewBuilder
    func unpackHapticFeedback<T: Equatable>(trigger: T, feedback: SensoryFeedback = .impact(weight: .light)) -> some View {
        let hapticsEnabled = UserDefaults.standard.object(forKey: "enableHaptics") as? Bool ?? true
        if hapticsEnabled {
            self.sensoryFeedback(feedback, trigger: trigger)
        } else {
            self
        }
    }
}
