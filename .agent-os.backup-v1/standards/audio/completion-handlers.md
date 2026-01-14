# Audio Completion Handler Pattern

## Problem

End-gong sound cut off because dependent resources stopped before audio finished.

**Wrong Approach:**
```swift
gong.play(named: "gong-ende")
try? await Task.sleep(nanoseconds: 2_000_000_000)  // Guess timing!
ambientPlayer.stop()  // May stop too early
```

## Solution: AVAudioPlayerDelegate + Completion Callback

**1. Add completion tracking to GongPlayer:**
```swift
class GongPlayer: NSObject, AVAudioPlayerDelegate {
    private var completions: [AVAudioPlayer: () -> Void] = [:]

    func play(named name: String, completion: (() -> Void)? = nil) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }

        player.delegate = self

        if let completion = completion {
            completions[player] = completion
        }

        player.play()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if let completion = completions[player] {
            completions.removeValue(forKey: player)
            completion()  // Called when audio ACTUALLY finishes
        }
    }
}
```

**2. Use completion in caller:**
```swift
@State private var pendingEndStop: DispatchWorkItem?

func endSession() {
    gong.play(named: "gong-ende") {
        // This runs AFTER gong finishes
        self.pendingEndStop?.cancel()

        let work = DispatchWorkItem { [ambientPlayer = self.ambientPlayer] in
            ambientPlayer.stop()
        }
        self.pendingEndStop = work

        // Extra 0.5s safety buffer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
}
```

## Why DispatchWorkItem?

- Allows cancellation if user interrupts
- Can be stored and cancelled later
- Clean pattern for delayed async work

## The Rules

- DON'T use Task.sleep() or arbitrary delays
- DON'T guess audio duration
- DO use AVAudioPlayerDelegate
- DO use completion callback pattern
- DO stop dependent resources AFTER audio finishes
- DO allow extra safety buffer (0.5s)

## Why This Matters

- Race conditions between playback and cleanup
- Audio files have variable length
- Hardcoded delays break when audio changes
- Completion handlers guarantee correct sequencing
- DispatchWorkItem allows user interruption
