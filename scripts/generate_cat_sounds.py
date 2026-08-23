#!/usr/bin/env python3
"""
Generate the cat's voice: the three cues the pixel-cat companion makes.

It meows when a reminder lands and when a coding agent finishes, and purrs while
being stroked. Those are the only three sounds; a desktop pet that vocalises more than
that stops being company and becomes an interruption.

Written as synthesis rather than shipped as recordings for two reasons. A real cat
recording is someone's copyrighted audio, and a sampled meow is emotionally fixed — it
is always the same cat in the same mood, which fights a character whose whole job is to
react. Synthesis also keeps the assets at 60-120 KB of arithmetic instead of megabytes.

The shaping helpers are imported from `generate_sounds.py` rather than copied, so both
sound sets share one definition of the app's softness rules (raised-cosine attacks, a
one-pole low pass at 3.6 kHz, a guaranteed-zero tail, and a common −7.5 dBFS peak).
That matters: a cat cue that is brighter than the dictation cues would be the loudest
thing the app does, which is the wrong thing for a pet to be.

WHAT MAKES EACH ONE READ AS A CAT

* **The meow is a formant sweep, not a pitch sweep.** A cat's meow is recognisable from
  the *vowel* moving — roughly [e] → [a] → [o], the "mya-ow" — which is two resonances
  sliding down over a voiced tone. A bare rising-then-falling sine is a slide whistle,
  not a cat. So a harmonic-rich source at a swept fundamental (380 → 680 → 420 Hz, in
  the measured range for domestic-cat meows) is passed through two sweeping resonant
  bandpasses: F1 850 → 600 Hz, F2 1900 → 1100 Hz.

* **The purr is amplitude modulation, not a note.** A purr is a 20-30 Hz pulsing of the
  larynx, and the pulse *rate* is the cue. The companion purrs at 26 Hz.

  One honest deviation: the real fundamental sits near 25 Hz, and a laptop speaker
  cannot reproduce 25 Hz at all — a physically accurate purr is silent on the hardware
  this ships to. So the modulation stays at 26 Hz, where the perception lives, but it
  modulates a 58 Hz carrier with a 116 Hz partial, which small drivers can actually move.
  The rate is authentic; the carrier is chosen for the speaker.

* **The trill is the purr's rate applied to a chirp.** The "mrrp" a cat makes on greeting
  is a short rising call with a rolled, fluttering quality — the same fast modulation,
  over 0.22 s instead of 1.2 s.

Pure standard library plus those imports. Run:  python3 scripts/generate_cat_sounds.py
"""
import math
import os
import struct
import wave

# One definition of the app's sound-shaping rules, shared with the dictation cues.
from generate_sounds import RATE, at, mix, lowpass, fade_out, OUT_DIR

# Loudness the cat cues are matched to, in dBFS RMS.
#
# The dictation cues are matched on *peak* (−7.5 dBFS), which works because all four are
# struck notes with the same decaying shape. A meow is not that shape: it holds a plateau
# for 100 ms where a note is already decaying, so at equal peak it carries far more
# energy. Measured: peak-normalised alongside the existing set, the meow landed −18.2
# dBFS RMS against `done.wav`'s −21.5 — 3.3 dB hotter, which is the same "one cue jumps
# out" defect the dictation set was rebuilt to remove, and worse here because the pet
# vocalises while you are reading rather than when you asked for something.
#
# So these are matched on RMS instead, to the middle of the existing four (−20.0 to
# −21.7). Peak is left free; it lands around −10 dBFS, comfortably clear of clipping.
TARGET_RMS_DBFS = -21.0


# ── Sources ───────────────────────────────────────────────────────────────────

def voiced(f0_at, length, harmonics=14, jitter=0.004):
    """A glottal-ish tone whose pitch follows `f0_at(t) -> Hz`.

    Summed harmonics at 1/n amplitude, which is a sawtooth in the limit. A cat's call
    is harmonically dense — that density is what the formant filters below have to bite
    on. Filtering a pure sine does nothing audible, because there is no energy at the
    resonance to boost.

    Phase is integrated from the instantaneous frequency rather than computed as
    `sin(2*pi*f(t)*t)`. The second form is the classic sweep bug: it makes phase jump
    whenever the frequency changes, which is a click per sample.

    `jitter` is a slow random-free wobble (two detuned LFOs) standing in for the natural
    instability of a real voice. Without it the result is a synthesiser playing a vowel.
    """
    count = int(RATE * length)
    out = [0.0] * count
    phase = 0.0

    for i in range(count):
        t = i / RATE
        # Vibrato at 5.5 Hz — measured cat calls wobble at roughly 4-7 Hz — plus a
        # slower 1.7 Hz drift so successive cycles are not identical.
        wobble = 1.0 + jitter * (math.sin(2 * math.pi * 5.5 * t)
                                 + 0.6 * math.sin(2 * math.pi * 1.7 * t))
        f0 = max(40.0, f0_at(t) * wobble)
        phase += 2 * math.pi * f0 / RATE

        value = 0.0
        # Stop before Nyquist: a harmonic above RATE/2 aliases down as an audible
        # inharmonic whistle, which is the one artefact that instantly reads as "cheap
        # synth" rather than "animal".
        for n in range(1, harmonics + 1):
            if f0 * n >= RATE * 0.5:
                break
            value += math.sin(phase * n) / n
        out[i] = value * 0.5

    return out


