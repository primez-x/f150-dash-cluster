#!/usr/bin/env python3
"""Synthesize two replacement chime sets for the F150 cluster.

Set A "soft": warm sine and soft-FM bell tones, D major pentatonic.
Set B "crisp": bright glassy bell tones, E major pentatonic.

Every output keeps the stock file name, sample rate, channel count, sample
width, frame count and event onsets. The native plugin decides when each file
plays, so the timeline inside each file must not change.

Pure numpy and the wave module. No randomness. Run:
    python make_sounds.py
"""
import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
TAU = 2.0 * np.pi

# Stock sample rate and frame count (measured from the capture-04 files).
FRAMES = {
    "direct_slow": (48000, 34163), "direct_quick": (48000, 15381),
    "door": (48000, 29870), "breaker": (48000, 19176),
    "ding": (48000, 57608), "buzzer": (48000, 39347),
    "seatbelt_slow": (44100, 106572), "seatbelt_quick": (44100, 41609),
    "radar_b0": (44100, 1075200), "radar_b1": (44100, 837632),
    "radar_b2": (44100, 929792), "radar_b3": (44100, 925696),
    "radar_b4": (44100, 704512), "radar_b5": (44100, 1142784),
    "radar_b6": (44100, 1093632),
}

# Active RMS of each stock file in dBFS (left channel, measured with active_mask).
# Each output is scaled so the active RMS equals this value. A scale that would
# push the peak above PEAK_CAP_DB is capped, and the verify report shows the delta.
STOCK_RMS_DB = {
    "breaker": -4.30, "buzzer": -1.07, "ding": -10.36, "direct_quick": -15.03,
    "direct_slow": -11.86, "door": -4.22, "radar_b0": -10.69, "radar_b1": -10.52,
    "radar_b2": -9.39, "radar_b3": -8.74, "radar_b4": -8.42, "radar_b5": -7.70,
    "radar_b6": -7.73, "seatbelt_quick": -17.43, "seatbelt_slow": -22.65,
}
PEAK_CAP_DB = -0.5

RADAR_RIGHT_GAIN = 0.047  # stock radar files carry the right channel at -26 dB
PREVIEW_SECONDS = 4
PREVIEW_FADE = 0.010


def bursts(x, sr, win_ms=0.5, rel=0.1, gap_ms=2.0):
    """Burst list (start, end) in seconds from a thresholded peak envelope."""
    h = max(1, int(round(sr * win_ms / 1000.0)))
    m = np.abs(x) if x.ndim == 1 else np.abs(x).max(axis=1)
    nw = len(m) // h
    env = m[: nw * h].reshape(nw, h).max(axis=1)
    act = env > rel * env.max()
    runs, i = [], 0
    while i < len(act):
        if act[i]:
            j = i
            while j < len(act) and act[j]:
                j += 1
            runs.append([i * h / sr, j * h / sr])
            i = j
        else:
            i += 1
    merged = []
    for r in runs:
        if merged and r[0] - merged[-1][1] < gap_ms / 1000.0:
            merged[-1][1] = r[1]
        else:
            merged.append(r)
    return merged


def active_mask(x, sr):
    """True where the sound is active: above 2% of the peak, gaps under 5 ms merged."""
    mask = np.zeros(len(x), bool)
    for a, e in bursts(x, sr, win_ms=1.0, rel=0.02, gap_ms=5.0):
        mask[int(a * sr): int(e * sr)] = True
    return mask


