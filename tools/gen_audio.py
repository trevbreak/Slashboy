#!/usr/bin/env python3
"""Offline port of Slashboy's procedural WebAudio synth. Renders every SFX (with variants),
ambience beds (seamless loops) and the combat music loop to WAV in godot/assets/audio.
Reverb is NOT baked in: Godot applies room reverb per zone at runtime.
Run:  tools/.venv/bin/python tools/gen_audio.py
"""
import math
import os
import random
import wave

import numpy as np
from scipy.signal import lfilter

OUT = os.path.join(os.path.dirname(__file__), '..', 'godot', 'assets', 'audio')
os.makedirs(OUT, exist_ok=True)
SR = 44100
rng = np.random.default_rng(1)


# ------------------------------------------------------------------ primitives
def n_samples(d):
    return max(1, int(d * SR))


def env(n, peak, attack, curve='exp'):
    t = np.arange(n) / SR
    a = max(attack, 1e-4)
    dur = n / SR
    out = np.empty(n)
    rise = t < a
    out[rise] = t[rise] / a * peak
    k = (t[~rise] - a) / max(1e-4, dur - a)
    out[~rise] = peak * (0.0001 / peak) ** k if curve == 'exp' else peak * (1 - k)
    return out


def sweep(f0, f1, n):
    if f1 is None or f1 == f0:
        return np.full(n, float(f0))
    return f0 * (f1 / f0) ** (np.arange(n) / max(1, n - 1))


def osc(kind, freq):
    ph = np.cumsum(freq / SR)
    p = ph % 1.0
    if kind == 'sine':
        return np.sin(2 * np.pi * ph)
    if kind == 'square':
        return np.where(p < 0.5, 1.0, -1.0) * 0.7
    if kind == 'sawtooth':
        return (2 * p - 1) * 0.8
    if kind == 'triangle':
        return (4 * np.abs(p - 0.5) - 1)
    raise ValueError(kind)


def biquad(kind, f, Q):
    f = min(max(f, 10.0), SR * 0.45)
    w = 2 * math.pi * f / SR
    cs, sn = math.cos(w), math.sin(w)
    alpha = sn / (2 * Q)
    if kind == 'lowpass':
        b = [(1 - cs) / 2, 1 - cs, (1 - cs) / 2]
    elif kind == 'highpass':
        b = [(1 + cs) / 2, -(1 + cs), (1 + cs) / 2]
    else:  # bandpass (constant 0 dB peak)
        b = [alpha, 0, -alpha]
    a = [1 + alpha, -2 * cs, 1 - alpha]
    return np.array(b) / a[0], np.array(a) / a[0]


def filt(x, kind, f0, f1=None, Q=1.0):
    """Biquad with an exponential cutoff sweep, processed in blocks."""
    fs = sweep(f0, f1, len(x))
    out = np.zeros_like(x)
    zi = np.zeros(2)
    B = 128
    for i in range(0, len(x), B):
        b, a = biquad(kind, fs[i], Q)
        out[i:i + B], zi = lfilter(b, a, x[i:i + B], zi=zi)
    return out


def white(n):
    return rng.uniform(-1, 1, n)


def brown(n):
    w = rng.uniform(-1, 1, n) * 0.02
    out = lfilter([1], [1, -0.98], w)
    return out / (np.max(np.abs(out)) + 1e-9) * 0.9


def tone(freq=440, dur=0.3, kind='sine', freq_end=None, gain=0.3, attack=0.005, delay=0.0,
         flt=None, f_freq=2000, f_end=None, Q=1.0, detune=0.0):
    n = n_samples(dur)
    f = sweep(freq, freq_end, n) * (2 ** (detune / 1200))
    x = osc(kind, f)
    if flt:
        x = filt(x, flt, f_freq, f_end, Q)
    return delay, x * env(n, gain, attack)


def noise(dur=0.3, gain=0.3, attack=0.005, delay=0.0, flt='bandpass', freq=1000, freq_end=None, Q=1.0, is_brown=False):
    n = n_samples(dur)
    x = brown(n) if is_brown else white(n)
    x = filt(x, flt, freq, freq_end, Q)
    return delay, x * env(n, gain, attack)


def mix(*parts, tail=0.05):
    end = max(d + len(x) / SR for d, x in parts) + tail
    out = np.zeros(n_samples(end))
    for d, x in parts:
        i = int(d * SR)
        out[i:i + len(x)] += x
    return out


def save(name, x, peak=0.89, sr=SR, normalize=False):
    x = np.asarray(x, dtype=np.float64)
    if normalize:
        m = np.max(np.abs(x)) + 1e-9
        x = x / m * peak
    else:
        # keep the synth's relative loudness between sounds; gentle soft clip
        x = np.tanh(x * 2.2)
    # 5 ms fade-out to avoid clicks
    f = min(len(x), int(0.005 * sr))
    x[-f:] *= np.linspace(1, 0, f)
    data = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(data.tobytes())


def save_loop(name, render, length, fade=1.5):
    """Render length+fade seconds and fold the tail over the head for a seamless loop."""
    x = render(length + fade)
    n, fn = n_samples(length), n_samples(fade)
    head, tail = x[:fn].copy(), x[n:n + fn]
    w = np.linspace(0, 1, fn)
    x[:fn] = head * w + tail * (1 - w)
    save(name, x[:n], peak=0.8, normalize=True)


R = random.Random(7)


def r(a=0.0, b=1.0):
    return a + (b - a) * R.random()


# ------------------------------------------------------------------ SFX (ported from audio.js)
def variants(name, fn, k=3):
    for i in range(k):
        save(f'{name}_{i}', fn(i))