def resonate(samples, centre_at, q=0.30, gain=1.0):
    """Sweepable resonant bandpass — one formant.

    A state-variable filter, chosen over a biquad because its coefficients can be
    modulated every sample without the transient blow-ups a recalculated biquad gives.
    `centre_at(t) -> Hz` is the formant's path; `q` is 1/Q, so 0.30 is Q≈3.3, which is
    resonant enough to colour the vowel without whistling.
    """
    count = len(samples)
    out = [0.0] * count
    low = band = 0.0

    for i, sample in enumerate(samples):
        # 2*sin(pi*fc/RATE) is the SVF's frequency coefficient. Clamped below 1.4
        # because the filter goes unstable as it approaches 2.
        f = min(1.4, 2.0 * math.sin(math.pi * min(centre_at(i / RATE), RATE * 0.45) / RATE))
        low += f * band
        high = sample - low - q * band
        band += f * high
        out[i] = band * gain

    return out


def envelope(samples, attack=0.040, hold=0.10, tau=0.18):
    """Raised-cosine open, flat hold, exponential release. Mutates and returns."""
    attack_n = max(1, int(RATE * attack))
    hold_n = int(RATE * hold)

    for i in range(len(samples)):
        if i < attack_n:
            env = 0.5 - 0.5 * math.cos(math.pi * i / attack_n)
        elif i < attack_n + hold_n:
            env = 1.0
        else:
            env = math.exp(-((i - attack_n - hold_n) / RATE) / tau)
        samples[i] *= env

    return samples


def save_voice(filename, samples):
    """Write one cue, matched on RMS rather than peak — see `TARGET_RMS_DBFS`.

    Everything else is the shared pipeline: the same one-pole low pass at 3.6 kHz and the
    same guaranteed-zero tail as the dictation cues, so the cat is shaped by the app's
    softness rules and differs only in how its level is chosen.
    """
    samples = fade_out(lowpass(samples))

    rms = math.sqrt(sum(s * s for s in samples) / len(samples)) or 1.0
    gain = (10 ** (TARGET_RMS_DBFS / 20.0)) / rms
    # A cue that would clip after RMS matching is a cue whose crest factor is wrong; back
    # it off to a safe peak instead of shipping distortion. None of the four hit this
    # today (worst peak lands near −10 dBFS), but silently clipping would be invisible in
    # the generator's own output.
    peak = max(abs(s) for s in samples) or 1.0
    if peak * gain > 0.95:
        gain = 0.95 / peak
    samples = [s * gain for s in samples]

    path = os.path.join(OUT_DIR, filename)
    frames = bytearray()
    for sample in samples:
        frames += struct.pack("<h", int(max(-1.0, min(1.0, sample)) * 32767))
    with wave.open(path, "w") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(bytes(frames))

    final_rms = math.sqrt(sum(s * s for s in samples) / len(samples))
    final_peak = max(abs(s) for s in samples)
    print(f"  ✓ {filename:22s} {len(samples) / RATE:.2f}s  "
          f"peak {20 * math.log10(final_peak):.1f} dBFS  "
          f"rms {20 * math.log10(final_rms + 1e-12):.1f} dBFS")


def ramp(start, end, over, then=None):
    """A value that slides `start` → `end` across `over` seconds, then holds `then`."""
    tail = end if then is None else then

    def value(t):
        if t >= over:
            return tail
        # Cosine ease, so the sweep has no corner at either end. A linear sweep's
        # corner is audible as a tick at the turnaround.
        k = 0.5 - 0.5 * math.cos(math.pi * t / over)
        return start + (end - start) * k

    return value


# ── The three cues ────────────────────────────────────────────────────────────

