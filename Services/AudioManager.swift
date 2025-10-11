import Foundation
import AVFoundation

final class AudioManager {
    static let shared = AudioManager()
    private init() {}

    func activateAudioSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, options: [.mixWithOthers])
        try? s.setActive(true)
    }

    func playNamed(_ name: String) {
        activateAudioSession()
        // actual gong playback is still in AtemView's GongPlayer for now
    }
}
