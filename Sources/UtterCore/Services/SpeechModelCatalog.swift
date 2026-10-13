import Foundation

/// The speech models a user can choose between, and which one suits this Mac.
///
/// Every speed and accuracy figure below was measured on this project's own
/// benchmark (whisper.cpp v1.9.1 with Metal, 12.8 s of technical dictation), not
/// taken from a vendor claim. `realtimeFactor` is how many seconds of audio are
/// transcribed per second of wall-clock on an M4; slower chips scale down roughly
/// with core count, which `Device.speedScale` accounts for.
package struct SpeechModel: Identifiable, Equatable {

    package enum Tier: String, CaseIterable {
        case base, small, medium, turbo
    }

    package let tier: Tier
    /// GGML filename on huggingface.co/ggerganov/whisper.cpp.
    let filename: String
    /// SHA-256 of the immutable Hugging Face artifact. Digest values are from
    /// the upstream file metadata at revision 0b364b566045a405be7225ee1e415a073e04da77.
    let sha256: String
    package let displayName: String
    /// Download size in megabytes.
    package let sizeMB: Int
    /// Peak resident memory while transcribing, measured.
    package let peakRAMMB: Int
    /// Seconds of audio transcribed per wall-clock second, measured on an M4.
    let realtimeFactor: Double
    /// Technical-jargon keywords recognised out of 10, measured.
    let jargonScore: Int
    /// Whether the model handles languages other than English.
    package let isMultilingual: Bool
    /// One-line plain-language summary for the UI.
    package let summary: String

    package var id: String { tier.rawValue }

    /// Models shipped inside the app, available with no download.
    ///
    /// Only `small` is bundled: it runs well on any Mac and keeps the installer
    /// at ~180 MB. Larger tiers are downloads because quantized weights barely
    /// compress - bundling every tier produced a 670 MB DMG for a dictation app.
    static let bundledTiers: Set<Tier> = [.small]

    /// The tier to fall back on when nothing else is available. `small` runs
    /// comfortably even on 8 GB.
    static let fallback = Tier.small

    package static func isBundled(_ tier: Tier) -> Bool { bundledTiers.contains(tier) }

    package static let all: [SpeechModel] = [
        SpeechModel(
            tier: .base,
            filename: "ggml-base.en-q5_1.bin",
            sha256: "4baf70dd0d7c4247ba2b81fafd9c01005ac77c2f9ef064e00dcf195d0e2fdd2f",
            displayName: "Base",
            sizeMB: 57,
            peakRAMMB: 180,
            realtimeFactor: 74.7,
            jargonScore: 8,
            isMultilingual: false,
            summary: "Fastest and smallest. Fine for everyday notes, weaker on unusual names."
        ),
        SpeechModel(
            tier: .small,
            filename: "ggml-small.en-q5_1.bin",
            sha256: "bfdff4894dcb76bbf647d56263ea2a96645423f1669176f4844a1bf8e478ad30",
            displayName: "Small",
            sizeMB: 181,
            peakRAMMB: 395,
            realtimeFactor: 33.7,
            jargonScore: 8,
            isMultilingual: false,
            summary: "Fast and light, English-only. A good default on any Mac, including 8 GB machines."
        ),
        SpeechModel(
            tier: .medium,
            filename: "ggml-medium.en-q5_0.bin",
            sha256: "76733e26ad8fe1c7a5bf7531a9d41917b2adc0f20f2e4f5531688a8c6cd88eb0",
            displayName: "Medium",
            sizeMB: 514,
            peakRAMMB: 815,
            realtimeFactor: 10.9,
            jargonScore: 9,
            isMultilingual: false,
            summary: "Most accurate on technical terms and unusual names, but English-only, so it can struggle with strong or non-native accents. 10\u{00D7} faster than real time."
        ),
        SpeechModel(
            tier: .turbo,
            filename: "ggml-large-v3-turbo-q5_0.bin",
            sha256: "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2",
            displayName: "Large Turbo",
            sizeMB: 547,
            peakRAMMB: 718,
            realtimeFactor: 11.2,
            jargonScore: 7,
            isMultilingual: true,
            summary: "Best for accented or non-native English. Trained across 99 languages, so it has heard far more pronunciation variation. Slightly weaker than Medium on technical jargon."
        ),
    ]

    package static func model(for tier: Tier) -> SpeechModel {
        all.first { $0.tier == tier } ?? all[1]
    }

    /// Estimated seconds to transcribe one minute of speech on this Mac.
    func secondsPerMinuteOfSpeech(scale: Double) -> Double {
        60.0 / (realtimeFactor * scale)
    }

    /// Whether this Mac has enough memory to run the model comfortably.
    ///
    /// The threshold is deliberately conservative: peak RAM is only the model's
    /// own footprint, and a dictation app has to coexist with whatever the user
    /// is actually working in.
    func fitsComfortably(in device: Device) -> Bool {
        Double(peakRAMMB) < Double(device.ramGB) * 1024 * 0.12
    }
}

