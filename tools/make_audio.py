#!/usr/bin/env python3
"""Synthesize every sound in The Deep Vault (original, CC0 by this project).

Usage: python3 tools/make_audio.py game/assets/audio
Requires numpy. Output: 16-bit mono WAV files at 22050 Hz.
"""
import sys, os, wave
import numpy as np

SR = 22050
rng = np.random.default_rng(7)

def t(sec): return np.arange(int(sec * SR)) / SR
def env(n, a=0.005, d=0.2, curve=4.0):
    x = np.arange(n) / SR
    att = np.clip(x / max(a, 1e-4), 0, 1)
    dec = np.exp(-np.maximum(x - a, 0) * curve / max(d, 1e-4))
    return att * dec
def noise(sec): return rng.uniform(-1, 1, int(sec * SR))
def lowpass(x, cutoff):
    # one-pole low-pass, cutoff may be array
    a = np.exp(-2 * np.pi * np.broadcast_to(cutoff, x.shape) / SR)
    y = np.zeros_like(x); s = 0.0
    for i in range(len(x)):
        s = (1 - a[i]) * x[i] + a[i] * s; y[i] = s
    return y
def highpass(x, cutoff): return x - lowpass(x, cutoff)
def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak
def save(path, x, peak=0.9):
    x = norm(x, peak)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())
def loopify(x, fade=0.25):
    n = int(fade * SR); head = x[:n].copy(); x = x[n:].copy()
    ramp = np.linspace(0, 1, n)
    x[-n:] = x[-n:] * (1 - ramp) + head * ramp
    return x

def swing():
    n = noise(0.28); sw = np.linspace(600, 3800, len(n)) ** 1.0
    x = highpass(lowpass(n, sw), 300) * np.sin(np.linspace(0, np.pi, len(n))) ** 2
    return x
def hit():
    d = 0.32; tt = t(d)
    thud = np.sin(2 * np.pi * (110 * np.exp(-tt * 9)) * tt) * env(len(tt), 0.002, 0.14)
    crunch = lowpass(noise(d), 2400) * env(len(tt), 0.001, 0.06)
    return thud * 0.9 + crunch * 0.7
def bone_break():
    d = 0.5; x = np.zeros(int(d * SR))
    for k in range(7):
        s = int(rng.uniform(0, 0.25) * SR); n = int(0.05 * SR)
        click = highpass(noise(0.05), 1200) * env(n, 0.001, 0.02)
        x[s:s + n] += click * rng.uniform(0.4, 1.0)
    return x
def clang():
    d = 0.9; tt = t(d); x = np.zeros_like(tt)
    for f, a in [(523, 1), (1187, .6), (1873, .4), (2649, .3), (3720, .2)]:
        x += a * np.sin(2 * np.pi * f * tt) * np.exp(-tt * (4 + f / 900))
    x += highpass(noise(d), 2000) * env(len(tt), 0.001, 0.03) * 0.6
    return x
def footstep():
    d = 0.16; tt = t(d)
    return lowpass(noise(d), 900) * env(len(tt), 0.003, 0.04) + 0.4 * np.sin(2 * np.pi * 70 * tt) * env(len(tt), 0.002, 0.05)
def pickup():
    d = 0.5; tt = t(d); x = np.zeros_like(tt)
    for i, f in enumerate([880, 1320, 1760]):
        s = int(i * 0.07 * SR); seg = tt[: len(tt) - s]
        x[s:] += np.sin(2 * np.pi * f * seg) * np.exp(-seg * 7)
    return x
def coins():
    d = 0.6; x = np.zeros(int(d * SR))
    for k in range(6):
        s = int(rng.uniform(0, 0.3) * SR); tt = t(0.25)
        f = rng.uniform(2800, 4200)
        c = (np.sin(2 * np.pi * f * tt) + .5 * np.sin(2 * np.pi * f * 1.5 * tt)) * np.exp(-tt * 22)
        x[s:s + len(c)] += c[: len(x) - s] * rng.uniform(.5, 1)
    return x
def levelup():
    d = 1.6; tt = t(d); x = np.zeros_like(tt)
    for i, f in enumerate([392, 494, 587, 784, 988]):
        s = int(i * 0.11 * SR); seg = tt[: len(tt) - s]
        x[s:] += (np.sin(2 * np.pi * f * seg) + .3 * np.sin(4 * np.pi * f * seg)) * np.exp(-seg * 2.2)
    return x
def spell():
    d = 0.7; tt = t(d)
    f = 300 + 900 * (1 - np.exp(-tt * 6))
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = np.sin(ph) * .6 + np.sin(ph * 1.503) * .3
    sh = lowpass(noise(d), 4000) * .5
    return (tone + sh) * env(len(tt), 0.02, 0.35, 3)
