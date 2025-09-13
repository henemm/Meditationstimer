//
//  BackgroundAudioKeeper.swift
//  Meditationstimer
//
//  Created by Henning Emmrich on 03.09.25.
//

import Foundation
import AVFoundation

final class BackgroundAudioKeeper {
    private var player: AVAudioPlayer?

    // Public API
    func start() {
        guard player == nil else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)

            // Bevorzugt: silence.caf aus dem Bundle
            let url: URL
            if let bundled = Bundle.main.url(forResource: "silence", withExtension: "caf") {
                url = bundled
            } else {
                url = try ensureGeneratedSilenceWAV()
            }

            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0.0
            p.prepareToPlay()
            p.play()
            self.player = p
        } catch {
            print("BackgroundAudioKeeper start failed: \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [])
    }

    // MARK: - Silent file generation

    /// Legt eine 1‑Sekunden‑WAV (16‑bit PCM, 44.1 kHz, mono) im Application Support an,
    /// falls noch nicht vorhanden, und gibt deren URL zurück.
    private func ensureGeneratedSilenceWAV() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true)
        let dir = appSupport.appendingPathComponent("BackgroundAudio", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let fileURL = dir.appendingPathComponent("silence.wav")

        if fm.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        // WAV Header für 1 Sekunde Stille
        let sampleRate: UInt32 = 44_100
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let durationSeconds: Double = 1.0
        let bytesPerSample = UInt32(channels) * UInt32(bitsPerSample / 8)
        let numSamples = UInt32(Double(sampleRate) * durationSeconds)
        let dataSize = numSamples * bytesPerSample
        let byteRate = sampleRate * bytesPerSample
        let blockAlign = UInt16(bytesPerSample)

        // Helper zum Schreiben kleiner Endian-Integer
        func le32(_ v: UInt32) -> [UInt8] {
            [UInt8(v & 0xff),
             UInt8((v >> 8) & 0xff),
             UInt8((v >> 16) & 0xff),
             UInt8((v >> 24) & 0xff)]
        }
        func le16(_ v: UInt16) -> [UInt8] {
            [UInt8(v & 0xff), UInt8((v >> 8) & 0xff)]
        }

        var bytes: [UInt8] = []
        // RIFF Header
        bytes += Array("RIFF".utf8)
        bytes += le32(36 + dataSize)                 // ChunkSize
        bytes += Array("WAVE".utf8)

        // fmt subchunk
        bytes += Array("fmt ".utf8)
        bytes += le32(16)                             // Subchunk1Size for PCM
        bytes += le16(1)                              // AudioFormat = PCM
        bytes += le16(channels)                       // NumChannels
        bytes += le32(sampleRate)                     // SampleRate
        bytes += le32(byteRate)                       // ByteRate
        bytes += le16(blockAlign)                     // BlockAlign
        bytes += le16(bitsPerSample)                  // BitsPerSample

        // data subchunk
        bytes += Array("data".utf8)
        bytes += le32(dataSize)                       // Subchunk2Size

        // Stille (alle Nullen)
        bytes += Array(repeating: 0, count: Int(dataSize))

        let data = Data(bytes)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