def build_meow():
    """A single short meow, 0.52 s.

    Pitch arcs 380 → 680 → 420 Hz: up into the call, down out of it. Both formants
    fall throughout, which is the [e] → [a] → [o] movement that makes it a meow rather
    than a hum. F2 falls further than F1 (800 Hz against 250), because it is the wide
    F2 travel that the ear reads as the vowel opening and closing.
    """
    length = 0.52

    def pitch(t):
        # Rise across the first third, fall across the rest.
        return ramp(380.0, 680.0, 0.17)(t) if t < 0.17 else ramp(680.0, 420.0, 0.35)(t - 0.17)

    source = voiced(pitch, length)
    first = resonate(source, ramp(850.0, 600.0, length), q=0.30, gain=1.0)
    second = resonate(source, ramp(1900.0, 1100.0, length), q=0.26, gain=0.55)
    # A little unfiltered source keeps the body; formants alone sound hollow.
    return envelope(mix(first, second, [s * 0.18 for s in source]),
                    attack=0.040, hold=0.10, tau=0.18)


def build_purr():
    """1.2 s of purring, 26 Hz pulse rate.

    Each pulse is a raised-cosine burst rather than a sine trough, because a purr is a
    *motor* — the ear hears distinct pulses, not a wobbling tone. The burst occupies 70%
    of each cycle, leaving a short gap that is what makes it grainy.

    Opens and closes on 0.18 s ramps so it can be retriggered while the user keeps
    stroking without a seam at the join.
    """
    length = 1.2
    count = int(RATE * length)
    rate_hz = 26.0
    out = [0.0] * count
    phase = 0.0

    for i in range(count):
        t = i / RATE
        # Carrier: 58 Hz with a 116 Hz partial. See the module docstring — the rate is
        # authentic, the carrier is raised so a laptop speaker can move it at all.
        phase += 2 * math.pi * 58.0 / RATE
        carrier = math.sin(phase) + 0.45 * math.sin(phase * 2) + 0.16 * math.sin(phase * 3)

        # Pulse train. `cycle` is 0..1 within one 26 Hz period.
        cycle = (t * rate_hz) % 1.0
        duty = 0.70
        pulse = 0.5 - 0.5 * math.cos(2 * math.pi * cycle / duty) if cycle < duty else 0.0

        # Purring is never perfectly even; a slow 3.1 Hz depth drift stops it sounding
        # like a tremolo plugin.
        depth = 0.82 + 0.18 * math.sin(2 * math.pi * 3.1 * t)

        # 0.22 floor: a purr does not fully stop between pulses, it dips.
        out[i] = carrier * (0.22 + depth * pulse) * 0.5

    edge = int(RATE * 0.18)
    for i in range(edge):
        fade = 0.5 - 0.5 * math.cos(math.pi * i / edge)
        out[i] *= fade
        out[count - 1 - i] *= fade

    return out


def build_trill():
    """A 0.24 s "mrrp" — the greeting chirp, used for reminders.

    The purr's modulation (here 33 Hz, faster because the call is short) over a rising
    380 → 620 Hz pitch. Rising and brief reads as a question, which is what a reminder
    is; the meow, arcing down, reads as a statement.
    """
    length = 0.24
    source = voiced(ramp(380.0, 620.0, length), length, harmonics=10)

    # The roll: fast amplitude flutter across the whole call.
    for i in range(len(source)):
        cycle = ((i / RATE) * 33.0) % 1.0
        source[i] *= 0.45 + 0.55 * (0.5 - 0.5 * math.cos(2 * math.pi * cycle))

    voice = resonate(source, ramp(1250.0, 900.0, length), q=0.28)
    return envelope(mix(voice, [s * 0.22 for s in source]),
                    attack=0.018, hold=0.06, tau=0.09)


def build_meow_double():
    """Two meows, the second lower and quieter — "mrow-mow".

    For the agent-finished hop, where a single meow is easy to miss if you are reading.
    Two calls with the second dropping in pitch is how a cat repeats itself, and the
    0.30 s offset overlaps the first tail so it is one utterance, not two cues.
    """
    first = build_meow()
    second = [s * 0.72 for s in envelope(
        mix(resonate(voiced(ramp(560.0, 360.0, 0.44), 0.44), ramp(780.0, 560.0, 0.44)),
            resonate(voiced(ramp(560.0, 360.0, 0.44), 0.44), ramp(1700.0, 1000.0, 0.44),
                     q=0.26, gain=0.5)),
        attack=0.035, hold=0.07, tau=0.16)]
    return mix(first, at(0.30, second))


def main():
    print("Generating the cat's voice...")
    save_voice("cat-meow.wav", build_meow())
    save_voice("cat-meow-double.wav", build_meow_double())
    save_voice("cat-purr.wav", build_purr())
    save_voice("cat-trill.wav", build_trill())
    print("\nDone. Four cues in Sounds/.")


if __name__ == "__main__":
    main()
