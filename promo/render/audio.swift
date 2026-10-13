import Foundation

// A 130 BPM funk-carioca groove, synthesized so the cuts sit exactly on its grid.
let sampleRate = 48_000.0
let bpm = 130.0
let beatSeconds = 60.0 / bpm
let stepSeconds = beatSeconds / 4

struct Track {
    var left: [Float]
    var right: [Float]

    init(seconds: Double) {
        let count = Int(seconds * sampleRate) + Int(sampleRate)
        left = Array(repeating: 0, count: count)
        right = left
    }

    mutating func add(_ at: Double, _ samples: [Float], gain: Float = 1, pan: Float = 0) {
        let start = Int(at * sampleRate)
        let l = gain * min(1, 1 - pan), r = gain * min(1, 1 + pan)
        for (i, s) in samples.enumerated() where start + i >= 0 && start + i < left.count {
            left[start + i] += s * l
            right[start + i] += s * r
        }
    }
}

private var noiseState: UInt32 = 0x1234_5678
private func noise() -> Float {
    noiseState ^= noiseState << 13; noiseState ^= noiseState >> 17; noiseState ^= noiseState << 5
    return Float(Int32(bitPattern: noiseState)) / Float(Int32.max)
}

private func render(_ seconds: Double, _ sample: (Double) -> Double) -> [Float] {
    (0..<Int(seconds * sampleRate)).map { Float(sample(Double($0) / sampleRate)) }
}

func kick(_ big: Bool = false) -> [Float] {
    var phase = 0.0
    return render(big ? 0.9 : 0.5) { x in
        phase += 2 * .pi * (46 + 120 * exp(-x * 32)) / sampleRate
        let body = sin(phase) * exp(-x * (big ? 3.8 : 7))
        let click = x < 0.004 ? Double(noise()) * 0.5 : 0
        return tanh(2.4 * (body + click)) * 0.95
    }
}

func clap() -> [Float] {
    var last: Float = 0
    return render(0.25) { x in
        let bursts = [0.0, 0.011, 0.022].reduce(0.0) { sum, o in x >= o ? sum + exp(-(x - o) * 170) : sum }
        let env = min(1, bursts) * 0.8 + exp(-x * 20) * 0.45
        let n = noise(); let hp = n - last * 0.86; last = n
        return Double(hp) * env * 0.7
    }
}

func hat(open: Bool = false) -> [Float] {
    var last: Float = 0
    return render(open ? 0.22 : 0.05) { x in
        let n = noise(); let hp = n - last; last = n
        return Double(hp) * exp(-x * (open ? 14 : 75)) * 0.35
    }
}

func tom(_ freq: Double) -> [Float] {
    var phase = 0.0
    return render(0.22) { x in
        phase += 2 * .pi * freq * (1 + 0.6 * exp(-x * 45)) / sampleRate
        return (sin(phase) * 0.8 + Double(noise()) * 0.15 * exp(-x * 60)) * exp(-x * 15)
    }
}

func sub(_ freq: Double, _ seconds: Double) -> [Float] {
    var phase = 0.0
    return render(seconds) { x in
        phase += 2 * .pi * freq / sampleRate
        let env = min(1, x / 0.006) * exp(-x * 2.6) * min(1, (seconds - x) / 0.02)
        return tanh(1.6 * sin(phase)) * env * 0.75
    }
}

func lead(_ freq: Double, _ seconds: Double, detune: Double) -> [Float] {
    var phase = 0.0, low = 0.0
    return render(seconds) { x in
        phase += freq * detune / sampleRate
        let saw = 2 * (phase - floor(phase)) - 1
        let square = phase - floor(phase) < 0.5 ? 1.0 : -1.0
        let cutoff = 0.05 + 0.35 * exp(-x * 9)
        low += cutoff * ((saw * 0.6 + square * 0.4) - low)
        let env = min(1, x / 0.004) * exp(-x * 5) * min(1, (seconds - x) / 0.015)
        return low * env * 0.5
    }
}

func riser(_ seconds: Double) -> [Float] {
    var low = 0.0, phase = 0.0
    return render(seconds) { x in
        let p = x / seconds
        low += (0.01 + 0.5 * p * p) * (Double(noise()) - low)
        phase += 2 * .pi * (180 + 1400 * p * p) / sampleRate
        return (low * 0.9 + sin(phase) * 0.18) * p * p
    }
}

