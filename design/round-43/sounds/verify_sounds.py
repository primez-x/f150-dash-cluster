#!/usr/bin/env python3
"""Compare the generated sets a and b with the stock sounds and write report.json.

Checks per file: sample rate, channels, sample width, frame count, event onsets
(within 2 ms), peak, active RMS, DC offset, first and last sample, full-scale
samples, and the share of energy in 500-4000 Hz and below 300 Hz.
"""
import glob
import json
import os
import sys
import wave

import numpy as np
from scipy.signal import butter, find_peaks, hilbert, sosfiltfilt

sys.path.insert(0, HERE_DIR := os.path.dirname(os.path.abspath(__file__)))
from make_sounds import active_mask, bursts  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
STOCK = os.path.join(HERE, "..", "..", "..", "installed", "capture-04",
                     "rootfs", "etc", "sound")
TOLERANCE = 0.002
LOUDNESS_TOLERANCE_DB = 1.0


def load(path):
    with wave.open(path, "rb") as w:
        sr, ch, sw, n = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(n)
    x = np.frombuffer(raw, dtype="<i2").reshape(-1, ch)
    return dict(sr=sr, ch=ch, sw=sw, n=n, pcm=x, x=x / 32768.0)


def db(v):
    return float(20.0 * np.log10(max(v, 1e-12)))


def level(x, sr):
    mask = active_mask(x, sr)
    col = x[:, 0]
    return dict(
        peak_dbfs=db(np.abs(x).max()),
        rms_active_dbfs=db(np.sqrt((col[mask] ** 2).mean())) if mask.any() else None,
        active_seconds=float(mask.sum() / sr),
    )


def band_fractions(x, sr):
    m = x[:, 0]
    spec = np.abs(np.fft.rfft(m)) ** 2
    f = np.fft.rfftfreq(len(m), 1.0 / sr)
    tot = spec.sum()
    return dict(frac_500_4000=float(spec[(f >= 500) & (f <= 4000)].sum() / tot),
                frac_below_300=float(spec[f < 300].sum() / tot))


def voice_dips(x, sr, fc):
    """Envelope minima of a narrow band, used for the seatbelt echo trains."""
    m = x.mean(axis=1)
    sos = butter(3, [fc - 35, fc + 35], btype="band", fs=sr, output="sos")
    e = np.abs(hilbert(sosfiltfilt(sos, m)))
    k = int(sr * 0.012)
    e = np.convolve(e, np.ones(k) / k, "same")
    pk, _ = find_peaks(-e, distance=int(sr * 0.1), prominence=0.012 * e.max())
    return [float(p / sr) for p in pk]


def voice_rises(x, sr, fc):
    """Note starts of a band: the last point below 10% of each note peak.

    The band is wider than the stock dip band so the filter smears the rise less.
    """
    m = x.mean(axis=1)
    sos = butter(3, [fc - 150, fc + 150], btype="band", fs=sr, output="sos")
    e = np.abs(hilbert(sosfiltfilt(sos, m)))
    k = int(sr * 0.002)
    e = np.convolve(e, np.ones(k) / k, "same")
    pk, _ = find_peaks(e, distance=int(sr * 0.1), prominence=0.012 * e.max())
    out = []
    for p in pk:
        i = p
        while i > 0 and e[i] > 0.1 * e[p]:
            i -= 1
        out.append(float(i / sr))
    return out


def match(new, ref, tol=TOLERANCE):
    """Match each new time to the nearest reference time. Report the worst error."""
    ref = np.array(ref)
    errs = [float(np.min(np.abs(ref - t))) if len(ref) else None for t in new]
    unmatched = [float(r) for r in ref if len(new) and np.min(np.abs(np.array(new) - r)) > tol]
    return dict(max_err_ms=max(errs) * 1000.0 if errs else None,
                new_count=len(new), ref_count=len(ref),
                new_not_in_ref=[round(t, 4) for t, e in zip(new, errs) if e > tol],
                ref_not_in_new=[round(t, 4) for t in unmatched])


def onsets(x, sr, name):
    if name.startswith("direct"):
        return [a for a, _ in bursts(x, sr, rel=0.05)]
    if name.startswith("radar"):
        return [a for a, _ in bursts(x, sr)]
    return [a for a, _ in bursts(x, sr, rel=0.05, gap_ms=15.0)]


