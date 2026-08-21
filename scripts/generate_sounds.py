#!/usr/bin/env python3
"""
Generate Utter's UI sounds.

These fire on every dictation, many times an hour, so the goal is a cue you
notice without being interrupted by. That is a property of the *sound design*,
not the playback volume — a sharp sound played quietly is still sharp, just
faint. The previous set was harsh for four measurable reasons, each fixed here:

  * **Clicky attacks.** A 5 ms linear ramp is a corner in the waveform, and a
    corner is broadband energy — a click. Every note now opens on a 28-40 ms
    raised-cosine ramp, which is smooth in both value and slope, so there is no
    transient to hear.

  * **Spliced pitch changes.** The old two-tone cues concatenated one sine onto
    another. The phase jumps at the seam, which is another click, right in the
    middle of the sound. Notes now *overlap* and crossfade, so pitch moves
    without a discontinuity.

  * **Fundamentals too high.** 880 Hz and 1108 Hz sit in the ear's most
    sensitive band (2-5 kHz once harmonics are counted), which is exactly where
    "piercing" lives. Everything moved down roughly an octave, to 260-660 Hz.

  * **No spectral shaping.** A bare sine is sterile, and any residual edge stays
    bright. Each voice gets a quiet octave partial for body, a slightly detuned
    twin for slow chorus movement, and a gentle low-pass to round the top end.

Long exponential tails do most of the perceptual work: soft instruments
(marimba, glass, felt piano) are recognisable by how they *end*, not how they
start. Assets are peak-normalised to a common level so no cue is louder than
its neighbour — the old set varied by ~4 dB, which made "done" jump out.

Pure standard library on purpose: this machine has no numpy, so the previous
version could not run at all, and the build silently shipped stale March assets.
A few thousand samples of arithmetic is nothing in plain Python.
"""
import math
import os
import struct
import wave

RATE = 44100
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "Sounds")

# Peak level every asset is normalised to. Soft but unambiguously present; the
# player applies its own modest volume on top.
TARGET_PEAK = 0.42

# Rounds off the top end without dulling the note. Above this the ear mostly
# hears "edge", which is the quality being removed.
LOWPASS_HZ = 3600.0


# ── Note synthesis ────────────────────────────────────────────────────────────

def note(freq, length, attack=0.030, tau=0.22, gain=1.0,
         octave=0.16, detune=0.7):
    """One soft voice.

    freq    fundamental, Hz
    length  total samples produced, seconds
    attack  raised-cosine fade-in; >=25 ms is what removes the click
    tau     exponential decay constant — the tail, and the main "soft" cue
    octave  amplitude of the +1 octave partial, for body without brightness
    detune  Hz offset of a second voice, giving slow chorus-like movement
    """
    count = int(RATE * length)
    attack_n = max(1, int(RATE * attack))
    out = [0.0] * count

    for i in range(count):
        t = i / RATE

        # Fundamental plus a detuned twin. The pair beat against each other at
        # `detune` Hz, which reads as warmth rather than as two notes.
        value = math.sin(2 * math.pi * freq * t)
        value += 0.55 * math.sin(2 * math.pi * (freq + detune) * t)
        value /= 1.55

        if octave:
            value += octave * math.sin(2 * math.pi * freq * 2 * t)
            value /= 1.0 + octave

        # Envelope: smooth open, exponential tail.
        if i < attack_n:
            env = 0.5 - 0.5 * math.cos(math.pi * i / attack_n)
        else:
            env = 1.0
        env *= math.exp(-(t if i >= attack_n else 0.0) / tau)

        out[i] = value * env * gain

    return out


def mix(*layers):
    """Sum layers of differing length into one buffer."""
    length = max(len(layer) for layer in layers)
    out = [0.0] * length
    for layer in layers:
        for i, sample in enumerate(layer):
            out[i] += sample
    return out


def at(offset, samples):
    """Shift `samples` later by `offset` seconds — overlap instead of splice."""
    return [0.0] * int(RATE * offset) + samples


# ── Shaping ───────────────────────────────────────────────────────────────────

