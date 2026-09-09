#!/usr/bin/env python3
"""Compose Last Light: original, deterministic Outpost menu music (requires NumPy).

No sampled recordings, soundfonts, or third-party compositions are used.
Writes a seamless stereo PCM master; encode to Ogg Vorbis for the game.
"""
import argparse
import json
import math
from pathlib import Path
import wave
import numpy as np

SR = 44100
BPM = 72
BEAT = 60 / BPM
BARS = 32
N = round(BARS * 4 * BEAT * SR)
RNG = np.random.default_rng(8051)


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def envelope(t, length, attack, release):
    return np.sin(np.minimum(t / attack, 1) * np.pi / 2) ** 2 * np.sin(np.minimum((length - t) / release, 1) * np.pi / 2) ** 2


def add(bus, signal, start, gain, pan=0):
    """Wrap release tails over the musical loop boundary, preserving their continuity."""
    signal = signal.astype(np.float32) * gain
    stereo = signal[:, None] * np.array([math.sqrt((1-pan)/2), math.sqrt((1+pan)/2)], np.float32)
    offset = round(start * SR) % N
    first = min(len(signal), N - offset)
    bus[offset:offset+first] += stereo[:first]
    if first < len(signal):
        bus[:len(signal)-first] += stereo[first:]


def pad(note, seconds, phase):
    t = np.arange(round(seconds * SR)) / SR
    f = hz(note)
    tone = np.zeros(len(t))
    for detune in [-0.0017, 0.0013]:
        p = 2 * np.pi * f * (1 + detune) * t + phase
        tone += np.sin(p) + .20 * np.sin(2*p + .2) + .065 * np.sin(3*p)
    return tone * .5 * envelope(t, seconds, 1.8, 2.2) * (.91 + .09*np.sin(2*np.pi*.13*t + phase))


def pluck(note, seconds, soft=False):
    t = np.arange(round(seconds * SR)) / SR
    f = hz(note)
    tone = np.zeros(len(t))
    # Slightly inharmonic upper modes make a muted, worn string/metal timbre.
    for k, weight in enumerate([1, .34, .15, .06, .025], 1):
        decay = (1.8 if soft else 2.5) / (k ** .55)
        tone += weight * np.sin(2*np.pi*f*k*(1 + .00013*k*k)*t) * np.exp(-t/decay)
    return tone * envelope(t, seconds, .016 if soft else .026, .7)


def pulse(seconds=.8):
    t = np.arange(round(seconds * SR)) / SR
    phase = 2*np.pi*(45*t + 20*.035*(1-np.exp(-t/.035)))
    return np.sin(phase) * np.exp(-t/.15) * envelope(t, seconds, .014, .25)


def compose():
    dry = np.zeros((N, 2), np.float32)
    # D minor add9, Bb major7, F add9, C suspended; an A-minor turnaround.
    chords = [([38,50,57,65,76],50), ([34,46,53,62,69],46),
              ([41,53,60,69,79],53), ([36,48,55,64,74],48),
              ([43,55,62,65,74],55), ([34,46,53,62,69],46),
              ([38,50,57,65,76],50), ([33,45,52,60,71],45)]
    for block in range(16):
        notes, root = chords[block % 8]
        start = block * 8 * BEAT
        for i, note in enumerate(notes):
            add(dry, pad(note, 10*BEAT, RNG.uniform(0, 2*np.pi)), start-.8,
                [.085,.040,.033,.025,.013][i], [-.1,-.45,.40,-.3,.5][i])
        # A low, unhurried ostinato under the melody; thinner during the closing bars.
        pattern = [(0,root), (1.5,root+7), (3.25,root+12), (5,root+7), (6.5,root+12)]
        if block in [0, 1, 14, 15]:
            pattern = pattern[::2]
        for beat, note in pattern:
            add(dry, pluck(note, 4.0, True), start+beat*BEAT,
                RNG.uniform(.045,.063), -.26 if beat < 4 else .24)
        if 2 <= block <= 13:
            for beat, gain in [(0,.055), (2.5,.025), (4,.04)]:
                add(dry, pulse(), start+beat*BEAT, gain)
    # Four eight-bar phrases, with space for the UI's mechanical sounds.
    phrases = [
        [(2,69),(5,65),(9,64),(12,62),(18,65),(21,69),(26,67),(29,64)],
        [(1,69),(4,72),(8,74),(11,69),(17,67),(21,65),(26,64),(29,60)],
        [(2,77),(5,76),(9,74),(14,69),(18,72),(22,69),(26,67),(29,64)],
        [(1,69),(6,65),(10,64),(14,62),(20,65),(25,64),(28,60)]
    ]
    for section, phrase in enumerate(phrases):
        for j, (beat, note) in enumerate(phrase):
            add(dry, pluck(note, 6.5), (section*32+beat)*BEAT,
                .074 if section == 2 else .066, .12*np.sin(j*1.3))
    # Very quiet, periodic air, filtered in the frequency domain. No loop crossfade dip.
    size = N // 4
    frequencies = np.fft.rfftfreq(size, 1/SR)
    spectrum = np.exp(-frequencies/1600) / np.maximum(frequencies, 80)**.7
    spectrum[frequencies < 70] = 0
    for channel in range(2):
        air = np.fft.irfft(spectrum*np.exp(1j*RNG.uniform(0,2*np.pi,len(spectrum))), n=size)
        air *= .0015 / np.std(air)
        dry[:,channel] += np.tile(air,4).astype(np.float32)
    mix = dry.copy()
    for i, delay in enumerate([.137,.229,.383,.541,.719,.967,1.277,1.669,2.137,2.743]):
        reflected = np.roll(dry, round(delay*SR), axis=0)
        if i % 2:
            reflected = reflected[:, ::-1]
        mix += reflected * (.14 * np.exp(-delay/1.5))
    # Gentle saturation and DC removal; leave 3 dB of headroom.
    mix = np.tanh(mix * 1.35)
    mix -= mix.mean(axis=0)
    mix *= 10**(-3/20) / np.max(np.abs(mix))
    return mix


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--ogg', type=Path, help='Also encode an Ogg Vorbis game asset (requires SoundFile).')
    args = parser.parse_args()
    mix = compose()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.round(np.clip(mix, -1, 1)*32767).astype('<i2')
    with wave.open(str(args.output), 'wb') as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(SR)
        out.writeframes(pcm.tobytes())
    stats = {'title':'Last Light at the Outpost','bpm':BPM,'bars':BARS,
             'seconds':N/SR,'sample_rate':SR,'channels':2,
             'peak_dbfs':float(20*np.log10(np.max(np.abs(mix)))),
             'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(mix**2)))),
             'loop_step':float(np.max(np.abs(mix[0]-mix[-1]))),
             'max_adjacent_step':float(np.max(np.abs(np.diff(mix,axis=0)))),
             'clipped_samples':int(np.count_nonzero(np.abs(mix)>=1))}
    args.output.with_suffix('.json').write_text(json.dumps(stats,indent=2)+'\n')
    print(json.dumps(stats,indent=2))
    if args.ogg:
        import soundfile as sf
        args.ogg.parent.mkdir(parents=True, exist_ok=True)
        # Small writes also avoid the Vorbis encoder's large-initial-block bug.
        with sf.SoundFile(args.ogg, 'w', samplerate=SR, channels=2, subtype='VORBIS') as out:
            for start in range(0, len(mix), 4096):
                out.write(mix[start:start+4096])


if __name__ == '__main__':
    main()
