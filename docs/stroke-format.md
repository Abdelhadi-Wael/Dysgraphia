# Stroke format (`dysgraphia-drawing`, version 1)

How handwriting is stored and exchanged between the tablet app and any other
part of the project (backend, scoring/AI service, dashboards). If you only
read one file before working with our data, read this one. No Dart needed.

## Example

One letter "o" written in one stroke (points shortened):

```json
{
  "format": "dysgraphia-drawing",
  "version": 1,
  "createdAt": "2026-11-17T10:22:31.123Z",
  "target": "o",
  "drawing": {
    "strokes": [
      [
        {"x": 0.4768, "y": -0.4268, "t": 0,  "p": 0.5},
        {"x": 0.4602, "y": -0.4425, "t": 8,  "p": 0.5},
        {"x": 0.4418, "y": -0.4562, "t": 16, "p": 0.5}
      ]
    ]
  }
}
```

## Fields

| Field | Type | Meaning |
|---|---|---|
| `format` | string | Always `"dysgraphia-drawing"`. Reject anything else. |
| `version` | int | Format version, currently `1`. Changes only on breaking changes. |
| `createdAt` | string | When it was written, ISO 8601 in UTC. |
| `target` | string or null | What the user was asked to write (`"o"`, `"cat"`), or `null` for free writing. |
| `drawing.strokes` | list of strokes | In the order they were written. |
| stroke | list of points | One pen-down → pen-up movement, points in order. |
| `x`, `y` | number | Position in **line units** (see below), rounded to 4 decimals. |
| `t` | int | Milliseconds since the **first point of the whole drawing** (not of the stroke), so pauses between strokes are visible. |
| `p` | number 0..1 | Pen pressure. **`0.5` on every point means "unknown"**: mouse, finger, or a device without pressure. Only trust it when it varies. |

## Line units: the coordinate system

Coordinates are **not pixels**. They are measured against the handwriting
guide lines, so the same letter written big or small, on a tablet or a phone,
gives the same numbers:

```
y = -1.0   ───────────────  top line       (top of tall letters: l, h, capitals)
y = -0.5   - - - - - - - -  midline        (top of small letters: a, o, x)
y =  0.0   ━━━━━━━━━━━━━━━  baseline       (every letter sits here)
y = +0.5   ───────────────  descender line (bottom of g, p, y)
```

* **y grows downwards** (screen convention). Above the baseline is negative.
* x grows to the right and uses **the same unit** as y, so shapes are not
  stretched. x = 0 is the left edge of the writing area.
* One unit = the distance from the baseline to the top line.

So a correctly sized lowercase "o" has y between -0.5 and 0, and a "g" goes
down to about +0.5.

## Things to know before analysing the data

* **Sampling is not uniform.** The tablet reports points at its own rate, and
  the app drops points that moved less than 0.004 units (jitter). Use `t` for
  speed and timing, and resample by distance before comparing shapes.
* **A single-point stroke is a dot**, e.g. the dot on an "i".
* **Stroke order and direction matter.** Teachers check where each stroke
  starts and which way it goes, so keep the order as given.
* **Speed:** distance between consecutive points divided by the difference in
  `t`. Pauses = large `t` gaps inside a stroke, or between strokes.

## Getting real samples

On the canvas test screen, write something and press **Export JSON**
(download icon, top right). Files are saved as
`<target>_<UTC time>.json`, e.g. `o_2026-11-17T10-22-31.123Z.json`, in a
`dysgraphia_exports` folder:

| Platform | Folder |
|---|---|
| Linux desktop | `~/Documents/dysgraphia_exports/` |
| Android | `Android/data/com.dysgraphia.dysgraphia_app/files/dysgraphia_exports/` (USB file transfer, or `adb pull /sdcard/Android/data/com.dysgraphia.dysgraphia_app/files/dysgraphia_exports`) |

The pop-up after saving also has a **Copy JSON** button.

## Reading it in Python

```python
import json
import matplotlib.pyplot as plt

with open("o_2026-11-17T10-22-31.123Z.json") as f:
    data = json.load(f)
assert data["format"] == "dysgraphia-drawing" and data["version"] == 1

for stroke in data["drawing"]["strokes"]:
    xs = [p["x"] for p in stroke]
    ys = [p["y"] for p in stroke]
    plt.plot(xs, ys, marker=".")
    plt.plot(xs[0], ys[0], "go")  # green dot = where the stroke starts

for y in (-1, -0.5, 0, 0.5):  # top line, midline, baseline, descender line
    plt.axhline(y, color="grey", linewidth=0.5)
plt.gca().invert_yaxis()  # y grows downwards
plt.gca().set_aspect("equal")
plt.title(f"target: {data['target']}")
plt.show()
```

## Source of truth

The Dart code that writes this format, if you need to check a detail:

* `lib/core/models/stroke.dart`: points, strokes, drawings
* `lib/core/models/drawing_export.dart`: the envelope (`format`, `version`, …)
* `lib/core/models/guide_geometry.dart`: pixels ↔ line units

Any change to these files that changes the JSON must update this document,
and a breaking change must bump `version`.
