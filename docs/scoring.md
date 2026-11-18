# Letter scoring (version 1)

How the app judges one written letter against its template, and why. The
rules are deliberately simple and explainable: every number can be traced
back to something a teacher would check. Code:
`lib/features/scoring/` (`geometry.dart`, `letter_scorer.dart`).

Coordinates are in **line units** (see [stroke-format.md](stroke-format.md)):
baseline y = 0, midline -0.5, top line -1, descender line +0.5. The
x-height (body of a small letter) is 0.5.

## Two kinds of feedback

| | Live checks (while writing) | Score (after the letter) |
|---|---|---|
| Purpose | Stop a mistake as it happens | Rate the finished letter |
| Where | `exercises/trace/trace_checker.dart` | `scoring/letter_scorer.dart` |
| Checks | start point, stroke order, direction, staying on the line, finishing the stroke | shape, size, position on the lines, number of strokes |
| Output | a hint; wrong strokes are rejected | 0-1 per measure, 1-3 stars, one tip |

## The four measures

Each measure is 0 (poor) to 1 (matches the template).

### Shape (weight 50%)

1. **Resample**: spread 64 points evenly along the strokes by distance (each
   stroke gets points in proportion to its length, at least 4). This removes
   the effect of writing speed and of the device's sampling rate.
2. **Normalise**: centre the points' bounding box on (0, 0) and scale its
   larger side to 1. Position and size are judged separately, so here only
   the form counts. The aspect ratio is kept, so a tall "l" does not match a
   round "o".
3. **Compare with dynamic time warping (DTW)**: align the two point
   sequences in writing order, letting one be locally faster or slower, and
   take the average distance between matched points.

Because DTW follows writing order, a letter written in the wrong direction
scores badly even if it looks right: an "o" drawn clockwise scores 0.63,
worse than most *different* letters. That matches how handwriting is taught.

Score: `1` when the distance is ≤ 0.05, falling linearly to `0` at 0.30.

### Size (weight 20%)

`ratio = written height / template height`. Score
`1 - |ln(ratio)| / ln(2)`: 1 at the right size, 0 at twice or half the
size, and symmetric (10% too big is judged like 10% too small).

### Position on the lines (weight 20%)

`offset = written bottom - template bottom` in line units: how far the
letter sits from the baseline (or, for g, j, p, q, y, from the descender
line). Score `1 - |offset| / 0.25`, so being off by half a small letter's
height scores 0. Negative offset = floating too high, positive = too low.

### Strokes (weight 10%)

Same number of strokes as the template: 1. One more or fewer: 0.6. Two or
more: 0.2. The penalty is small on purpose: some children retrace instead of
lifting the pen (e.g. "n" in one stroke), which is not wrong.

## Overall, stars and tip

`overall = 0.5·shape + 0.2·size + 0.2·position + 0.1·strokes`

| overall | stars |
|---|---|
| ≥ 0.85 | ★★★ |
| ≥ 0.60 | ★★ |
| below | ★ (never zero, to keep children motivated) |

**Tip**: the weakest measure below 0.8 gives one tip ("Make it a little
smaller", "Sit the letter on the baseline", …). With none below 0.8: "Great
job!". One tip at a time keeps it manageable for a child.

## How the thresholds were chosen

From measurements on the 26 lowercase templates, not guesses:

* **Different letters** are typically 0.31 apart in shape (median over all
  650 pairs; about 90% are above 0.2). So 0.30 = "this is another letter".
* **Copies with a wobble** of 0.02-0.06 line units score 0.02-0.06
  (median), so 0.05 = "a normal, slightly uneven copy" gets full marks.
* Look-alike pairs are close in shape: g/q 0.04, b/h 0.08, a/o 0.08,
  i/l 0.09. The scorer always knows which letter was asked for, so this
  only matters for recognition, which is a separate job.

Resulting stars on simulated writing (26 letters × 8 random variations,
including ±15% size and ±0.05 baseline drift):

| Writing | 1★ | 2★ | 3★ |
|---|---|---|---|
| Neat (wobble 0.02) | 0 | 0 | 208 |
| Moderate (0.04) | 0 | 14 | 194 |
| Messier (0.06) | 0 | 55 | 153 |
| Very messy (0.10) | 19 | 132 | 57 |
| Wrong letter | 588 | 52 | 10 |

## Limitations and next steps

* Thresholds come from simulated noise, not real children. Tune them with
  the handwriting-check data (all raw strokes are kept, so old attempts can
  be re-scored).
* The weights are a judgement call. A 45% too large letter with a perfect
  shape still gets 3 stars (with the tip "make it smaller"); raise the size
  weight if size should matter more.
* Not yet measured: fluency (speed, pauses, pen lifts), pressure, spacing
  between letters, slant. These need timing data from real writing and
  word-level tasks.
* A model trained on collected data could later learn better weights from
  these measures instead of fixed ones.

# Word scoring (version 1)

Code: `lib/features/scoring/word_scorer.dart`, models in
`lib/features/words/word_templates.dart`. A model word is its letter
templates placed left to right with a gap of 0.15 line units.

1. **Split into letters.** Strokes are sorted by their left edge. A stroke
   that overlaps (or comes within 0.04 of) the letter before joins it, so a
   dot joins its "i" and a crossbar its "t". If that gives too many letters
   (a "k" written with a gap), the two closest neighbours are joined until
   the count fits. Too few letters means some touch: the word is then
   scored as one shape, spacing gets 0.2 and the tip asks for gaps.
2. **Score each letter** with the letter scorer above.
3. **Word measures** (each 0-1):

| Measure | Weight | How |
|---|---|---|
| Shape | 40% | mean of the letters' shape scores |
| Size | 20% | half *right size* (mean height ratio, like a letter), half *even size*: `1 - spread / 0.35`, spread = standard deviation / mean of the letters' height ratios |
| On the line | 20% | mean of the letters' position scores |
| Spacing | 20% | 70% gap size (each gap, rescaled to model size, scores 1 between 0.07 and 0.35, falling to 0 at 0 and 0.7) and 30% evenness (`1 - (widest - narrowest - 0.1) / 0.3`) |

Stars use the same bars as letters (≥ 0.85 three, ≥ 0.6 two). The tip
comes from the weakest measure below 0.8 and names the letter when it is
about one ("Make the "a" the same size as the others").
