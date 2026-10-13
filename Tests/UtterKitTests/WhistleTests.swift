import Darwin
import Foundation
import Testing
@testable import UtterCore

@Suite("Whistle engine")
struct WhistleTests {
    private let second = WhistleProvider.sampleRate

    private func speech(seconds: Double) -> [Float] {
        (0..<Int(seconds * Double(second))).map { 0.3 * sin(Float($0) * 0.05) }
    }

    @Test("Up to 30 s is one pass")
    func shortAudioIsOneChunk() {
        let samples = speech(seconds: 30)
        #expect(WhistleProvider.chunks(of: samples) == [.init(audio: 0..<samples.count, keep: 0..<samples.count)])
    }

    @Test("Longer audio is cut inside a pause, with no overlap")
    func cutsAtPause() {
        var samples = speech(seconds: 45)
        let gap = 24 * second..<(24 * second + second / 2)
        for i in gap { samples[i] = 0.001 }
        let chunks = WhistleProvider.chunks(of: samples)
        #expect(chunks.count == 2)
        #expect(gap.contains(chunks[0].audio.upperBound))
        #expect(chunks[1].audio.lowerBound == chunks[0].audio.upperBound)
        #expect(chunks[0].keep == chunks[0].audio && chunks[1].keep == chunks[1].audio)
    }

    @Test("Without a pause, cuts are hard at 28 s with a 2 s overlap and a seam in its middle")
    func cutsHardWithOverlap() {
        let samples = speech(seconds: 70)
        let chunks = WhistleProvider.chunks(of: samples)
        #expect(chunks.map(\.audio) == [0..<28 * second, 26 * second..<54 * second, 52 * second..<samples.count])
        #expect(chunks.map(\.keep) == [0..<27 * second, 27 * second..<53 * second, 53 * second..<samples.count])
    }

    @Test("Stitching keeps each word once across an overlap")
    func stitchesOverlap() {
        let a = WhistleProvider.Chunk(audio: 0..<28 * second, keep: 0..<27 * second)
        let b = WhistleProvider.Chunk(audio: 26 * second..<40 * second, keep: 27 * second..<40 * second)
        let first: [WhistleEngine.Word] = [.init(word: "send", start: 25.0, end: 25.4),
                                           .init(word: "the", start: 26.7, end: 26.9),
                                           .init(word: "report", start: 27.1, end: 27.6)]
        let second: [WhistleEngine.Word] = [.init(word: "the", start: 0.75, end: 1.05),
                                            .init(word: " report", start: 1.1, end: 1.6),
                                            .init(word: "today", start: 1.7, end: 2.1)]
        #expect(WhistleProvider.stitch([(a, first), (b, second)]) == "send the report today")
    }

    @Test("The dictionary becomes newline-separated keywords, and only while biasing is on")
    func keywords() {
        let data = UserData(storageDir: nil)
        data.dictionaryWords = ["Kubernetes", "ab", "kubernetes", " Utter "]
        #expect(WhistleProvider.keywords(from: data) == "Kubernetes\nUtter")
        data.speechBiasEnabled = false
        #expect(WhistleProvider.keywords(from: data).isEmpty)
    }

    @Test("Whistle is used only when chosen and available")
    func routing() {
        let data = UserData(storageDir: nil)
        #expect(SpeechEngine.active(data) == .whisper)
        data.speechEngine = .whistle
        #expect(SpeechEngine.active(data) == (WhistleEngine.isAvailable ? .whistle : .whisper))
    }

    @Test("The engine loads and hears nothing in silence", .enabled(if: WhistleEngine.isAvailable))
    func silenceIsEmpty() async throws {
        let transcript = try await WhistleEngine.transcribe([Float](repeating: 0, count: second), keywords: "", wordTimes: true)
        #expect(transcript.text.isEmpty)
    }