func impact() -> [Float] {
    var low = 0.0
    let boom = kick(true)
    return render(1.6) { x in
        low += 0.04 * (Double(noise()) - low)
        let i = Int(x * sampleRate)
        return (i < boom.count ? Double(boom[i]) : 0) + low * exp(-x * 2.5) * 1.2
    }
}

func whoosh(_ seconds: Double) -> [Float] {
    var low = 0.0
    return render(seconds) { x in
        let p = x / seconds
        low += (0.05 + 0.4 * p) * (Double(noise()) - low)
        return low * sin(.pi * p) * 0.8
    }
}

/// The whole soundtrack, arranged by bar: intro, build, riser, drop at beat 20, logo hit at 44.
func soundtrack(beats: Double) -> Track {
    var t = Track(seconds: beats * beatSeconds)
    let k = kick(), c = clap(), h = hat(), ho = hat(open: true)
    let toms = [tom(210), tom(165)]
    let roots = [110.0, 87.31, 98.0, 82.41]   // A2 F2 G2 E2
    let riff: [Double?] = [440, nil, 523.25, 440, nil, 659.25, 587.33, nil, 523.25, nil, 440, nil, 392, nil, 440, nil]
    let riffB: [Double?] = [440, nil, 523.25, 440, nil, 659.25, 587.33, nil, 659.25, 783.99, 659.25, nil, 587.33, nil, 523.25, nil]
    func at(_ bar: Int, _ step: Int) -> Double { (Double(bar * 16 + step)) * stepSeconds }

    for bar in 0..<12 {
        let drop = (5...10).contains(bar)
        let silentTail = bar == 4
        for step in 0..<16 {
            if silentTail && step >= 14 { continue }
            let time = at(bar, step)
            if [0, 3, 7, 10].contains(step) && bar != 11 { t.add(time, k, gain: drop ? 1 : 0.85) }
            if [4, 12].contains(step) && bar != 11 { t.add(time, c, gain: 0.55) }
            if bar >= 2 && bar != 11 && [2, 6, 9, 13, 14].contains(step) { t.add(time, toms[step % 2], gain: 0.4, pan: step % 2 == 0 ? -0.3 : 0.3) }
            if bar >= 2 && bar != 11 && step % 2 == 1 { t.add(time, step == 15 ? ho : h, gain: 0.5, pan: 0.2) }
            if drop, [0, 3, 7, 10].contains(step) {
                t.add(time, sub(roots[bar % 4] / 2, stepSeconds * 2.6), gain: 0.55)
            }
            if drop, let note = (bar % 2 == 0 ? riff : riffB)[step] {
                t.add(time, lead(note, stepSeconds * 1.6, detune: 1.004), gain: 0.16, pan: -0.45)
                t.add(time, lead(note, stepSeconds * 1.6, detune: 0.996), gain: 0.16, pan: 0.45)
                t.add(time, lead(note * 2, stepSeconds * 1.2, detune: 1), gain: 0.05)
            }
        }
    }
    t.add(at(4, 0), riser(beatSeconds * 3.5), gain: 0.5)
    t.add(at(5, 0), impact(), gain: 0.9)
    for wipe in [3.5, 15.5, 27.5, 39.5] { t.add(wipe * beatSeconds, whoosh(beatSeconds * 0.5), gain: 0.35) }
    t.add(at(11, 0), impact(), gain: 0.85)
    t.add(at(12, 0), kick(true), gain: 0.8)
    return t
}

/// 16-bit stereo WAV, peak-normalised to -1 dBFS through a soft clip.
func writeWAV(_ track: Track, to url: URL) throws {
    let peak = max(track.left.map(abs).max() ?? 1, track.right.map(abs).max() ?? 1)
    let scale = 0.89 / max(peak, 0.0001)
    var data = Data()
    func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { data.append(contentsOf: $0) } }
    let frames = track.left.count
    data.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + frames * 4)); data.append(contentsOf: Array("WAVEfmt ".utf8))
    u32(16); u16(1); u16(2); u32(UInt32(sampleRate)); u32(UInt32(sampleRate) * 4); u16(4); u16(16)
    data.append(contentsOf: Array("data".utf8)); u32(UInt32(frames * 4))
    for i in 0..<frames {
        for s in [track.left[i], track.right[i]] {
            u16(UInt16(bitPattern: Int16(max(-1, min(1, tanh(s * scale * 1.1))) * 32_000)))
        }
    }
    try data.write(to: url)
}
