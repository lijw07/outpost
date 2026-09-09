"""Original deterministic menu sounds, synthesized without recordings or samples.

Requires NumPy. Writes mono 44.1 kHz PCM WAV assets; no runtime synthesis cost.
"""
from pathlib import Path
import wave
import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parents[2] / 'assets/audio/menu'
RNG = np.random.default_rng(9024)


def noise(count, width=1):
    raw = RNG.normal(0, 1, count)
    return np.convolve(raw, np.ones(width) / np.sqrt(width), mode='same')


def write(name, signal, peak=.8, loop=False):
    signal = np.asarray(signal, dtype=np.float64)
    signal -= signal.mean()
    signal *= peak / max(np.max(np.abs(signal)), 1e-8)
    if not loop:
        fade = min(220, len(signal)//4)
        signal[:fade] *= np.linspace(0, 1, fade)
        signal[-fade:] *= np.linspace(1, 0, fade)
    else:
        # Crossfade both ends through the same quiet boundary value.
        fade = 2205
        signal[:fade] *= np.sin(np.linspace(0, np.pi/2, fade))**2
        signal[-fade:] *= np.sin(np.linspace(np.pi/2, 0, fade))**2
    with wave.open(str(ROOT / f'{name}.wav'), 'wb') as output:
        output.setparams((1, 2, SR, 0, 'NONE', 'not compressed'))
        output.writeframes(np.round(signal * 32767).astype('<i2').tobytes())


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    t = np.arange(int(SR*.42))/SR
    shot = noise(len(t), 2)*np.exp(-t*60)*1.1
    shot += noise(len(t), 35)*np.exp(-t*17)*.5
    shot += np.sin(2*np.pi*(110*t-35*t*t))*np.exp(-t*27)*.65
    shot += np.roll(shot, int(SR*.065))*.11
    write('rifle', shot)

    t = np.arange(int(SR*.22))/SR
    hammer = noise(len(t), 3)*np.exp(-t*120)*.35
    for frequency, gain, decay in [(185, .6, 30), (560, .32, 48), (1350, .16, 62)]:
        hammer += np.sin(2*np.pi*frequency*t)*np.exp(-t*decay)*gain
    write('hammer', hammer, .65)

    t = np.arange(int(SR*.14))/SR
    step = noise(len(t), 12)*np.exp(-t*35)*.35
    step += noise(len(t), 2)*np.sin(np.pi*np.minimum(t/.12, 1))**2*.08
    step += np.sin(2*np.pi*92*t)*np.exp(-t*45)*.4
    write('footstep', step, .55)

    t = np.arange(int(SR*.9))/SR
    pitch = 73+7*np.sin(2*np.pi*4.5*t)-20*t
    phase = 2*np.pi*np.cumsum(pitch)/SR
    groan = sum(np.sin(phase*k)*np.exp(-((k*65-440)/300)**2)/k for k in range(1, 13))
    groan += noise(len(t), 18)*.055
    groan *= np.sin(np.pi*t/.9)**1.5*(.8+.2*np.sin(2*np.pi*7*t))
    write('groan', groan, .65)

    t = np.arange(int(SR*.38))/SR
    fall = noise(len(t), 22)*np.exp(-t*13)*.5
    fall += np.sin(2*np.pi*67*t)*np.exp(-t*21)*.45
    fall += noise(len(t), 3)*np.exp(-((t-.08)/.075)**2)*.09
    write('body_fall', fall, .7)

    t = np.arange(int(SR*.5))/SR
    broken = noise(len(t), 7)*np.exp(-t*16)*.5
    for onset in [0, .08, .17, .26]:
        age = np.maximum(0, t-onset)
        broken += (t >= onset)*noise(len(t), 2)*np.exp(-age*80)*.32
    write('fence_break', broken, .75)

    t = np.arange(int(SR*.27))/SR
    timber = noise(len(t), 8)*np.exp(-t*25)*.3
    timber += np.sin(2*np.pi*240*t)*np.exp(-t*35)*.3
    timber += np.sin(2*np.pi*410*t)*np.exp(-t*42)*.15
    write('timber', timber, .6)

    t = np.arange(SR*8)/SR
    fire = noise(len(t), 75)*.05+noise(len(t), 6)*.025
    for onset in RNG.uniform(.1, 7.85, 36):
        age = np.maximum(0, t-onset)
        fire += (t >= onset)*noise(len(t), 3)*np.exp(-age*RNG.uniform(90, 220))*.15
    write('campfire', fire, .4, loop=True)
    print('Wrote eight original PCM sounds to', ROOT)


if __name__ == '__main__':
    main()
