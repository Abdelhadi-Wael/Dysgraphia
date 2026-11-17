"""Generates the app's sound effects into assets/sounds/.

Original sounds, synthesised from plain sine waves, so there are no
licensing questions. Run from the project root:

    python3 tool/make_sounds.py

Each sound is short, soft at the start and end (no clicks), 22.05 kHz mono
16-bit WAV.
"""

import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def tone(freq, seconds, volume=0.5, decay=6.0):
    """A sine tone with a little second harmonic, a 5 ms fade-in and an
    exponential fade-out."""
    n = int(RATE * seconds)
    attack = int(RATE * 0.005)
    samples = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-decay * t) * min(1.0, i / attack if attack else 1.0)
        # Fade the very end to zero so sounds never end with a click.
        env *= min(1.0, (n - i) / (RATE * 0.01))
        s = math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(4 * math.pi * freq * t)
        samples.append(volume * env * s / 1.25)
    return samples


def sequence(notes):
    """Notes [(freq, seconds, volume, decay)] one after another."""
    out = []
    for note in notes:
        out += tone(*note)
    return out


def write(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(
            b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in samples)
        )


# E6 then B6: a bright, quick "ding" for earning stars.
write("star.wav", sequence([(1318.5, 0.12, 0.45, 10), (1975.5, 0.35, 0.45, 7)]))

# C5 E5 G5 C6: a short rising melody for finishing a letter or challenge.
write(
    "success.wav",
    sequence(
        [
            (523.3, 0.12, 0.45, 6),
            (659.3, 0.12, 0.45, 6),
            (784.0, 0.12, 0.45, 6),
            (1046.5, 0.6, 0.5, 4),
        ]
    ),
)

# A4 down to F4, soft and low: "try again", never harsh.
write("oops.wav", sequence([(440.0, 0.14, 0.25, 8), (349.2, 0.25, 0.25, 8)]))

print("Wrote", ", ".join(sorted(p.name for p in OUT.glob("*.wav"))))