def spell_hit():
    d = 0.6; tt = t(d)
    return lowpass(noise(d), 3000) * env(len(tt), 0.001, 0.2) + np.sin(2 * np.pi * 180 * tt * np.exp(-tt * 2)) * env(len(tt), 0.001, 0.25)
def hurt():
    d = 0.35; tt = t(d)
    f = 180 * np.exp(-tt * 1.5)
    ph = 2 * np.pi * np.cumsum(f) / SR
    v = np.sign(np.sin(ph)) * .3 + np.sin(ph)
    h = np.zeros_like(tt); hh = hit()[: len(tt)]; h[: len(hh)] = hh
    return lowpass(v, 1200) * env(len(tt), 0.01, 0.15) + h * .5
def skel_attack():
    d = 0.4; tt = t(d)
    return highpass(noise(d), 1500) * env(len(tt), 0.01, 0.12) * np.sin(2 * np.pi * 30 * tt) ** 2
def roar():
    d = 2.2; tt = t(d)
    f = 55 + 15 * np.sin(2 * np.pi * 5 * tt) + 25 * np.exp(-tt)
    ph = 2 * np.pi * np.cumsum(f) / SR
    saw = 2 * ((ph / (2 * np.pi)) % 1) - 1
    rough = lowpass(noise(d), 500)
    x = lowpass(saw, 700) + rough * .8
    return x * env(len(tt), 0.2, 1.4, 2.5)
def slam():
    d = 1.4; tt = t(d)
    boom = np.sin(2 * np.pi * (60 * np.exp(-tt * 3)) * tt) * env(len(tt), 0.002, 0.8, 3)
    rubble = lowpass(noise(d), 1500) * env(len(tt), 0.01, 0.5, 4)
    return boom + rubble * .6
def door():
    d = 2.6; tt = t(d)
    grind = lowpass(noise(d), 260 + 120 * np.sin(2 * np.pi * 3 * tt)) * np.clip(tt * 4, 0, 1) * np.clip((d - tt) * 3, 0, 1)
    thunk = np.zeros_like(tt); s = int(2.2 * SR); seg = tt[: len(tt) - s]
    thunk[s:] = np.sin(2 * np.pi * 50 * seg) * np.exp(-seg * 8)
    return grind * 1.2 + thunk
def lever():
    d = 0.5; tt = t(d)
    return clang()[: len(tt)] * .3 + lowpass(noise(d), 800) * env(len(tt), 0.01, 0.1)
def fire_burst():
    d = 1.0; tt = t(d)
    return lowpass(noise(d), 1400 + 800 * np.exp(-tt * 3)) * env(len(tt), 0.03, 0.6, 2.5)
def splash():
    d = 0.6; x = lowpass(highpass(noise(d), 400), 3000) * env(int(d * SR), 0.005, 0.25, 4)
    for k in range(8):
        s = int(rng.uniform(0.05, 0.45) * SR); tt = t(0.06)
        b = np.sin(2 * np.pi * rng.uniform(600, 1400) * tt * (1 + tt * 8)) * np.exp(-tt * 60)
        x[s:s + len(b)] += b[: len(x) - s] * .4
    return x
def chest():
    return np.concatenate([door()[: int(0.7 * SR)] * .6, pickup() * .8])
def death_sting():
    d = 3.0; tt = t(d); x = np.zeros_like(tt)
    for f in [110, 131, 165, 196]:
        x += np.sin(2 * np.pi * f * tt * (1 - tt * .03))
    return x * env(len(tt), 0.05, 2.2, 2)
def victory():
    d = 4.0; tt = t(d); x = np.zeros_like(tt)
    notes = [(0.0, [262, 330, 392]), (0.5, [294, 370, 440]), (1.0, [330, 415, 494]), (1.6, [392, 494, 587, 784])]
    for st, chord in notes:
        s = int(st * SR); seg = tt[: len(tt) - s]
        for f in chord:
            x[s:] += (np.sin(2 * np.pi * f * seg) + .25 * np.sin(4 * np.pi * f * seg)) * np.exp(-seg * (1.2 if st > 1.5 else 3))
    return x