def check(name, which):
    st = load(os.path.join(STOCK, name + ".wav"))
    nw = load(os.path.join(HERE, which, name + ".wav"))
    sr = st["sr"]
    r = dict(
        format_ok=(st["sr"], st["ch"], st["sw"], st["n"]) == (nw["sr"], nw["ch"], nw["sw"], nw["n"]),
        frames=nw["n"], stock_frames=st["n"],
        stock=level(st["x"], sr), new=level(nw["x"], sr),
        new_bands=band_fractions(nw["x"], sr),
        dc_offset=[float(v) for v in nw["x"].mean(axis=0)],
        first_last_zero=bool((nw["pcm"][0] == 0).all() and (nw["pcm"][-1] == 0).all()),
        max_abs_sample=int(np.abs(nw["pcm"].astype(int)).max()),
        full_scale_samples=int((np.abs(nw["pcm"].astype(int)) >= 32767).sum()),
    )
    if name.startswith("seatbelt"):
        centers = {"a": (987.77, 659.26), "b": (1975.5, 1318.5)}[which]
        stock_centers = (987.77, 659.26)
        worst, detail = 0.0, []
        for fs_, fn in zip(stock_centers, centers):
            first = bursts(st["x"], sr, rel=0.05)[0][0]
            ref = [first] + [t for t in voice_dips(st["x"], sr, fs_) if t > 0.2]
            new = voice_rises(nw["x"], sr, fn)
            if name == "seatbelt_quick":
                ref = [t for t in ref if t < 0.6]
                new = [t for t in new if t < 0.6]
            m = match(new, ref)
            detail.append(dict(stock_band_hz=fs_, new_band_hz=fn, **m))
            worst = max(worst, m["max_err_ms"] or 0.0)
        r["onsets"] = dict(kind="stock lobe starts (envelope dips) vs new note starts", max_err_ms=worst, voices=detail)
    else:
        r["onsets"] = dict(kind="burst onsets", **match(onsets(nw["x"], sr, name),
                                                       onsets(st["x"], sr, name)))
    return r


def main():
    names = sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(STOCK, "*.wav")))
    report = {"tolerance_ms": TOLERANCE * 1000.0}
    for which in ("a", "b"):
        report[which] = {n: check(n, which) for n in names}
    report["loudness_tolerance_db"] = LOUDNESS_TOLERANCE_DB
    report["loudness"] = {}
    for n in names:
        row = {"stock_rms_db": round(report["a"][n]["stock"]["rms_active_dbfs"], 2)}
        for which in ("a", "b"):
            rms = report[which][n]["new"]["rms_active_dbfs"]
            row[which + "_rms_db"] = round(rms, 2)
            row[which + "_delta_db"] = round(rms - row["stock_rms_db"], 2)
            row[which + "_peak_db"] = round(report[which][n]["new"]["peak_dbfs"], 2)
        report["loudness"][n] = row
    report["checks"] = {
        which: {
            "format_ok": all(report[which][n]["format_ok"] for n in names),
            "onsets_within_2ms": all((report[which][n]["onsets"]["max_err_ms"] or 0) <= 2.0
                                     for n in names),
            "start_end_zero": all(report[which][n]["first_last_zero"] for n in names),
            "no_full_scale": all(report[which][n]["full_scale_samples"] == 0 for n in names),
            "peak_at_or_below_-0.5": all(report["loudness"][n][which + "_peak_db"] <= -0.499
                                         for n in names),
            "rms_within_1db": all(abs(report["loudness"][n][which + "_delta_db"])
                                  <= LOUDNESS_TOLERANCE_DB for n in names),
        } for which in ("a", "b")
    }
    path = os.path.join(HERE, "report.json")
    with open(path, "w", newline="\n") as f:
        json.dump(report, f, indent=1)
    for which in ("a", "b"):
        for n in names:
            r = report[which][n]
            print(which, n, "fmt", r["format_ok"],
                  "peak %.1f (stock %.1f)" % (r["new"]["peak_dbfs"], r["stock"]["peak_dbfs"]),
                  "rms %.1f (stock %.1f)" % (r["new"]["rms_active_dbfs"], r["stock"]["rms_active_dbfs"]),
                  "onset_err_ms %.2f" % (r["onsets"]["max_err_ms"] or 0),
                  "n %s/%s" % (r["onsets"].get("new_count", "-"), r["onsets"].get("ref_count", "-")),
                  "500-4k %.2f <300 %.3f" % (r["new_bands"]["frac_500_4000"], r["new_bands"]["frac_below_300"]),
                  "z" if r["first_last_zero"] else "NONZERO-END", "fs", r["full_scale_samples"])
    print("file stock_rms a_rms a_delta b_rms b_delta")
    for n, r in report["loudness"].items():
        print("%-15s %7.2f %7.2f %+5.2f %7.2f %+5.2f" % (
            n, r["stock_rms_db"], r["a_rms_db"], r["a_delta_db"], r["b_rms_db"], r["b_delta_db"]))
    print(json.dumps(report["checks"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