def lowpass(samples, cutoff=LOWPASS_HZ):
    """One-pole low-pass. Rounds the top end; no resonance, no ringing."""
    rc = 1.0 / (2 * math.pi * cutoff)
    dt = 1.0 / RATE
    alpha = dt / (rc + dt)
    out = [0.0] * len(samples)
    prev = 0.0
    for i, sample in enumerate(samples):
        prev += alpha * (sample - prev)
        out[i] = prev
    return out


def fade_out(samples, seconds=0.025):
    """Guarantee the buffer reaches exactly zero.

    An exponential tail is never truly zero, and a non-zero final sample is a
    step edge — the click that ends a sound instead of the sound ending.
    """
    n = min(int(RATE * seconds), len(samples))
    for i in range(n):
        # Raised cosine again, so the slope also reaches zero.
        samples[len(samples) - n + i] *= 0.5 + 0.5 * math.cos(math.pi * i / n)
    return samples


def normalize(samples, peak=TARGET_PEAK):
    """Scale to a common peak so no cue is louder than another."""
    current = max(abs(sample) for sample in samples) or 1.0
    scale = peak / current
    return [sample * scale for sample in samples]


def save_wav(filename, samples):
    samples = fade_out(normalize(lowpass(samples)))
    path = os.path.join(OUT_DIR, filename)
    frames = bytearray()
    for sample in samples:
        clamped = max(-1.0, min(1.0, sample))
        frames += struct.pack("<h", int(clamped * 32767))
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(bytes(frames))

    rms = math.sqrt(sum(s * s for s in samples) / len(samples))
    print(f"  ✓ {filename:10s} {len(samples) / RATE:.2f}s  "
          f"peak {20 * math.log10(TARGET_PEAK):.1f} dBFS  "
          f"rms {20 * math.log10(rms + 1e-12):.1f} dBFS")


# ── The four cues ─────────────────────────────────────────────────────────────

def build_start():
    """Recording opens: a soft rising major third, A4 → C#5.

    Rising says "beginning". The second note enters while the first is still
    sounding, so the interval blooms rather than stepping.
    """
    return mix(
        note(440.00, 0.55, attack=0.030, tau=0.20, gain=0.75),
        at(0.075, note(554.37, 0.62, attack=0.034, tau=0.26, gain=0.80)),
    )


def build_stop():
    """Recording closes: the same third, falling. Slightly longer tail so it
    settles rather than stops."""
    return mix(
        note(554.37, 0.55, attack=0.030, tau=0.19, gain=0.72),
        at(0.080, note(440.00, 0.70, attack=0.036, tau=0.30, gain=0.80)),
    )


def build_done():
    """Text delivered: a soft, wide-spaced major triad, F4 → A4 → C5.

    Generous overlap and long tails give the felt-mallet quality. The top note
    stays at C5 (523 Hz) — high enough to read as resolution, low enough not to
    ping.
    """
    return mix(
        note(349.23, 0.85, attack=0.028, tau=0.34, gain=0.62),
        at(0.070, note(440.00, 0.85, attack=0.030, tau=0.36, gain=0.60)),
        at(0.140, note(523.25, 0.90, attack=0.032, tau=0.42, gain=0.66)),
    )


def build_error():
    """Something failed: a low falling minor second, A3 → G#3.

    Deliberately *not* the old double tap — a tap is a click by construction,
    and repeating it doubles the harshness. A close falling interval is
    unmistakably negative while staying quiet: the tension is in the harmony,
    not the transient.

    An octave below the other cues, and the only one with no upper partial
    (`octave=0`), so it is measurably the darkest of the four — an error should
    never be the brightest sound the app makes. The slowest attack here too;
    nothing about this cue should feel like a jab.
    """
    return mix(
        note(220.00, 0.70, attack=0.040, tau=0.28, gain=0.72, octave=0.0),
        at(0.120, note(207.65, 0.85, attack=0.046, tau=0.34, gain=0.74,
                       octave=0.0)),
    )


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("Generating sounds...")
    save_wav("start.wav", build_start())
    save_wav("stop.wav", build_stop())
    save_wav("done.wav", build_done())
    save_wav("error.wav", build_error())
    print(f"\nAll sounds saved to {os.path.normpath(OUT_DIR)}/")


if __name__ == "__main__":
    main()