def creak(i):
    f = r(90, 210)
    return mix(tone(f, r(1.2, 2.2), 'sawtooth', f * r(0.7, 1.3), 0.06, 0.3, flt='bandpass', f_freq=700, Q=12))


def clank(i, gain=0.4):
    parts = [tone(fr * r(0.95, 1.05), r(0.9, 1.5), 'sine', None, gain * 0.25) for fr in (420, 1130, 2380, 3120)]
    parts.append(noise(0.06, gain * 0.8, freq=2500, Q=0.8))
    return mix(*parts)


def drip(i):
    f = r(900, 1800)
    return mix(tone(f, 0.12, 'sine', f * 2.2, 0.12))


def vent_rumble(i):
    return mix(noise(2.5, 0.15, 0.8, flt='lowpass', freq=220, is_brown=True))


def distant_boom(i):
    return mix(noise(4, 0.35, 0.05, flt='lowpass', freq=160, freq_end=40, is_brown=True), tone(48, 3, 'sine', 30, 0.18))


def buzz(i):
    d = [0.4, 0.15, 0.7][i]
    return mix(tone(120, d, 'sawtooth', None, 0.04, 0.01, flt='bandpass', f_freq=2400, Q=2), noise(d * 0.5, 0.04, freq=5000))


def sparks(i):
    return mix(*[noise(0.04, 0.15, delay=k * 0.03 + r(0, 0.02), freq=r(5000, 8000), Q=2) for k in range(6)])


def whisper(i):
    return mix(*[noise(r(0.5, 0.9), 0.05, 0.15, delay=k * 0.35 + r(0, 0.2), freq=r(1800, 3400), freq_end=r(900, 1700), Q=6) for k in range(3)])


def breath(i):
    return mix(*[noise(1.2, 0.07, 0.5, delay=k * 1.6, freq=600, freq_end=380, Q=3) for k in range(2)])


def taps(i):
    n = 3 + R.randrange(4)
    t, parts = 0, []
    for k in range(n):
        parts.append(noise(0.05, 0.18, delay=t, freq=1600, Q=6))
        t += r(0.15, 0.4)
    return mix(*parts)


def skitter(i, dur=0.8):
    m = int(dur * 28)
    return mix(*[noise(0.025, r(0.5, 1), delay=k / 28 + r(0, 0.015), freq=r(2500, 5000), Q=4) for k in range(m)])


def skitter_run(i):
    m = int(1.3 * 30)
    parts = []
    for k in range(m):
        parts.append(noise(0.03, r(0.6, 1), delay=k / 30 + r(0, 0.012), freq=r(1800, 4800), Q=3))
        if k % 6 == 0:
            parts.append(noise(0.06, 0.6, delay=k / 30, flt='lowpass', freq=400))
    return mix(*parts)


def vent_bang(i):
    return mix(noise(0.5, 0.9, flt='lowpass', freq=600, freq_end=80), tone(140, 0.4, 'square', 60, 0.25, flt='lowpass', f_freq=500), (0, clank(0, 0.6)))


def grate_fall(i):
    return mix((0, vent_bang(0)), (0.0, clank(1, 0.7)), (0.45, clank(2, 0.5)), (0.7, clank(0, 0.25)))


def whale(i):
    return mix(tone(70, 5, 'sawtooth', 52, 0.08, 1.8, flt='lowpass', f_freq=300, Q=6), tone(140, 4, 'triangle', 110, 0.03, 2, delay=0.5))


def leviathan_horn(i):
    return mix(tone(38, 9, 'sawtooth', 34, 0.25, 3, flt='lowpass', f_freq=220, Q=4),
               tone(57, 8, 'sawtooth', 51, 0.12, 3.5, delay=0.6, flt='lowpass', f_freq=300),
               noise(10, 0.15, 4, flt='lowpass', freq=90, is_brown=True))


CHIMES = [587.3, 698.5, 880, 1174.7, 1396.9]
PAD = [73.4, 87.3, 98, 110, 116.5, 146.8, 174.6, 196, 220, 233.1, 293.7]


def chime(i):
    b = CHIMES[i]
    return mix(tone(b, 4, 'sine', None, 0.04, 0.01), tone(b * 2.76, 2, 'sine', None, 0.012, 0.01))


def pad(i):
    n = PAD[i]
    d = 9
    return mix(tone(n, d, 'triangle', None, 0.045, 2.5, flt='lowpass', f_freq=900), tone(n * 1.5, d * 0.8, 'sine', None, 0.02, 3, delay=0.8, detune=7))


def door_open(i):
    return mix(noise(0.9, 0.35, 0.02, flt='highpass', freq=3000, freq_end=1200), tone(90, 0.7, 'sawtooth', 140, 0.12, flt='lowpass', f_freq=400),
               tone(880, 0.15, 'sine', None, 0.08), tone(1320, 0.2, 'sine', None, 0.08, delay=0.09), noise(0.25, 0.4, delay=0.75, flt='lowpass', freq=300))


def door_close(i):
    return mix(noise(0.6, 0.25, flt='highpass', freq=2000, freq_end=900), noise(0.35, 0.55, delay=0.5, flt='lowpass', freq=250))


def door_slam(i):
    return mix(noise(0.6, 0.9, flt='lowpass', freq=400, freq_end=60), tone(70, 0.6, 'square', 40, 0.3, flt='lowpass', f_freq=300),
               tone(220, 0.25, 'square', None, 0.08, delay=0.3, flt='lowpass', f_freq=1200), tone(165, 0.35, 'square', None, 0.08, delay=0.55, flt='lowpass', f_freq=1200))


