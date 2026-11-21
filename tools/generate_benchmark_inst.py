#!/usr/bin/env python3
"""Generate the built-in instrument for the Device Benchmark song.

The benchmark (Options -> Optimization -> Device Benchmark) plays a fixed,
mod-free chart for about 60 seconds. It needs an Instrumental that ships with
every full build, exercises the audio decoder, and is bit-reproducible, which
is why it is synthesized here instead of committed as an arbitrary recording.

Usage:

    pip install numpy soundfile imageio-ffmpeg
    python3 tools/generate_benchmark_inst.py

Writes `assets/songs/phoenix-benchmark/Inst.ogg` (~60 s, 44.1 kHz stereo OGG Vorbis).
The output is deterministic: every run produces the same samples, so the
generated file is committed to the repository and this script only needs to be
re-run when the arrangement changes on purpose.

The OGG is encoded with the static ffmpeg that `imageio-ffmpeg` ships (or an
`ffmpeg` on PATH): the Vorbis encoder bundled with some libsndfile wheels
segfaults on long inputs.
"""

import os
import subprocess
import sys
import wave

import numpy as np
import soundfile as sf

SAMPLE_RATE = 44100
BPM = 120.0
BEAT = 60.0 / BPM            # 0.5 s
BAR = BEAT * 4               # 2.0 s
BARS = 30                    # 60.0 s exactly, matching the in-code chart
DURATION = BAR * BARS

A2, F2, C3, G2 = 110.00, 87.31, 130.81, 98.00
A3, C4, D4, E4, G4, A4 = 220.00, 261.63, 293.66, 329.63, 392.00, 440.00
C5, E5 = 523.25, 659.25

# One root per bar, two bars per chord. Am, F, C, G — a loop Android
# can scream along to (not that it hears itself; the notes are botplayed).
ROOTS = [A2, A2, F2, F2, C3, C3, G2, G2,
         A2, A2, F2, F2, C3, C3, G2, G2,
         A2, A2, F2, F2, C3, C3, G2, G2,
         A2, A2, F2, F2, C3, G2, A2, A2]

ARP = [A3, C4, E4, A4, E4, C4, G4, E4]
ARP_CHORUS = [A4, C5, E5, C5, G4, E4, D4, E4]


def envelope(length, attack=0.005, decay=8.0):
    t = np.arange(length) / SAMPLE_RATE
    env = np.exp(-decay * t)
    n_attack = max(1, int(attack * SAMPLE_RATE))
    env[:n_attack] *= np.linspace(0.0, 1.0, n_attack)
    return env


def soft_clip(x):
    return np.tanh(x * 1.6) / np.tanh(1.6)