# --- Loops --------------------------------------------------------------------
def cave_drone():
    d = 12.25; tt = t(d)
    x = np.zeros_like(tt)
    for f, a in [(55, 1), (82.4, .6), (110.3, .35), (164.8, .15)]:
        x += a * np.sin(2 * np.pi * f * tt + np.sin(2 * np.pi * 0.08 * tt) * 2)
    wind = lowpass(noise(d), 300 + 200 * (np.sin(2 * np.pi * 0.11 * tt) + 1))
    x = x * .35 + wind * 1.2
    drips = np.zeros_like(tt)
    for k in range(9):
        s = int(rng.uniform(0.3, d - 0.6) * SR); seg = t(0.15)
        drips[s:s + len(seg)] += np.sin(2 * np.pi * rng.uniform(900, 1700) * seg * (1 + seg * 6)) * np.exp(-seg * 40) * .5
    return loopify(x + drips)
def river_loop():
    d = 8.25; base = lowpass(highpass(noise(d), 200), 1800)
    tt = t(d); mod = 0.7 + 0.3 * np.sin(2 * np.pi * 0.25 * tt)
    x = base * mod
    for k in range(70):
        s = int(rng.uniform(0, d - 0.1) * SR); seg = t(0.05)
        x[s:s + len(seg)] += np.sin(2 * np.pi * rng.uniform(500, 1500) * seg * (1 + seg * 12)) * np.exp(-seg * 70) * .35
    shimmer = np.sin(2 * np.pi * 880 * tt) * .03 * (np.sin(2 * np.pi * .2 * tt) + 1)
    return loopify(x + shimmer)
def fire_loop():
    d = 4.25; tt = t(d)
    x = lowpass(noise(d), 600) * (0.8 + 0.2 * np.sin(2 * np.pi * 1.3 * tt))
    for k in range(40):
        s = int(rng.uniform(0, d - 0.05) * SR); seg = t(0.02)
        x[s:s + len(seg)] += highpass(noise(0.02), 2000) * np.exp(-seg * 200) * rng.uniform(.3, 1.2)
    return loopify(x)
def music_explore():
    # slow minor pad: Am - F - Dm - E, 6s each
    d = 24.5; tt = t(d); x = np.zeros_like(tt)
    chords = [[110, 130.8, 164.8], [87.3, 110, 130.8], [73.4, 87.3, 110], [82.4, 103.8, 123.5]]
    for i, ch in enumerate(chords):
        s = int(i * 6 * SR); n = int(6.6 * SR); seg = t(6.6)
        e = np.clip(seg / 1.5, 0, 1) * np.clip((6.6 - seg) / 1.5, 0, 1)
        for f in ch:
            for det in (0.997, 1.003):
                tone = np.sin(2 * np.pi * f * 2 * det * seg) + .3 * np.sin(2 * np.pi * f * 4 * det * seg)
                end = min(len(x), s + n); x[s:end] += (tone * e)[: end - s]
    return loopify(lowpass(x, 1800), 0.5)
def music_boss():
    d = 8.25; tt = t(d); x = np.zeros_like(tt)
    beat = 60 / 132
    for k in range(int(d / beat)):
        s = int(k * beat * SR); seg = t(0.35)
        drum = np.sin(2 * np.pi * (70 * np.exp(-seg * 12)) * seg) * np.exp(-seg * 9)
        if k % 4 == 2: drum = drum * .6 + lowpass(noise(0.35), 3000) * np.exp(-seg * 14) * .7
        x[s:s + len(seg)] += drum[: len(x) - s]
    bass_notes = [55, 55, 58.3, 55, 51.9, 55, 61.7, 58.3]
    for i, f in enumerate(bass_notes * 2):
        s = int(i * 2 * beat * SR); seg = t(2 * beat)
        if s >= len(x): break
        ph = 2 * np.pi * f * seg
        b = (2 * ((ph / (2 * np.pi)) % 1) - 1) * np.exp(-seg * 1.5)
        end = min(len(x), s + len(seg)); x[s:end] += lowpass(b, 400)[: end - s] * .5
    return loopify(x, 0.1)

SOUNDS = {
    "swing": swing, "hit": hit, "bone_break": bone_break, "clang": clang, "footstep": footstep,
    "pickup": pickup, "coins": coins, "levelup": levelup, "spell": spell, "spell_hit": spell_hit,
    "hurt": hurt, "skel_attack": skel_attack, "roar": roar, "slam": slam, "door": door,
    "lever": lever, "fire_burst": fire_burst, "splash": splash, "chest": chest,
    "death": death_sting, "victory": victory,
    "loop_cave": cave_drone, "loop_river": river_loop, "loop_fire": fire_loop,
    "music_explore": music_explore, "music_boss": music_boss,
}

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "game/assets/audio"
    os.makedirs(out, exist_ok=True)
    for name, fn in SOUNDS.items():
        save(os.path.join(out, name + ".wav"), fn(), 0.8 if name.startswith(("loop", "music")) else 0.9)
        print("wrote", name)