def denied(i):
    return mix(tone(180, 0.18, 'square', None, 0.08, flt='lowpass', f_freq=1200), tone(140, 0.25, 'square', None, 0.08, delay=0.16, flt='lowpass', f_freq=1200))


def unlock(i):
    return mix(*[tone(f, 0.4, 'sine', None, 0.08, delay=k * 0.08) for k, f in enumerate([660, 990, 1320])])


def lights_out(i):
    return mix(tone(120, 1.6, 'sawtooth', 30, 0.2, flt='lowpass', f_freq=800, f_end=60), noise(0.15, 0.4, freq=3000, Q=0.5),
               noise(1.2, 0.25, delay=0.05, flt='lowpass', freq=200, is_brown=True))


def lights_on(i):
    return mix(*[(k * 0.12 + r(0, 0.05), buzz(R.randrange(3))) for k in range(4)], tone(40, 1.2, 'sawtooth', 120, 0.08, flt='lowpass', f_freq=400))


def alarm(i):
    return mix(*[tone(520, 0.7, 'sawtooth', 380, 0.06, delay=k * 1.1, flt='lowpass', f_freq=1800) for k in range(3)])


def stinger(kind):
    if kind == 'encounter':
        p = [tone(f, 3.5, 'sawtooth', None, 0.07, 0.04, flt='lowpass', f_freq=2400, f_end=300) for f in (73.4, 77.8, 110, 155.6, 233.1)]
        p += [noise(1.4, 0.5, flt='lowpass', freq=200, freq_end=40, is_brown=True), tone(55, 1.5, 'sine', 30, 0.4)]
    elif kind == 'scare':
        p = [tone(f, 1.6, 'sawtooth', None, 0.025, 0.02, flt='bandpass', f_freq=f, Q=3) for f in (1244, 1318, 1396, 1480)]
        p += [noise(0.8, 0.3, flt='lowpass', freq=150, is_brown=True)]
    elif kind == 'clear':
        p = [tone(f, 5, 'triangle', None, 0.05, 0.6, delay=k * 0.25) for k, f in enumerate([293.7, 349.2, 440, 587.3])]
    else:
        p = [tone(f, 3, 'sine', None, 0.045, 0.05, delay=k * 0.12) for k, f in enumerate([440, 554.4, 659.3, 880])]
    return mix(*p)


# player
def swing(i):
    f0 = [3800, 3200, 2600, 2000][i]
    return mix(noise(0.22, 0.32, 0.03, freq=f0 * 0.5, freq_end=f0 * 1.6, Q=1.6), tone(900 + i * 120, 0.18, 'sine', 300, 0.04))


def slash_hit(i, heavy=False):
    return mix(noise(0.18, 0.55, freq=1200, freq_end=300, Q=0.9), tone(90 if heavy else 130, 0.25, 'sine', 40, 0.6 if heavy else 0.4),
               tone(r(2400, 2800), 0.3, 'triangle', None, 0.06))


def clang(i):
    return mix(*[tone(f * r(0.97, 1.03), 0.6, 'sine', None, 0.09) for f in (1800, 2650, 4200)], noise(0.05, 0.5, freq=4000))


def deflect(i):
    return mix(tone(2000, 0.35, 'sine', 5200, 0.18), tone(3000, 0.9, 'triangle', None, 0.08), (0, clang(i)))


def dash(i):
    return mix(noise(0.35, 0.45, 0.02, freq=600, freq_end=3500, Q=1.2), tone(200, 0.25, 'sine', 900, 0.08))


def charge(i):
    n = n_samples(1.6)
    f = np.concatenate([sweep(110, 440, n_samples(0.9)), np.full(n - n_samples(0.9), 440.0)])
    f2 = f * 6
    x = osc('sawtooth', f) + osc('sine', f2) * 0.6
    x = filt(x, 'lowpass', 400, 3000)
    e = np.minimum(1, np.arange(n) / n_samples(0.4)) * 0.07
    vib = 1 + 0.15 * np.sin(np.arange(n) / SR * 2 * np.pi * 9) * (np.arange(n) > n_samples(0.9))
    return x * e * vib


def wave_release(i):
    return mix(noise(0.6, 0.6, freq=400, freq_end=5000, Q=0.8), tone(220, 0.6, 'sawtooth', 55, 0.2, flt='lowpass', f_freq=1500))


def hurt(i):
    return mix(tone(90, 0.35, 'sine', 45, 0.6), noise(0.4, 0.35, freq=1800, Q=0.4), tone(340, 0.25, 'square', 120, 0.05, flt='lowpass', f_freq=900))


def footstep(i):
    f = r(140, 200)
    return mix(noise(0.09, 0.07, flt='lowpass', freq=r(500, 700)), tone(f, 0.08, 'sine', f * 0.6, 0.05), noise(0.03, 0.025, flt='highpass', freq=4000))


def land(i):
    return mix(noise(0.18, 0.3, flt='lowpass', freq=380), tone(80, 0.2, 'sine', 40, 0.25))


def jump(i):
    return mix(noise(0.12, 0.06, freq=900, freq_end=1600))


def scan_beep(i):
    return mix(tone(1200 + i * 120, 0.05, 'square', None, 0.03, flt='lowpass', f_freq=3000))


def scan_done(i):
    return mix(*[tone(f, 0.3, 'sine', None, 0.07, delay=k * 0.07) for k, f in enumerate([1046.5, 1318.5, 1568])])