def render():
    n = int(DURATION * SAMPLE_RATE)
    left = np.zeros(n)
    right = np.zeros(n)
    rng = np.random.default_rng(0xB0BE)

    def add(buf, pos, samples, gain, pan):
        end = min(pos + len(samples), len(buf[0]))
        if end <= pos:
            return
        chunk = samples[:end - pos] * gain
        # equal-power-ish pan, 0 = hard left, 1 = hard right
        buf[0][pos:end] += chunk * np.cos(pan * np.pi / 2)
        buf[1][pos:end] += chunk * np.sin(pan * np.pi / 2)

    def kick(buf, pos, gain=1.0):
        length = int(0.22 * SAMPLE_RATE)
        t = np.arange(length) / SAMPLE_RATE
        freq = 40.0 + 90.0 * np.exp(-9.0 * t)
        phase = 2 * np.pi * np.cumsum(freq) / SAMPLE_RATE
        body = np.sin(phase) * envelope(length, 0.002, 11.0)
        click = rng.standard_normal(length) * np.exp(-220.0 * t) * 0.35
        add(buf, pos, body + click, gain, 0.5)

    def hat(buf, pos, gain=0.35, pan=0.62):
        length = int(0.05 * SAMPLE_RATE)
        noise = rng.standard_normal(length)
        # crude high-pass: difference the noise
        noise = np.diff(noise, prepend=0.0)
        add(buf, pos, noise * envelope(length, 0.001, 55.0), gain, pan)

    def snare(buf, pos, gain=0.5):
        length = int(0.16 * SAMPLE_RATE)
        t = np.arange(length) / SAMPLE_RATE
        noise = rng.standard_normal(length) * envelope(length, 0.001, 16.0)
        tone = np.sin(2 * np.pi * 190.0 * t) * envelope(length, 0.001, 14.0)
        noise = np.diff(noise, prepend=0.0) * 0.7
        add(buf, pos, noise * 0.8 + tone * 0.6, gain, 0.5)

    def bass(buf, pos, freq, length_s, gain=0.5):
        length = int(length_s * SAMPLE_RATE)
        t = np.arange(length) / SAMPLE_RATE
        phase = 2 * np.pi * freq * t
        saw = 2.0 * ((t * freq) % 1.0) - 1.0
        env = envelope(length, 0.008, 3.2)
        # crude one-pole lowpass
        lp = np.empty(length)
        acc = 0.0
        for i in range(length):
            acc += 0.055 * (saw[i] - acc)
            lp[i] = acc
        add(buf, pos, lp * env, gain, 0.44)

    def lead(buf, pos, freq, length_s, gain=0.3, pan=0.6):
        length = int(length_s * SAMPLE_RATE)
        t = np.arange(length) / SAMPLE_RATE
        tri = 2.0 * np.abs(2.0 * ((t * freq) % 1.0) - 1.0) - 1.0
        env = envelope(length, 0.006, 2.6)
        add(buf, pos, tri * env, gain, pan)

    def pad(buf, pos, freq, length_s, gain=0.16):
        length = int(length_s * SAMPLE_RATE)
        t = np.arange(length) / SAMPLE_RATE
        saw_a = 2.0 * ((t * freq) % 1.0) - 1.0
        saw_b = 2.0 * ((t * freq * 1.006) % 1.0) - 1.0  # detune
        sub = np.sin(2 * np.pi * (freq / 2) * t)
        env = np.minimum(1.0, np.minimum(t / 0.4, (length_s - t) / 0.6))
        chord = (saw_a + saw_b) * 0.25 + sub * 0.6
        add(buf, pos, chord * np.maximum(env, 0.0), gain, 0.5)

    def crash(buf, pos, gain=0.4):
        length = int(1.6 * SAMPLE_RATE)
        t = np.arange(length) / SAMPLE_RATE
        noise = rng.standard_normal(length)
        noise = np.diff(noise, prepend=0.0)
        add(buf, pos, noise * np.exp(-2.1 * t), gain, 0.5)

    buf = (np.zeros(n), np.zeros(n))

    for bar in range(BARS):
        bar_start = bar * BAR
        pos0 = int(bar_start * SAMPLE_RATE)
        root = ROOTS[bar]
        chorus = (bar % 8) in (2, 3, 4, 6)

        pad(buf, pos0, root, BAR, 0.17)

        for beat in range(4):
            beat_pos = int((bar_start + beat * BEAT) * SAMPLE_RATE)
            kick(buf, beat_pos, 1.0)
            if beat in (1, 3):
                snare(buf, beat_pos, 0.5)
            for eighth in (0, 1):
                hat_pos = int((bar_start + (beat + eighth * 0.5) * BEAT) * SAMPLE_RATE)
                hat(buf, hat_pos, 0.16 if eighth == 0 else 0.3, 0.62 if eighth == 0 else 0.38)

        for eighth in range(8):
            t_note = bar_start + eighth * (BEAT / 2)
            bass_pos = int(t_note * SAMPLE_RATE)
            # driving eighth-note bass, root with a fifth bounce on the offbeat
            freq = root if eighth % 4 != 3 else root * 1.5
            bass(buf, bass_pos, freq, 0.21, 0.5)
            arp_note = (ARP_CHORUS if chorus else ARP)[(bar * 3 + eighth) % 8]
            lead(buf, bass_pos, arp_note, 0.21, 0.22 if chorus else 0.13,
                 0.3 + 0.4 * ((eighth * 37 + bar * 11) % 10) / 10.0)

        if bar in (0, 8, 16, 24):
            crash(buf, pos0, 0.32)

    left, right = buf
    stereo = [left, right]
    peak = max(np.max(np.abs(left)), np.max(np.abs(right)))
    if peak > 0:
        stereo = [c / peak * 0.89 for c in stereo]
    out = np.stack(stereo, axis=1)
    out = soft_clip(out) * 0.94
    # 5 ms fade-in, 1.5 s fade-out so the loop boundary never clicks
    fade_in = int(0.005 * SAMPLE_RATE)
    fade_out = int(1.5 * SAMPLE_RATE)
    out[:fade_in] *= np.linspace(0.0, 1.0, fade_in)[:, None]
    out[-fade_out:] *= np.linspace(1.0, 0.0, fade_out)[:, None]
    return out


def ffmpeg_exe():
    try:
        import imageio_ffmpeg
        return imageio_ffmpeg.get_ffmpeg_exe()
    except Exception:
        from shutil import which
        exe = which('ffmpeg')
        if exe is None:
            sys.exit('ffmpeg not found: pip install imageio-ffmpeg (or install ffmpeg)')
        return exe


def main():
    ogg_path = 'assets/songs/phoenix-benchmark/Inst.ogg'
    os.makedirs(os.path.dirname(ogg_path), exist_ok=True)
    out = render()
    wav_path = 'assets/songs/phoenix-benchmark/.Inst.tmp.wav'
    pcm = (np.clip(out, -1.0, 1.0) * 32767.0).astype('<i2')
    with wave.open(wav_path, 'wb') as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(pcm.tobytes())
    try:
        subprocess.check_call([
            ffmpeg_exe(), '-y', '-hide_banner', '-loglevel', 'error',
            '-i', wav_path,
            '-c:a', 'libvorbis', '-q:a', '4',
            ogg_path,
        ])
    finally:
        try:
            os.remove(wav_path)
        except OSError:
            pass
    info = sf.info(ogg_path)
    print(f'wrote {ogg_path}: {info.samplerate} Hz, {info.channels} ch, '
          f'{info.frames / info.samplerate:.2f} s')


if __name__ == '__main__':
    main()
