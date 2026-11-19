import Foundation
import AVFoundation

/// Plays the app's short synthesized sound effects. Silent when the player turns sounds off.
final class SoundPlayer {
    private var players: [String: AVAudioPlayer] = [:]

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for name in ["card_flip", "card_place", "foundation", "shuffle", "deal", "win"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[name] = player
        }
    }

    func cardFlip() { play("card_flip") }
    func cardPlace() { play("card_place") }
    func foundation() { play("foundation", volume: 0.8) }
    func shuffle() { play("shuffle", volume: 0.7) }
    func deal() { play("deal", volume: 0.7) }
    func win() { play("win") }

    private func play(_ name: String, volume: Float = 1) {
        guard AppPreferences.soundEnabled, let player = players[name] else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
}