def visor(i):
    on = i == 0
    return mix(tone(600 if on else 900, 0.15, 'sine', 900 if on else 600, 0.07), noise(0.08, 0.05, freq=4000))


def pickup(i):
    return mix(tone(880 * (1 + i * 0.12), 0.15, 'sine', 1760 * (1 + i * 0.12), 0.07))


def focus(i):
    if i == 0:
        return mix(tone(400, 0.8, 'sine', 80, 0.25), noise(0.8, 0.25, freq=3000, freq_end=200, Q=1))
    return mix(tone(80, 0.5, 'sine', 400, 0.2))


def heartbeat(i):
    return mix(tone(55, 0.18, 'sine', 35, 0.4), tone(50, 0.2, 'sine', 32, 0.28, delay=0.22))


def lock(i):
    return mix(tone(1400, 0.08, 'sine', 1800, 0.06)) if i == 0 else mix(tone(400, 0.06, 'square', None, 0.03, flt='lowpass', f_freq=1200))


def threat_ping(i):
    return mix(tone(700 + i * 250, 0.08, 'sine', None, 0.05))


# enemies
def crawler_hiss(i):
    return mix(noise(0.7, 0.35, 0.05, freq=r(3200, 3800), freq_end=2200, Q=2), tone(300, 0.5, 'sawtooth', 180, 0.05, flt='bandpass', f_freq=1200, Q=4))


def crawler_screech(i):
    b = r(1300, 1500)
    return mix(tone(b, 0.45, 'sawtooth', b / 2, 0.12, flt='bandpass', f_freq=1800, Q=3), tone(b * 1.04, 0.45, 'sawtooth', b * 0.54, 0.1, flt='bandpass', f_freq=2400, Q=3),
               noise(0.4, 0.2, freq=3000))


def crawler_die(i):
    return mix(tone(900, 0.6, 'sawtooth', 120, 0.12, flt='bandpass', f_freq=1500, Q=2), noise(0.5, 0.35, flt='lowpass', freq=900, freq_end=100), (0, skitter(0, 0.3) * 0.2))


def sentinel_boot(i):
    return mix(tone(60, 1.5, 'sawtooth', 240, 0.12, flt='lowpass', f_freq=300, f_end=2000),
               *[tone(f, 0.12, 'square', None, 0.04, delay=1 + k * 0.1, flt='lowpass', f_freq=2000) for k, f in enumerate([523, 659, 784])])


def sentinel_charge(i):
    return mix(tone(300, 0.9, 'sine', 1800, 0.12, 0.3), tone(310, 0.9, 'sawtooth', 1850, 0.03, 0.3, flt='lowpass', f_freq=2000))


def sentinel_shot(i):
    return mix(tone(1600, 0.3, 'sawtooth', 200, 0.15, flt='lowpass', f_freq=4000), noise(0.15, 0.3, freq=2000, freq_end=500))


def sentinel_hum(length):
    n = n_samples(length)
    t = np.arange(n) / SR
    x = osc('sawtooth', np.full(n, 95.0)) + 0.5 * osc('sawtooth', np.full(n, 95.0 * 1.005))
    x = filt(x, 'lowpass', 400) * (0.8 + 0.2 * np.sin(2 * np.pi * 3 * t))
    return x * 0.3


def sentinel_die(i):
    return mix(tone(800, 1.2, 'sawtooth', 50, 0.15, flt='lowpass', f_freq=3000, f_end=200), (0, sparks(0)))


def explosion(i):
    return mix(noise(1.5, 0.8, flt='lowpass', freq=1200, freq_end=60), tone(70, 1, 'sine', 25, 0.6))


def stalker_shriek(i):
    p = [tone(f, 0.9, 'sawtooth', f * 1.6, 0.07, 0.08, delay=d, flt='bandpass', f_freq=f * 2, Q=2) for f, d in [(620, 0), (930, 0.02), (1240, 0.04), (455, 0)]]
    p.append(noise(0.9, 0.3, 0.08, freq=2500, freq_end=5000, Q=1))
    return mix(*p)


def stalker_whoosh(i):
    return mix(noise(0.5, 0.3, 0.1, freq=300, freq_end=1600, Q=2), tone(200, 0.4, 'sine', 600, 0.05))


def stalker_step(i):
    return mix(noise(0.12, 0.12, flt='lowpass', freq=300), tone(3000, 0.05, 'sine', None, 0.015))


def stalker_die(i):
    return mix((0, stalker_shriek(0)), tone(400, 3, 'sawtooth', 40, 0.15, flt='lowpass', f_freq=2000, f_end=100), (0, explosion(0)))


def cloak(i):
    return mix(tone(2200, 0.6, 'sine', 1400, 0.03, 0.2))


def fizzle(i):
    return mix(tone(400, 0.15, 'sawtooth', 100, 0.05, flt='lowpass', f_freq=1500))


# ------------------------------------------------------------------ ambience beds (seamless loops)
ZONES = {
    'bay': (55, 0.10, 0.05, 0.0, 0.025), 'corridor': (49, 0.12, 0.03, 0.0, 0.05), 'atrium': (41, 0.09, 0.035, 0.10, 0.0),
    'funnel': (46, 0.17, 0.02, 0.02, 0.02), 'arena': (43, 0.10, 0.04, 0.0, 0.03), 'final': (52, 0.08, 0.03, 0.04, 0.0),
}