def hz(note_name):
    """Equal-tempered frequency for names like 'A5' or 'F#6'."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    n = names[note_name[0]]
    rest = note_name[1:]
    if rest[0] == "#":
        n += 1
        rest = rest[1:]
    midi = 12 * (int(rest) + 1) + n
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


TRITONE = 2.0 ** 0.5


# ---------------------------------------------------------------- voices
# The FM index and the third harmonic fade in this time, so the body turns into a
# plain sine while the envelope tau sets the length of the body.
SOFT_BRIGHT_TAU = 0.12


def voice_soft(f, t, tau):
    """Warm bell: 1:1 FM with a decaying index plus a soft third harmonic."""
    bright = np.exp(-t / SOFT_BRIGHT_TAU)
    y = np.sin(TAU * f * t + 0.9 * bright * np.sin(TAU * f * t))
    y += 0.12 * np.sin(TAU * 3.0 * f * t) * bright
    return y


# (frequency ratio, amplitude, decay time in s) of the glass bell partials.
# The fundamental sets the body. These partials give the glassy strike.
GLASS_PARTIALS = ((2.756, 0.16, 0.120), (5.404, 0.072, 0.060), (8.93, 0.036, 0.030))


def voice_glass(f, t, tau):
    """Glassy bell: inharmonic partials that die faster than the body."""
    y = np.sin(TAU * f * t)
    for ratio, amp, decay in GLASS_PARTIALS:
        if ratio * f < 7500.0:
            y += amp * np.sin(TAU * ratio * f * t) * np.exp(-t / decay)
    return y


STYLES = {
    "a": {
        "voice": voice_soft,
        "attack": 0.005, "tick_attack": 0.0012, "tick_tau": 0.0040,
        "tick_hi": hz("A5"), "tick_lo": hz("F#5"),
        "door": (hz("A5"), 20.0),
        "seat_hi": hz("B5"), "seat_lo": hz("E5"), "seat_tau": 0.09,
        "ding": ((hz("A5"), 1.0), (hz("E6"), 0.5)), "ding_tau": 1.20,
        "breaker": (hz("F#5"), hz("D6")), "breaker_tau": 20.0,
        "buzzer": (hz("A5"), hz("A5") * TRITONE), "buzzer_warble": (4.0, 3.0),
        "radar": hz("E5"), "ping": None,
        "radar_b5": (hz("E5"), hz("B5")), "radar_b6": (hz("E5"), hz("F5")),
    },
    "b": {
        "voice": voice_glass,
        "attack": 0.001, "tick_attack": 0.0006, "tick_tau": 0.0045,
        "tick_hi": hz("G#6"), "tick_lo": hz("E6"),
        "door": (hz("G#6"), 20.0),
        "seat_hi": hz("B6"), "seat_lo": hz("E6"), "seat_tau": 0.11,
        "ding": ((hz("E6"), 1.0), (hz("B6"), 0.5)), "ding_tau": 1.50,
        "breaker": (hz("G#6"), hz("E7")), "breaker_tau": 20.0,
        "buzzer": (hz("B5"), hz("B5") * TRITONE), "buzzer_warble": (8.0, 4.0),
        "radar": hz("E6"), "ping": 3.0,
        "radar_b5": (hz("B5"), hz("F#6")), "radar_b6": (hz("B5"), hz("C6")),
    },
}


# ------------------------------------------------------------- primitives
def envelope(n, sr, attack, release, tau=None):
    """Raised-cosine fade in and out. First and last sample are exactly zero."""
    env = np.ones(n)
    na = max(2, min(n // 2, int(round(attack * sr))))
    env[:na] *= 0.5 * (1.0 - np.cos(np.pi * np.arange(na) / na))
    nr = max(2, min(n // 2, int(round(release * sr))))
    env[n - nr:] *= 0.5 * (1.0 + np.cos(np.pi * np.arange(1, nr + 1) / nr))
    if tau:
        env *= np.exp(-np.arange(n) / sr / tau)
    return env


def note(style, sr, f, length, tau, release=0.015, attack=None, gain=1.0):
    """One bell note of `length` seconds with a natural exponential decay."""
    n = int(round(length * sr))
    t = np.arange(n) / sr
    a = style["attack"] if attack is None else attack
    return gain * style["voice"](f, t, tau) * envelope(n, sr, a, release, tau)


def place(buf, sig, start, sr):
    i = int(round(start * sr))
    j = min(len(buf), i + len(sig))
    buf[i:j] += sig[: j - i]


def tick(style, sr, f):
    """Short soft tock. The stock tick lasts about 11 ms, so the tock fits there."""
    n = int(round(0.0105 * sr))
    t = np.arange(n) / sr
    y = np.sin(TAU * f * t) + 0.25 * np.sin(TAU * 2.5 * f * t) * np.exp(-t / 0.0015)
    return y * envelope(n, sr, style["tick_attack"], 0.003, style["tick_tau"])


# ------------------------------------------------------------------ files
def make_direct(style, name):
    """Three ticks per file: on (high), off (low), on (high), at the stock times."""
    sr, n = FRAMES[name]
    buf = np.zeros(n)
    onsets = (0.001, 0.350, 0.700) if name == "direct_slow" else (0.0, 0.109, 0.309)
    pitches = (style["tick_hi"], style["tick_lo"], style["tick_hi"])
    for onset, f in zip(onsets, pitches):
        place(buf, tick(style, sr, f), onset, sr)
    return buf


def make_door(style):
    sr, n = FRAMES["door"]
    buf = np.zeros(n)
    f, tau = style["door"]
    place(buf, note(style, sr, f, 0.325, tau, release=0.025), 0.001, sr)
    return buf


def make_breaker(style):
    """Two rising notes that cross-fade inside the stock 0.2 s burst."""
    sr, n = FRAMES["breaker"]
    buf = np.zeros(n)
    f1, f2 = style["breaker"]
    tau = style["breaker_tau"]
    place(buf, note(style, sr, f1, 0.105, tau, release=0.012, attack=0.004), 0.001, sr)
    place(buf, note(style, sr, f2, 0.1105, tau, release=0.010, attack=0.012), 0.094, sr)
    return buf


def make_ding(style):
    sr, n = FRAMES["ding"]
    buf = np.zeros(n)
    for f, g in style["ding"]:
        place(buf, note(style, sr, f, 1.18, style["ding_tau"], release=0.10, gain=g), 0.0, sr)
    return buf


def make_buzzer(style):
    """Continuous two-pitch warble between a tritone, with a flat level.

    The oscillator is tanh(g * sin(phase)), a rounded square wave. The crest
    factor is low, so the buzzer reaches the stock RMS under the peak cap.
    """
    sr, n = FRAMES["buzzer"]
    t = np.arange(n) / sr
    rate, shape = style["buzzer_warble"]
    f1, f2 = style["buzzer"]
    glide = 0.5 * (1.0 + np.tanh(4.0 * np.sin(TAU * rate * t)))
    phase = TAU * np.cumsum(f1 + (f2 - f1) * glide) / sr
    return np.tanh(shape * np.sin(phase)) * envelope(n, sr, 0.006, 0.012)


def echo_train(style, buf, sr, f, repeats, stop):
    """One note at 0.134 s, then repeats at the stock spacing, each 0.65 times softer."""
    onsets = [0.134] + list(repeats)
    for k, start in enumerate(onsets):
        end = min(onsets[k + 1] - 0.003 if k + 1 < len(onsets) else stop, stop)
        if end - start < 0.02:
            continue
        place(buf, note(style, sr, f, end - start, style["seat_tau"],
                        release=0.02, gain=0.65 ** k), start, sr)


def make_seatbelt(style, name):
    """Stock structure: a high voice repeating every 0.2505 s and a low voice every 0.306 s."""
    sr, n = FRAMES[name]
    buf = np.zeros(n)
    if name == "seatbelt_slow":
        hi = [0.328 + 0.2505 * j for j in range(9)]
        lo = [0.329 + 0.306 * j for j in range(7)]
        stop = n / sr - 0.03
    else:
        hi, lo, stop = [0.328], [0.329], 0.600
    echo_train(style, buf, sr, style["seat_hi"], hi, stop)
    echo_train(style, buf, sr, style["seat_lo"], lo, stop)
    return buf


# Radar beep schedules measured from the stock files: optional first beep
# (onset, length), then `count` beeps from t0 at `period`, each `length` long.
# The last beep is shorter because the stock file cuts the final beep.
RADAR = {
    "radar_b0": dict(first=(0.3497, 0.2524), t0=0.7872, period=0.47722, count=50,
                     length=0.2923, last=0.1960),
    "radar_b1": dict(first=(0.3497, 0.2764), t0=0.6824, period=0.34951, count=53,
                     length=0.2943, last=0.1188),
    "radar_b2": dict(first=None, t0=0.3664, period=0.26886, count=77,
                     length=0.2372, last=0.2372),
    "radar_b3": dict(first=None, t0=0.3729, period=0.18148, count=114,
                     length=0.1666, last=0.0967),
    "radar_b4": dict(first=(0.3497, 0.0449), t0=0.4078, period=0.14115, count=111,
                     length=0.1282, last=0.0273),
}
# Continuous radar files: tone from 0.3497 s to this end time.
CONTINUOUS_END = {"radar_b5": 25.8837, "radar_b6": 24.7857}
# The closest-range tone beats against a weaker second tone, so the level never gates.
CONTINUOUS_SECOND_GAIN = {"radar_b5": 1.0, "radar_b6": 0.6}
SOFT_BEEP_HARMONICS = (1.0, 0.25, 0.08)
SOFT_BEEP_ATTACK = 0.008


def beep(style, sr, f, length, which):
    """Soft set: a sustained rounded beep. Crisp set: a short ping that decays."""
    n = int(round(length * sr))
    if which == "a":
        t = np.arange(n) / sr
        y = sum(a * np.sin(TAU * (h + 1) * f * t) for h, a in enumerate(SOFT_BEEP_HARMONICS))
        return y * envelope(n, sr, SOFT_BEEP_ATTACK, 0.025, tau=length * 1.5)
    return note(style, sr, f, length, style["ping"] * length, release=0.015)


def make_radar(style, name, which):
    sr, n = FRAMES[name]
    buf = np.zeros(n)
    if name in CONTINUOUS_END:
        f1, f2 = style["radar_" + name[-2:]]
        start, end = 0.3497, CONTINUOUS_END[name]
        m = int(round((end - start) * sr))
        t = np.arange(m) / sr
        y = np.sin(TAU * f1 * t) + CONTINUOUS_SECOND_GAIN[name] * np.sin(TAU * f2 * t)
        attack = 0.006
        place(buf, y * envelope(m, sr, attack, 0.012), start - 0.2 * attack, sr)
        return buf
    p = RADAR[name]
    f = style["radar"]
    lead = 0.2 * SOFT_BEEP_ATTACK if which == "a" else 0.0
    if p["first"]:
        place(buf, beep(style, sr, f, p["first"][1], which), p["first"][0] - lead, sr)
    for k in range(p["count"]):
        length = p["last"] if k == p["count"] - 1 else p["length"]
        place(buf, beep(style, sr, f, length, which), p["t0"] + k * p["period"] - lead, sr)
    return buf


# ----------------------------------------------------------------- output
def write_wav(path, left, right, sr):
    pcm = np.empty((len(left), 2), dtype="<i2")
    pcm[:, 0] = np.rint(left * 32767.0)
    pcm[:, 1] = np.rint(right * 32767.0)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def render(name, which):
    style = STYLES[which]
    if name.startswith("direct"):
        mono = make_direct(style, name)
    elif name == "door":
        mono = make_door(style)
    elif name == "breaker":
        mono = make_breaker(style)
    elif name == "ding":
        mono = make_ding(style)
    elif name == "buzzer":
        mono = make_buzzer(style)
    elif name.startswith("seatbelt"):
        mono = make_seatbelt(style, name)
    else:
        mono = make_radar(style, name, which)
    mask = active_mask(mono, FRAMES[name][0])
    rms = np.sqrt((mono[mask] ** 2).mean())
    gain = min(10.0 ** (STOCK_RMS_DB[name] / 20.0) / rms,
               10.0 ** (PEAK_CAP_DB / 20.0) / np.abs(mono).max())
    mono = mono * gain
    right_gain = RADAR_RIGHT_GAIN if name.startswith("radar") else 1.0
    return mono, mono * right_gain


def preview(left, right, sr):
    """First seconds of a radar loop, faded out so the excerpt ends without a click."""
    m = PREVIEW_SECONDS * sr
    nf = int(PREVIEW_FADE * sr)
    fade = np.ones(m)
    fade[-nf:] = 0.5 * (1.0 + np.cos(np.pi * np.arange(1, nf + 1) / nf))
    return left[:m] * fade, right[:m] * fade


def main():
    for which in ("a", "b"):
        for name, (sr, n) in FRAMES.items():
            left, right = render(name, which)
            assert len(left) == n
            write_wav(os.path.join(HERE, which, name + ".wav"), left, right, sr)
            if name.startswith("radar"):
                pl, pr = preview(left, right, sr)
                write_wav(os.path.join(HERE, which, "preview", name + ".wav"), pl, pr, sr)
    print("wrote sets a and b")


if __name__ == "__main__":
    main()