// MARK: - Device capability

/// What we can learn about this Mac, used to recommend a model.
package struct Device {
    package let chipName: String
    package let ramGB: Int
    let performanceCores: Int
    package let totalCores: Int
    let isAppleSilicon: Bool
    let freeDiskGB: Int

    package static func current() -> Device { cachedCurrent }

    /// Hardware identity changes only across process launches. In particular,
    /// disk-capacity discovery must not run every time a SwiftUI view recomputes.
    private static let cachedCurrent = Device(
            chipName: sysctlString("machdep.cpu.brand_string") ?? "Unknown",
            ramGB: Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824),
            performanceCores: sysctlInt("hw.perflevel0.logicalcpu")
                ?? ProcessInfo.processInfo.activeProcessorCount,
            totalCores: ProcessInfo.processInfo.activeProcessorCount,
            isAppleSilicon: isARM(),
            freeDiskGB: freeDisk()
        )

    /// Rough multiplier against the M4 the benchmarks were taken on.
    ///
    /// whisper.cpp encode runs on the GPU via Metal and decode across performance
    /// cores, so performance-core count tracks throughput better than total cores.
    /// Intel Macs have no Metal-accelerated path of comparable speed, hence the
    /// much lower factor.
    var speedScale: Double {
        guard isAppleSilicon else { return 0.12 }
        switch performanceCores {
        case 0...3: return 0.72   // base M1/M2/M3 (4 P-cores reported as fewer)
        case 4: return 1.0        // M4 reference
        case 5...7: return 1.25   // Pro
        case 8...11: return 1.6   // Max
        default: return 2.0       // Ultra
        }
    }

    /// The model we suggest, given memory, chip, and disk.
    package var recommended: SpeechModel {
        // Not enough memory headroom for anything large.
        guard isAppleSilicon else { return .model(for: .base) }
        if ramGB <= 8 { return .model(for: .small) }
        if freeDiskGB < 2 { return .model(for: .small) }
        // 16 GB and up can hold Medium comfortably, and it scored best on
        // technical vocabulary in our own benchmark.
        if ramGB >= 16 && performanceCores >= 4 { return .model(for: .medium) }
        return .model(for: .small)
    }

    /// Why we recommend it, in the user's terms.
    var recommendationReason: String {
        guard isAppleSilicon else {
            return "\(chipName) has no Metal-accelerated path, so the smallest model keeps dictation responsive."
        }
        let rec = recommended
        if rec.tier == .medium {
            return "\(chipName) with \(ramGB) GB can run Medium - the most accurate English model - and still "
                + "transcribe far faster than you speak. Small is included and works now; "
                + "download Medium when you want the extra accuracy."
        }
        if ramGB <= 8 {
            return "\(ramGB) GB of memory suits the included Small model best - larger ones would compete "
                + "with your other apps."
        }
        return "Small is included and is a good fit for \(chipName)."
    }

    // MARK: sysctl helpers

    private static func sysctlString(_ key: String) -> String? {
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    private static func sysctlInt(_ key: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(key, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }

    private static func isARM() -> Bool {
        #if arch(arm64)
        return true
        #else
        // Rosetta: the process is x86 but the host may still be Apple Silicon.
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("sysctl.proc_translated", &value, &size, nil, 0) == 0 {
            return value == 1
        }
        return false
        #endif
    }

    private static func freeDisk() -> Int {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let bytes = values.volumeAvailableCapacityForImportantUsage
        else { return 0 }
        return Int(bytes / 1_073_741_824)
    }
}
