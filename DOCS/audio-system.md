# Audio System Documentation

Complete reference for audio playback in Meditationstimer.

---

## Overview

Meditationstimer uses different audio strategies across platforms:

- **iOS (OffenView, AtemView):** GongPlayer + BackgroundAudioKeeper
- **iOS (WorkoutsView):** SoundPlayer (local) with speech synthesis
- **watchOS:** No audio (haptic feedback only)

---

## iOS Audio System (Offen & Atem Tabs)

### Components

**GongPlayer (Services/GongPlayer.swift)**
- Audio playback service for meditation cues
- Searches files: .caf → .wav → .mp3 (priority order)
- Maintains array of active players (prevent GC)
- Completion handlers for sequenced playback

**BackgroundAudioKeeper (Meditationstimer iOS/BackgroundAudioKeeper.swift)**
- Keeps audio session alive during meditation
- Plays silent audio loop (volume 0.0)
- Prevents iOS from suspending audio session

**AVAudioSession Configuration**
- Category: `.playback`
- Options: `.mixWithOthers`
- Mode: `.default`

### Audio Flow (OffenView)

```
User taps Start
  → bgAudio.start()              // silent audio keeps session alive
  → gong.play("gong")             // start sound
  → ... meditation runs ...
  → On phase transition:
    gong.play("gong-dreimal", completion: { /* update UI */ })
  → On end:
    gong.play("gong-ende")
    bgAudio.stop()                // release audio session
```

### Expected Audio Files (Offen Tab)

- `gong.caf` – Default gong (session start)
- `gong-dreimal.caf` – Triple gong (phase transition)
- `gong-Ende.caf` – End gong (session complete)

### Expected Audio Files (Atem Tab)

- `einatmen.caf` – Inhale cue
- `ausatmen.caf` – Exhale cue
- `halten-ein.caf` – Hold after inhale
- `halten-aus.caf` – Hold after exhale

**Note:** AtemView uses a **local GongPlayer instance** to avoid conflicts with OffenView's GongPlayer.

---

## iOS Audio System (Workouts Tab)

### Components

**SoundPlayer (local class in WorkoutsView)**
- Distinct from GongPlayer
- Supports round-specific audio
- Integrates AVSpeechSynthesizer for German announcements

**AVSpeechSynthesizer**
- German voice (`de-DE`)
- Used for round announcements: "Runde 5 von 10"
- Countdown: "30 Sekunden verbleiben"

### Expected Audio Files

**Workout Cues:**
- `auftakt.caf` – Pre-workout warm-up cue
- `kurz.caf` – 3, 2, 1 second countdown
- `lang.caf` – Work/rest phase transition
- `ausklang.caf` – Final completion tone
- `last-round.caf` – Penultimate round announcement

**Round-Specific (Optional):**
- `round-1.caf` through `round-20.caf` – Round start cues

### Audio Flow (WorkoutsView)

```
User starts workout
  → soundPlayer.play("auftakt")        // warm-up
  → ... workout runs ...
  → On round start:
    soundPlayer.playRoundSound(round: 5)  // "round-5.caf"
    OR speak("Runde 5 von 10")            // German voice
  → On work/rest transition:
    soundPlayer.play("lang")
  → Before final round:
    soundPlayer.play("last-round")
  → On completion:
    soundPlayer.play("ausklang")
```

---

## watchOS Audio System

### Strategy

**No Audio Playback**
- Watch speaker too quiet for meditation use
- Uses **haptic feedback** instead (WKInterfaceDevice)
- Notifications deliver critical alerts

### Haptic Patterns

```swift
WKInterfaceDevice.current().play(.notification)  // Phase transition
WKInterfaceDevice.current().play(.success)       // Session complete
WKInterfaceDevice.current().play(.start)         // Session start
```

---

## GongPlayer API Reference

### Basic Usage

```swift
let gong = GongPlayer()
gong.play(named: "gong")  // Plays gong.caf/.wav/.mp3
```

### Default Sound

```swift
gong.play()  // Defaults to "gong"
```

### With Completion Handler

```swift
gong.play(named: "gong-dreimal") {
    print("Triple gong finished")
    // Continue with next action
}
```

### File Search Priority

1. `{name}.caf`
2. `{name}.wav`
3. `{name}.mp3`

If none found → silent skip (no crash)

---

## BackgroundAudioKeeper API Reference

### Start Silent Audio

```swift
let bgAudio = BackgroundAudioKeeper()
bgAudio.start()  // Starts silent loop
```

### Stop Silent Audio

```swift
bgAudio.stop()  // Releases audio session
```

### How It Works

- Searches for `silence.caf` in bundle
- Falls back to generating 1-second WAV if not found
- Plays in loop with `numberOfLoops = -1`
- Volume set to `0.0` (inaudible)

---

## Audio File Guidelines

### Format Recommendations

**Preferred:** `.caf` (Core Audio Format)
- Optimized for iOS/macOS
- Best compression/quality trade-off
- Native support

**Alternative:** `.wav` (Uncompressed)
- Larger file size
- No compression artifacts
- Good for short cues

**Fallback:** `.mp3` (Compressed)
- Smaller file size
- Potential quality loss
- Wider compatibility

### Creating Audio Files

**Convert to .caf using afconvert:**
```bash
afconvert -f caff -d LEI16@44100 input.wav output.caf
```

**Optimize for size:**
```bash
afconvert -f caff -d aac -b 64000 input.wav output.caf
```

### File Naming Conventions

- Lowercase preferred: `gong.caf` (not `Gong.caf`)
- Hyphens for multi-word: `gong-dreimal.caf`
- No spaces: `last-round.caf` (not `last round.caf`)

---

## Troubleshooting

### Audio Not Playing

**Check:**
1. File is in app bundle (Xcode project navigator)
2. File extension correct (.caf, .wav, .mp3)
3. File name matches exactly (case-sensitive)
4. Audio session configured correctly

**Enable debug logging:**
```swift
print("Playing: \(name)")
if let path = Bundle.main.path(forResource: name, ofType: "caf") {
    print("Found at: \(path)")
} else {
    print("File not found!")
}
```

### Audio Cuts Off Early

**Cause:** AVAudioPlayer released before playback completes

**Fix:** GongPlayer maintains `activePlayers` array to prevent early deallocation

### Silent Audio Not Working

**Check:**
1. `BackgroundAudioKeeper.start()` called before session
2. Audio session category set to `.playback`
3. `silence.caf` exists or fallback WAV generated

### Speech Synthesis Issues

**Check:**
1. Language code correct: `de-DE` for German
2. AVSpeechSynthesizer initialized
3. Speech not interrupted by audio playback

**Fix:** Pause speech before playing audio, resume after

---

## Advanced Patterns

### Sequenced Audio Playback

```swift
gong.play(named: "gong") {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        gong.play(named: "gong-dreimal") {
            print("Sequence complete")
        }
    }
}
```

### Conditional Audio

```swift
if UserDefaults.standard.bool(forKey: "soundEnabled") {
    gong.play(named: "gong")
}
```

### Volume Control (Not Recommended)

```swift
// GongPlayer uses system volume
// To adjust: change device volume
// DO NOT set player.volume (overrides user preference)
```

---

## Future Considerations

1. **Customizable Sounds:** Allow users to upload custom audio files
2. **Volume Presets:** Per-session volume settings
3. **Audio Themes:** Different gong sets (Tibetan, Japanese, bell, etc.)
4. **Haptic+Audio Sync:** Coordinate haptics with audio on iOS
5. **watchOS Audio:** Explore playing audio through iPhone via WatchConnectivity
