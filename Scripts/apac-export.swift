#!/usr/bin/env swift
//
// apac-export.swift — dekodiert die APAC-Raumspur (First Order Ambisonics, ACN/SN3D)
// einer iPhone-Aufnahme (.qta/.mov) zu rohem Float32-PCM, interleaved, Quell-Abtastrate.
// Spezifikation: docs/specs/features/FEAT-apac-export.md
//
// Aufruf:
//   Scripts/apac-export.swift --probe <input>            Tonspuren auflisten, nichts dekodieren
//   Scripts/apac-export.swift <input> <output.pcm>       Raumspur in Datei dekodieren
//   Scripts/apac-export.swift <input>                    Raumspur nach stdout dekodieren
//
// Test-Hook (kein Nutzerfeature): APAC_EXPORT_EXPECT_LAYOUT_TAG ueberschreibt den erwarteten
// Kanallayout-Tag; ohne die Variable gilt kAudioChannelLayoutTag_HOA_ACN_SN3D | 4.

import AVFoundation
import CoreMedia
import Foundation

struct AudioTrackInfo {
    let number: Int
    let asset: AVAsset   // starke Referenz: AVAssetTrack.asset ist nur weak
    let track: AVAssetTrack
    let format: FourCharCode
    let channels: UInt32
    let sampleRate: Double
    let layoutTag: AudioChannelLayoutTag?
}

struct ExportError: Error, CustomStringConvertible {
    let description: String
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("apac-export: \(message)\n".utf8))
    exit(1)
}

/// OSType ('apac', 'aac ') in ASCII-Text wandeln; Auffuell-Leerzeichen entfallen.
func fourCCString(_ code: FourCharCode) -> String {
    let bytes = [UInt8((code >> 24) & 0xFF), UInt8((code >> 16) & 0xFF),
                 UInt8((code >> 8) & 0xFF), UInt8(code & 0xFF)]
    let text = String(bytes: bytes, encoding: .ascii) ?? "????"
    return text.trimmingCharacters(in: .whitespaces)
}

/// Layout-Tag als "<hi>_<lo>" (190_4 = HOA_ACN_SN3D | 4 Kanaele), "none" ohne Layout.
func layoutText(_ tag: AudioChannelLayoutTag?) -> String {
    guard let tag else { return "none" }
    return "\(tag >> 16)_\(tag & 0xFFFF)"
}

/// Liest nur den Tag aus dem AudioChannelLayout; die Struktur kann kuerzer sein als
/// MemoryLayout<AudioChannelLayout>.size (Tag-basierte Layouts liefern 12 Byte).
func channelLayoutTag(of description: CMAudioFormatDescription) -> AudioChannelLayoutTag? {
    var size = 0
    guard let layout = CMAudioFormatDescriptionGetChannelLayout(description, sizeOut: &size),
          size >= MemoryLayout<AudioChannelLayoutTag>.size else { return nil }
    return UnsafeRawPointer(layout).load(as: AudioChannelLayoutTag.self)
}

/// Erwarteter Layout-Tag: Umgebungsvariable (Test-Hook) oder HOA_ACN_SN3D | 4.
func expectedLayoutTag() -> AudioChannelLayoutTag {
    if let raw = ProcessInfo.processInfo.environment["APAC_EXPORT_EXPECT_LAYOUT_TAG"] {
        guard let value = AudioChannelLayoutTag(raw) else {
            fail("APAC_EXPORT_EXPECT_LAYOUT_TAG ist keine Zahl: '\(raw)'")
        }
        return value
    }
    return kAudioChannelLayoutTag_HOA_ACN_SN3D | 4
}

func inspectAudioTracks(at url: URL) async throws -> [AudioTrackInfo] {
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw ExportError(description: "Eingabedatei nicht gefunden: \(url.path)")
    }
    let asset = AVURLAsset(url: url)
    let tracks = try await asset.loadTracks(withMediaType: .audio)
    var result: [AudioTrackInfo] = []
    for (offset, track) in tracks.enumerated() {
        guard let description = try await track.load(.formatDescriptions).first else { continue }
        let basic = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee
        result.append(AudioTrackInfo(
            number: offset + 1,
            asset: asset,
            track: track,
            format: CMFormatDescriptionGetMediaSubType(description),
            channels: basic?.mChannelsPerFrame ?? 0,
            sampleRate: basic?.mSampleRate ?? 0,
            layoutTag: channelLayoutTag(of: description)))
    }
    return result
}

