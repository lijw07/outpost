# Last Light at the Outpost

Original instrumental menu cue composed for Outpost. No sampled recordings,
soundfonts, stock music, or third-party melodies were used. The composition
and deterministic instrument synthesis are in `tools/audio/compose_menu_music.py`.

- Mood: restrained, uneasy, with a little warmth; intended for the forest camp,
  worn metal signs, and survival setting.
- 72 BPM, D minor, 32 bars, 106.6667 seconds.
- Muted plucked motif, low sustained harmonies, sparse bass pulse, quiet air,
  and stereo reflections. No vocals.
- 44.1 kHz stereo Ogg Vorbis; approximately 1 MB. Decoded peak: -2.93 dBFS.
- Release and reflection tails wrap around the composition boundary. No silent
  intro/outro is baked into the loop; the menu player handles entry/exit fades.
- Plays on the Music bus, at -8 dB before user volume settings. The Music and
  Master sliders control it. Menu navigation keeps the same player; gameplay
  and Quit fade it out, and returning to the menu starts it again.

## Rebuild

Use Python with NumPy and SoundFile available:

```sh
python3 tools/audio/compose_menu_music.py output/audio/last_light.wav --ogg assets/audio/music/last_light.ogg
```

The script also writes measurements beside the PCM master. Generated masters
and review excerpts belong in the ignored `output/audio/` directory.

## Verification

The encoded track decodes to the expected 4,704,000 stereo frames, with no
clipping or invalid samples. Its last-to-first sample step is 0.00187 (well below
normal waveform steps). Godot UI regression checks cover playback on entry,
loop configuration, continuity across menu navigation, disposal on game launch,
and playback on returning to the menu.

Six additional Godot mixer checks verified fade-in, decoded audio, navigation
continuity, slider mute, endpoint looping, and fade-out/stop.
