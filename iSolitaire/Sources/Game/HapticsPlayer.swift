import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Haptic feedback for game actions. A no-op on devices without a Taptic Engine,
/// and when the player turns haptics off.
final class HapticsPlayer {
    #if canImport(UIKit)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let notification = UINotificationFeedbackGenerator()
    #endif

    func light() {
        #if canImport(UIKit)
        guard AppPreferences.hapticsEnabled else { return }
        lightImpact.impactOccurred(intensity: 0.6)
        #endif
    }

    func medium() {
        #if canImport(UIKit)
        guard AppPreferences.hapticsEnabled else { return }
        mediumImpact.impactOccurred(intensity: 0.8)
        #endif
    }

    func invalid() {
        #if canImport(UIKit)
        guard AppPreferences.hapticsEnabled else { return }
        rigidImpact.impactOccurred(intensity: 0.5)
        #endif
    }

    func won() {
        #if canImport(UIKit)
        guard AppPreferences.hapticsEnabled else { return }
        notification.notificationOccurred(.success)
        #endif
    }
}