    @Test("A settings file without the engine, or with an unknown one, decodes to Whisper")
    func oldSettingsDecode() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("utter-engine-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("userdata.json")
        try Data(#"{"words": ["Utter"]}"#.utf8).write(to: file)
        #expect(UserData(storageDir: directory).speechEngine == .whisper)
        try Data(#"{"speechEngine": "parakeet"}"#.utf8).write(to: file)
        #expect(UserData(storageDir: directory).speechEngine == .whisper)
        try Data(#"{"speechEngine": "whistle"}"#.utf8).write(to: file)
        #expect(UserData(storageDir: directory).speechEngine == .whistle)
    }
}

/// `UTTER_BENCH=whisper|whistle swift test --skip-update --filter WhistleBenchmark`, one engine per process
/// so peak memory is that engine's. Clips are made with `say` into `.build/whistle-bench`.
@Suite("Whistle benchmark", .serialized, .enabled(if: ProcessInfo.processInfo.environment["UTTER_BENCH"] != nil))
struct WhistleBenchmark {
    private static let clips: [(voice: String, text: String)] = [
        ("Samantha", "Can you send me the latest draft before lunch?"),
        ("Daniel", "Remind me to call the dentist tomorrow morning and ask about the cleaning appointment."),
        ("Karen", "Hey team, the deployment finished without errors. Please check the dashboard and let me know if anything looks off."),
        ("Ava (Premium)", "Hi Sarah, thanks for the update on the budget review. I think we should move the meeting to Thursday afternoon so that finance can join us."),
        ("Moira", "Open the configuration file, change the timeout value, and restart the server so the new settings take effect."),
        ("Rishi", "The Kubernetes pods keep restarting because the memory limit is too low for the indexing job."),
        ("Samantha", "I read through your proposal last night. The first section is clear and the examples help a lot. The pricing part needs more detail, especially around renewals. Could you add a short table that compares the three plans?"),
        ("Serena (Premium)", "Quick summary of the call with the design team. They want the onboarding flow shorter, so we will drop the second screen. Marketing still needs the new screenshots by the end of the week. I will follow up with legal about the privacy wording before we ship anything."),
        ("Daniel", "Here are my notes from the planning session. We agreed to focus on reliability this quarter. The crash rate on older machines is still too high, and most of it comes from the audio driver. Priya will own the investigation and report back next week. Tom will look at the slow startup on machines with many fonts installed. We also talked about the website. It needs a clearer download button and a short video that shows dictation in a real app. Finally, the support inbox is growing, so we will rotate who answers it every Monday."),
        ("Ava (Premium)", "so the main thing I wanted to flag is that the export keeps failing when the file name has spaces in it and I think it started after the last update because before that it worked fine for me and for everyone on the team and now we have to rename every file by hand which is slow and annoying and easy to get wrong so if someone could take a look at the upload code and check how it handles the path that would really help us and while you are in there it might be worth checking the retry logic too because when the network drops the export just stops without any message and people think it finished when it did not which means they send the wrong version to the client and then we have to apologise and send it again later"),
    ]

    private static func words(_ text: String) -> [String] {
        text.lowercased().replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    private static func editDistance(_ a: [String], _ b: [String]) -> Int {
        var row = Array(0...b.count)
        for (i, x) in a.enumerated() {
            var previous = row[0]
            row[0] = i + 1
            for (j, y) in b.enumerated() {
                let substitution = previous + (x == y ? 0 : 1)
                previous = row[j + 1]
                row[j + 1] = min(substitution, row[j] + 1, row[j + 1] + 1)
            }
        }
        return row[b.count]
    }

    private static func footprint() -> (now: UInt64, peak: UInt64) {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        _ = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return (info.phys_footprint, UInt64(info.ledger_phys_footprint_peak))
    }

    @Test func compare() async throws {
        let engine = try #require(SpeechEngine(rawValue: ProcessInfo.processInfo.environment["UTTER_BENCH"] ?? ""))
        let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/whistle-bench")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        UserData.preview = UserData(storageDir: nil)
        defer { UserData.preview = nil }

        var audio: [Data] = []
        for (index, clip) in Self.clips.enumerated() {
            let url = folder.appendingPathComponent("clip\(index).wav")
            if !FileManager.default.fileExists(atPath: url.path) {
                let say = Process()
                say.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                say.arguments = ["-v", clip.voice, "--data-format=LEI16@16000", "-o", url.path, clip.text]
                try say.run()
                say.waitUntilExit()
            }
            audio.append(try Data(contentsOf: url))
        }

        let baseline = Self.footprint().now
        let whisper = LocalWhisperProvider()
        let provider: TranscriptionProvider = engine == .whistle ? WhistleProvider() : whisper
        var errors = 0, referenceWords = 0, latencies: [Double] = []
        for (index, wav) in audio.enumerated() {
            let started = Date()
            let text = try await provider.transcribe(audioData: wav)
            latencies.append(Date().timeIntervalSince(started) * 1000)
            let reference = Self.words(Self.clips[index].text), hypothesis = Self.words(text)
            errors += Self.editDistance(reference, hypothesis)
            referenceWords += reference.count
            let seconds = Double(try LocalWhisperProvider.pcmSamples(fromWAV: wav).count) / 16_000
            print("bench \(engine) clip\(index) \(String(format: "%.1f", seconds))s \(Int(latencies[index]))ms wer=\(Self.editDistance(reference, hypothesis))/\(reference.count) | \(text)")
        }
        let peak = Self.footprint().peak
        let warm = latencies.dropFirst().sorted()
        print("bench \(engine) WER=\(String(format: "%.1f", 100 * Double(errors) / Double(referenceWords)))% first_text_cold_ms=\(Int(latencies[0])) warm_median_ms=\(Int(warm[warm.count / 2])) total_ms=\(Int(latencies.reduce(0, +))) peak_footprint_delta_mb=\((peak - baseline) / 1_048_576)")
        if engine == .whisper { await withCheckedContinuation { done in whisper.shutdown { done.resume() } } }
    }
}