def bed(df, drone, air, wind, hum):
    def render(length):
        n = n_samples(length)
        t = np.arange(n) / SR
        x = np.zeros(n)
        # drone: detuned saws through a slowly breathing lowpass
        d = np.zeros(n)
        for mul, kind, det in [(1, 'sawtooth', -6), (1.498, 'sawtooth', 5), (0.5, 'sine', 0), (2.01, 'triangle', 0)]:
            d += osc(kind, np.full(n, df * mul * 2 ** (det / 1200)))
        cut = 260 + 120 * np.sin(2 * np.pi * 0.07 * t)
        out = np.zeros(n); zi = np.zeros(2)
        for i in range(0, n, 256):
            b, a = biquad('lowpass', cut[i], 3)
            out[i:i + 256], zi = lfilter(b, a, d[i:i + 256], zi=zi)
        x += out * drone * 0.5
        if air:
            x += filt(white(n), 'bandpass', 520, None, 0.6) * air * 1.4
        if wind:
            w = brown(n)
            wc = 400 + 260 * np.sin(2 * np.pi * 0.11 * t)
            o = np.zeros(n); zi = np.zeros(2)
            for i in range(0, n, 256):
                b, a = biquad('bandpass', wc[i], 4)
                o[i:i + 256], zi = lfilter(b, a, w[i:i + 256], zi=zi)
            x += o * wind * 6
        if hum:
            x += filt(osc('sawtooth', np.full(n, 60.0)), 'lowpass', 200) * hum
        return x
    return render


def tension(length):
    n = n_samples(length)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for f in (1244.5, 1318.5, 932.3):
        vib = 1 + 0.0023 * np.sin(2 * np.pi * r(0.3, 0.7) * t)
        x += osc('sine', f * vib)
    return x * (0.6 + 0.4 * np.sin(2 * np.pi * 5.5 * t))