/// Spurauswahl ausschliesslich ueber die Format-Kennung (nicht Kanalzahl, nicht Index),
/// anschliessend harte Kanallayout-Zusicherung.
func selectSpatialTrack(from tracks: [AudioTrackInfo]) throws -> AudioTrackInfo {
    guard let info = tracks.first(where: { $0.format == kAudioFormatAPAC }) else {
        throw ExportError(description: "Keine APAC-Raumspur in der Eingabedatei gefunden "
            + "(Spuren: \(tracks.map { fourCCString($0.format) }.joined(separator: ", ")))")
    }
    let expected = expectedLayoutTag()
    guard info.layoutTag == expected else {
        throw ExportError(description: "Kanallayout der APAC-Spur ist \(layoutText(info.layoutTag)), "
            + "erwartet \(layoutText(expected)) (HOA ACN/SN3D, 4 Kanaele)")
    }
    return info
}

/// Reine PCM-Optionen: Float32, interleaved, Quellrate, Quellkanalzahl. Keine Spatial-Audio-
/// Optionen, kein AVAudioMix — sonst mischt AVFoundation Ambisonics auf Stereo herunter.
func pcmOutputSettings(for info: AudioTrackInfo) -> [String: Any] {
    [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: info.sampleRate,
        AVNumberOfChannelsKey: Int(info.channels),
        AVLinearPCMBitDepthKey: 32,
        AVLinearPCMIsFloatKey: true,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
    ]
}

/// Dekodiert die Spur; jeder Puffer von copyNextSampleBuffer() (variable Groesse) wird
/// vollstaendig kopiert und geschrieben, bevor der naechste angefordert wird.
func decode(_ info: AudioTrackInfo, into handle: FileHandle) throws -> Int {
    let reader = try AVAssetReader(asset: info.asset)
    let output = AVAssetReaderTrackOutput(track: info.track, outputSettings: pcmOutputSettings(for: info))
    output.alwaysCopiesSampleData = false
    reader.add(output)
    guard reader.startReading() else {
        throw ExportError(description: "AVAssetReader startet nicht: \(String(describing: reader.error))")
    }
    var written = 0
    while let sample = output.copyNextSampleBuffer() {
        guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
        let length = CMBlockBufferGetDataLength(block)
        var bytes = [UInt8](repeating: 0, count: length)
        let status = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: &bytes)
        guard status == kCMBlockBufferNoErr else {
            throw ExportError(description: "CMBlockBufferCopyDataBytes fehlgeschlagen (Status \(status))")
        }
        handle.write(Data(bytes))
        written += length
    }
    if reader.status == .failed {
        throw ExportError(description: "Dekodierung fehlgeschlagen: \(String(describing: reader.error))")
    }
    return written
}

func run() async {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let probe = arguments.first == "--probe"
    let paths = probe ? Array(arguments.dropFirst()) : arguments
    guard let inputPath = paths.first, paths.count <= (probe ? 1 : 2) else {
        fail("Aufruf: apac-export.swift --probe <input> | apac-export.swift <input> [output.pcm]")
    }
    let outputPath = probe ? nil : paths.dropFirst().first
    do {
        let tracks = try await inspectAudioTracks(at: URL(fileURLWithPath: inputPath))
        if probe {
            for info in tracks {
                print("track=\(info.number) format=\(fourCCString(info.format)) "
                    + "channels=\(info.channels) layout=\(layoutText(info.layoutTag))")
            }
            return
        }
        // Ausgabedatei erst nach erfolgreicher Spurauswahl + Layoutpruefung anlegen.
        let selected = try selectSpatialTrack(from: tracks)
        let handle: FileHandle
        if let outputPath {
            guard FileManager.default.createFile(atPath: outputPath, contents: nil) else {
                throw ExportError(description: "Ausgabedatei kann nicht angelegt werden: \(outputPath)")
            }
            handle = try FileHandle(forWritingTo: URL(fileURLWithPath: outputPath))
        } else {
            handle = FileHandle.standardOutput
        }
        do {
            let bytes = try decode(selected, into: handle)
            if outputPath != nil {
                try handle.close()
                let summary = "apac-export: \(bytes) Byte Float32-PCM, \(selected.channels) Kanaele, "
                    + "\(Int(selected.sampleRate)) Hz\n"
                FileHandle.standardError.write(Data(summary.utf8))
            }
        } catch {
            if let outputPath { try? FileManager.default.removeItem(atPath: outputPath) }
            throw error
        }
    } catch {
        fail("\(error)")
    }
}

await run()