# ------------------------------------------------------------------ combat music
def combat_loop():
    bpm = 132
    spb = 60 / bpm / 4
    steps = 64
    n = n_samples(steps * spb + 2.0)
    out = np.zeros(n)

    def put(t, x):
        i = int(t * SR); out[i:i + len(x)] += x[:max(0, n - i)]
    bass = [36.7, 0, 36.7, 0, 38.9, 0, 36.7, 36.7, 0, 36.7, 43.65, 0, 36.7, 0, 32.7, 34.6]
    arp = [587.3, 622.3, 880, 587.3, 698.5, 622.3, 880, 1174.7]
    for s in range(steps):
        t = s * spb
        st, bar = s % 16, s // 16
        shift = [1, 1, 1.189, 0.944][bar]
        if st in (0, 6, 8, 11, 14) or (bar == 3 and st >= 12):
            m = n_samples(0.4)
            f = sweep(120 if st == 0 else 95, 42, n_samples(0.25))
            f = np.concatenate([f, np.full(m - len(f), 42.0)])
            put(t, osc('sine', f) * env(m, 0.7 if st == 0 else 0.45, 0.002))
        if st % 2 == 1:
            m = n_samples(0.06)
            put(t, filt(white(m), 'highpass', 7000) * env(m, 0.06 if st % 4 == 3 else 0.03, 0.001))
        if st in (4, 12):
            m = n_samples(0.2)
            put(t, filt(white(m), 'bandpass', 1800, None, 0.8) * env(m, 0.25, 0.001))
        if bass[st]:
            m = n_samples(0.2)
            x = filt(osc('sawtooth', np.full(m, bass[st] * 2 * shift)), 'lowpass', 1400, 120, 8)
            put(t, x * env(m, 0.22, 0.002))
        if st == 0 and bar % 2 == 0:
            m = n_samples(1.6)
            x = sum(osc('sawtooth', np.full(m, f * shift)) for f in (146.8, 155.6, 220, 311.1))
            put(t, filt(x, 'lowpass', 3000, 300) * env(m, 0.04, 0.02))
        if bar >= 2 and st % 2 == 0:
            m = n_samples(0.15)
            put(t, filt(osc('square', np.full(m, arp[(st // 2) % 8] * shift)), 'lowpass', 2200) * env(m, 0.025, 0.001))
    L = n_samples(steps * spb)
    tail = out[L:L + n_samples(2.0)]
    out[:len(tail)] += tail  # wrap ringing tails into the head
    save('music_combat', out[:L], peak=0.85, normalize=True)



# ------------------------------------------------------------------ sectors 2-5
def rain_bed(length):
    n = n_samples(length)
    x = filt(white(n), 'highpass', 1800) * 0.25 + filt(white(n), 'bandpass', 600, None, 0.5) * 0.2
    t = np.arange(n) / SR
    drops = np.zeros(n)
    for i in rng.integers(0, n - 2000, int(length * 60)):
        d = int(rng.integers(200, 900))
        drops[i:i + d] += np.exp(-np.arange(d) / (d / 5)) * rng.uniform(0.05, 0.3) * np.sin(np.arange(d) * rng.uniform(0.2, 0.6))
    return x * (0.85 + 0.15 * np.sin(2 * np.pi * 0.07 * t)) + drops


def undercity_bed(length):
    n = n_samples(length)
    t = np.arange(n) / SR
    hum = filt(osc('sawtooth', np.full(n, 41.0)) + osc('sawtooth', np.full(n, 61.6)), 'lowpass', 160) * 0.18
    rumble = filt(brown(n), 'lowpass', 90) * 0.5
    siren = np.zeros(n)
    for k in range(2):
        start = int(rng.uniform(0.1, 0.7) * n); dur = n_samples(6)
        f = 600 + 180 * np.sin(2 * np.pi * 0.7 * np.arange(dur) / SR)
        seg = filt(osc('sine', f), 'bandpass', 700, None, 1) * np.sin(np.linspace(0, np.pi, dur)) * 0.04
        siren[start:start + dur] += seg[:max(0, n - start)]
    return rain_bed(length) * 0.6 + hum + rumble + siren


def foundry_bed(length):
    n = n_samples(length)
    t = np.arange(n) / SR
    rumble = filt(brown(n), 'lowpass', 120) * 0.8
    roar = filt(white(n), 'bandpass', 300, None, 0.4) * 0.12 * (0.7 + 0.3 * np.sin(2 * np.pi * 0.13 * t))
    hum = filt(osc('sawtooth', np.full(n, 50.0)), 'lowpass', 220) * 0.2
    clanks = np.zeros(n)
    beat = n_samples(1.6)
    for i in range(0, n - beat, beat):
        c = clank(0, 0.5)[:beat] * 0.25
        clanks[i:i + len(c)] += c
    return rumble + roar + hum + clanks


def archives_bed(length):
    n = n_samples(length)
    t = np.arange(n) / SR
    wind = brown(n)
    wc = 700 + 400 * np.sin(2 * np.pi * 0.09 * t)
    o = np.zeros(n); zi = np.zeros(2)
    for i in range(0, n, 256):
        b, a = biquad('bandpass', wc[i], 5)
        o[i:i + 256], zi = lfilter(b, a, wind[i:i + 256], zi=zi)
    choir = np.zeros(n)
    for f in (146.8, 220.0, 293.7, 349.2):
        vib = 1 + 0.003 * np.sin(2 * np.pi * r(4, 6) * t)
        choir += filt(osc('sawtooth', f * vib), 'bandpass', f * 3, None, 3) * (0.5 + 0.5 * np.sin(2 * np.pi * r(0.03, 0.08) * t + r(0, 6)))
    return o * 3.0 + choir * 0.12


def heart_bed(length):
    n = n_samples(length)
    t = np.arange(n) / SR
    drone = filt(osc('sawtooth', np.full(n, 36.7)) + osc('sawtooth', np.full(n, 55.0 * 1.003)), 'lowpass', 140, None, 4) * 0.3
    wet = filt(brown(n), 'bandpass', 220, None, 2) * 0.6 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.3 * t))
    beats = np.zeros(n)
    period = n_samples(1.15)
    for i in range(0, n - period, period):
        b = mix(tone(48, 0.25, 'sine', 30, 0.9), tone(44, 0.28, 'sine', 28, 0.6, delay=0.28))
        beats[i:i + len(b)] += b[:max(0, n - i)]
    return drone + wet + beats * 0.8


def music_boss():
    bpm = 148
    spb = 60 / bpm / 4
    steps = 64
    n = n_samples(steps * spb + 2.0)
    out = np.zeros(n)

    def put(t, x):
        i = int(t * SR); out[i:i + len(x)] += x[:max(0, n - i)]
    bass = [36.7, 36.7, 0, 36.7, 43.65, 0, 38.9, 0, 36.7, 36.7, 0, 32.7, 34.6, 0, 38.9, 41.2]
    for s_ in range(steps):
        t = s_ * spb; st, bar = s_ % 16, s_ // 16
        shift = [1, 0.944, 1.189, 1.0][bar]
        if st % 4 == 0 or st in (3, 10):
            m = n_samples(0.35)
            f = np.concatenate([sweep(140, 40, n_samples(0.2)), np.full(m - n_samples(0.2), 40.0)])
            put(t, osc('sine', f) * env(m, 0.8, 0.002))
        if st in (4, 12):
            m = n_samples(0.25)
            put(t, (filt(white(m), 'bandpass', 2200, None, 0.7) + filt(white(m), 'lowpass', 300)) * env(m, 0.35, 0.001))
        if st % 2 == 1:
            m = n_samples(0.05)
            put(t, filt(white(m), 'highpass', 8000) * env(m, 0.07, 0.001))
        if bass[st]:
            m = n_samples(0.18)
            put(t, filt(osc('sawtooth', np.full(m, bass[st] * 2 * shift)) + osc('square', np.full(m, bass[st] * shift)) * 0.5, 'lowpass', 1800, 150, 9) * env(m, 0.24, 0.002))
        if st == 0:
            m = n_samples(3.2)
            x = sum(osc('sawtooth', np.full(m, f * shift)) for f in (146.8, 174.6, 207.7, 293.7))
            put(t, filt(x, 'lowpass', 2600, 500) * env(m, 0.035, 0.05))
        if st % 2 == 0 and bar >= 1:
            arp = [587.3, 698.5, 830.6, 587.3, 1174.7, 830.6, 698.5, 1046.5]
            m = n_samples(0.12)
            put(t, filt(osc('square', np.full(m, arp[(st // 2) % 8] * shift)), 'lowpass', 2600) * env(m, 0.03, 0.001))
    L_ = n_samples(steps * spb)
    out[:n - L_] += out[L_:]
    save('music_boss', out[:L_], peak=0.85, normalize=True)


def music_escape():
    bpm = 168
    spb = 60 / bpm / 4
    steps = 64
    n = n_samples(steps * spb + 2.0)
    out = np.zeros(n)

    def put(t, x):
        i = int(t * SR); out[i:i + len(x)] += x[:max(0, n - i)]
    for s_ in range(steps):
        t = s_ * spb; st, bar = s_ % 16, s_ // 16
        if st % 2 == 0:
            m = n_samples(0.25)
            f = np.concatenate([sweep(150, 45, n_samples(0.15)), np.full(m - n_samples(0.15), 45.0)])
            put(t, osc('sine', f) * env(m, 0.7, 0.002))
        if st % 4 == 2:
            m = n_samples(0.2)
            put(t, filt(white(m), 'bandpass', 1900, None, 0.8) * env(m, 0.3, 0.001))
        m = n_samples(0.11)
        f = [73.4, 73.4, 87.3, 73.4, 98.0, 73.4, 87.3, 110.0][st % 8] * (1.0 if bar < 2 else 1.122)
        put(t, filt(osc('sawtooth', np.full(m, f * 2)), 'lowpass', 2000, 200, 8) * env(m, 0.2, 0.002))
        if st % 8 == 0:
            m = n_samples(0.9)
            put(t, tone(880, 0.9, 'sawtooth', 660, 0.03, flt='lowpass', f_freq=2500)[1])
    L_ = n_samples(steps * spb)
    out[:n - L_] += out[L_:]
    save('music_escape', out[:L_], peak=0.85, normalize=True)


def grapple_fire(i):
    return mix(noise(0.25, 0.5, 0.005, freq=2500, freq_end=600, Q=1.5), tone(1800, 0.2, 'triangle', 600, 0.06),
               *[noise(0.03, 0.2, delay=0.05 + k * 0.035, freq=4000, Q=3) for k in range(5)])


def phase_step(i):
    return mix(tone(300, 0.4, 'sine', 1400, 0.15), tone(310, 0.4, 'sawtooth', 1450, 0.04, flt='lowpass', f_freq=3000),
               noise(0.4, 0.3, 0.02, freq=500, freq_end=6000, Q=2))


def leap(i):
    return mix(noise(0.25, 0.35, 0.01, freq=400, freq_end=2400, Q=1.2), tone(220, 0.3, 'sine', 660, 0.08))


def lava(i):
    return mix(noise(1.2, 0.3, 0.1, flt='lowpass', freq=500, is_brown=True), *[noise(0.05, 0.15, delay=r(0, 1.1), freq=r(1500, 4000), Q=2) for _ in range(10)])


def crusher(i):
    return mix(noise(0.6, 1.0, 0.001, flt='lowpass', freq=900, freq_end=60), tone(55, 0.6, 'sine', 30, 0.9), (0, clank(0, 0.8)))


def hydraulic(i):
    return mix(noise(1.0, 0.25, 0.1, flt='bandpass', freq=1500, freq_end=500, Q=1), tone(70, 1.0, 'sawtooth', 110, 0.08, flt='lowpass', f_freq=300))


def turret_shot(i):
    return mix(tone(2200, 0.18, 'square', 300, 0.1, flt='lowpass', f_freq=5000), noise(0.12, 0.35, freq=3000, freq_end=800))


def shield_hit(i):
    return mix(tone(400, 0.5, 'sine', 380, 0.2), tone(803, 0.4, 'sine', None, 0.08), noise(0.15, 0.3, freq=1200, Q=0.6), (0, clang(i)))


def servo(i):
    f = r(180, 260)
    return mix(tone(f, 0.45, 'sawtooth', f * 1.6, 0.06, 0.05, flt='bandpass', f_freq=1200, Q=3), noise(0.4, 0.06, 0.05, freq=3000, Q=2))


def stomp(i):
    return mix(noise(0.7, 1.0, 0.001, flt='lowpass', freq=400, freq_end=50), tone(45, 0.8, 'sine', 25, 1.0))


def missile(i):
    return mix(noise(0.8, 0.5, 0.01, freq=800, freq_end=3000, Q=1), tone(300, 0.8, 'sawtooth', 120, 0.06, flt='lowpass', f_freq=1500))


def beam_charge(i):
    return mix(tone(80, 1.6, 'sawtooth', 600, 0.2, 0.8, flt='lowpass', f_freq=400, f_end=4000), tone(160, 1.6, 'sine', 1200, 0.1, 0.8))


def beam_fire(i):
    n = n_samples(2.2)
    t = np.arange(n) / SR
    x = filt(osc('sawtooth', 110 + 10 * np.sin(2 * np.pi * 30 * t)) + white(n) * 0.4, 'lowpass', 2500) * env(n, 0.4, 0.02, 'lin')
    return x


def matriarch_roar(i):
    b = r(160, 220)
    return mix(tone(b, 1.6, 'sawtooth', b * 0.5, 0.3, 0.15, flt='bandpass', f_freq=700, Q=2), tone(b * 1.5, 1.4, 'sawtooth', b * 0.7, 0.2, 0.2, flt='bandpass', f_freq=1400, Q=2),
               noise(1.5, 0.5, 0.2, freq=900, freq_end=300, Q=0.8), tone(55, 1.5, 'sine', 35, 0.5, 0.1))


def acid(i):
    return mix(noise(0.6, 0.35, 0.02, freq=3000, freq_end=1200, Q=1.5), tone(600, 0.3, 'sine', 200, 0.05))


def phantom(i):
    return mix(tone(1400, 0.6, 'sine', 400, 0.08, 0.05), tone(1420, 0.6, 'sine', 410, 0.06, 0.05), noise(0.5, 0.12, 0.1, freq=5000, freq_end=1500, Q=3))


def glitch(i):
    return mix(*[tone(r(200, 3000), 0.04, 'square', None, 0.06, delay=k * 0.05, flt='lowpass', f_freq=4000) for k in range(8)], noise(0.4, 0.1, freq=6000, Q=1))


def heart_thump(i):
    return mix(tone(42, 0.5, 'sine', 25, 1.0), tone(38, 0.55, 'sine', 24, 0.7, delay=0.32), noise(0.4, 0.4, flt='lowpass', freq=180, is_brown=True), noise(0.5, 0.3, delay=0.3, flt='lowpass', freq=160, is_brown=True))


def tentacle(i):
    return mix(noise(0.6, 0.9, 0.001, flt='lowpass', freq=600, freq_end=80), tone(70, 0.6, 'sine', 30, 0.6), noise(0.4, 0.25, 0.05, freq=1500, freq_end=400, Q=2))


def spore(i):
    return mix(noise(0.5, 0.5, 0.005, flt='lowpass', freq=1200, freq_end=200), noise(1.2, 0.15, 0.2, freq=4000, freq_end=2000, Q=1.5), tone(200, 0.3, 'sine', 80, 0.2))


def boss_intro(i):
    return mix(*[tone(f, 4.5, 'sawtooth', None, 0.07, 0.02, flt='lowpass', f_freq=3000, f_end=200) for f in (55.0, 58.3, 82.4, 110.0, 116.5)],
               noise(2.5, 0.6, 0.01, flt='lowpass', freq=300, freq_end=30, is_brown=True), tone(40, 3.0, 'sine', 25, 0.8))


def collapse(i):
    return mix(noise(4.0, 0.8, 0.3, flt='lowpass', freq=200, freq_end=40, is_brown=True), *[(r(0, 3), clank(0, 0.6)) for _ in range(5)], tone(35, 4.0, 'sine', 25, 0.6, 0.5))


def escape_alarm(i):
    return mix(*[tone(780, 0.35, 'square', 620, 0.05, delay=k * 0.5, flt='lowpass', f_freq=2200) for k in range(4)])


# ------------------------------------------------------------------ render all
if __name__ == '__main__':
    print('sfx...')
    for name, fn, k in [
        ('creak', creak, 3), ('clank', clank, 3), ('drip', drip, 3), ('vent_rumble', vent_rumble, 2), ('boom', distant_boom, 2),
        ('buzz', buzz, 3), ('sparks', sparks, 3), ('whisper', whisper, 3), ('breath', breath, 2), ('taps', taps, 3),
        ('skitter', skitter, 4), ('skitter_run', skitter_run, 2), ('vent_bang', vent_bang, 2), ('grate_fall', grate_fall, 2),
        ('whale', whale, 2), ('chime', chime, 5), ('pad', pad, len(PAD)), ('door_open', door_open, 2), ('door_close', door_close, 2),
        ('door_slam', door_slam, 1), ('denied', denied, 1), ('unlock', unlock, 1), ('lights_out', lights_out, 1), ('lights_on', lights_on, 1),
        ('alarm', alarm, 1), ('swing', swing, 4), ('slash_hit', slash_hit, 3), ('clang', clang, 3), ('deflect', deflect, 2),
        ('dash', dash, 2), ('wave_release', wave_release, 2), ('hurt', hurt, 3), ('footstep', footstep, 6), ('land', land, 2),
        ('jump', jump, 2), ('scan_beep', scan_beep, 6), ('scan_done', scan_done, 1), ('visor', visor, 2), ('pickup', pickup, 3),
        ('focus', focus, 2), ('heartbeat', heartbeat, 1), ('lock', lock, 2), ('threat_ping', threat_ping, 3),
        ('crawler_hiss', crawler_hiss, 3), ('crawler_screech', crawler_screech, 3), ('crawler_die', crawler_die, 2),
        ('sentinel_boot', sentinel_boot, 1), ('sentinel_charge', sentinel_charge, 1), ('sentinel_shot', sentinel_shot, 3),
        ('sentinel_die', sentinel_die, 2), ('explosion', explosion, 3), ('stalker_shriek', stalker_shriek, 2),
        ('stalker_whoosh', stalker_whoosh, 3), ('stalker_step', stalker_step, 3), ('stalker_die', stalker_die, 1),
        ('cloak', cloak, 2), ('fizzle', fizzle, 2),
    ]:
        variants(name, fn, k)
    save('slash_heavy_0', slash_hit(0, True))
    save('leviathan_horn_0', leviathan_horn(0))
    save('charge_0', charge(0), normalize=True)
    for k in ('encounter', 'scare', 'clear', 'discovery'):
        save(f'stinger_{k}_0', stinger(k))
    print('loops...')
    for z, (df, drone, air, wind, hum) in ZONES.items():
        save_loop(f'amb_{z}', bed(df, drone, air, wind, hum), 24)
    save_loop('tension', tension, 12)
    save_loop('sentinel_hum', sentinel_hum, 2)
    for z, fn in [('undercity', undercity_bed), ('foundry', foundry_bed), ('archives', archives_bed), ('heart', heart_bed)]:
        save_loop(f'amb_{z}', fn, 24)
    for name, fn, k in [('grapple', grapple_fire, 2), ('phase', phase_step, 2), ('leap', leap, 2), ('lava', lava, 2), ('crusher', crusher, 2),
                        ('hydraulic', hydraulic, 2), ('turret_shot', turret_shot, 3), ('shield_hit', shield_hit, 3), ('servo', servo, 3), ('stomp', stomp, 2),
                        ('missile', missile, 2), ('beam_charge', beam_charge, 1), ('beam_fire', beam_fire, 1), ('matriarch_roar', matriarch_roar, 3), ('acid', acid, 3),
                        ('phantom', phantom, 3), ('glitch', glitch, 3), ('heart_thump', heart_thump, 1), ('tentacle', tentacle, 3), ('spore', spore, 2),
                        ('boss_intro', boss_intro, 1), ('collapse', collapse, 2), ('escape_alarm', escape_alarm, 1)]:
        variants(name, fn, k)
    print('music...')
    combat_loop()
    music_boss()
    music_escape()
    print('done')
