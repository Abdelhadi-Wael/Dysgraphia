# Letter scoring (version 2)

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
| Checks | start point, stroke order, direction, staying on the line, finishing the stroke | looks, size, position on the lines, how it was written |
| Output | a hint; wrong strokes are rejected | 0-1 per measure, 1-3 stars, one tip |

## The four measures

Each measure is 0 (poor) to 1 (matches the template). *What the letter
looks like* and *how it was written* are kept apart on purpose: a child
whose "a" looks right but was started in the wrong place should hear "start
where the animation starts", not "your shape is wrong".

### Looks right (weight 45%)

1. **Resample**: spread 64 points evenly along the strokes by distance (each
   stroke gets points in proportion to its length, at least 4). This removes
   the effect of writing speed and of the device's sampling rate.
2. **Normalise**: centre the points' bounding box on (0, 0) and scale its
   larger side to 1. Position and size are judged separately, so here only
   the form counts. The aspect ratio is kept, so a tall "l" does not match a
   round "o".
3. **Compare as pictures, ignoring order**: for every point, the distance to
   the nearest point of the other letter. Average the worst quarter of these
   distances (so a missing or extra part counts, not only the outline), both
   ways, and keep the worse direction.

Because the order of points is ignored, an "o" drawn clockwise *looks*
perfect (score 1); the wrong direction is caught by the next measure.

Score: `1` when the distance is ≤ 0.05, falling linearly to `0` at 0.25.

### Size (weight 20%)

`ratio = written height / template height`. Score
`1 - |ln(ratio)| / ln(2)`: 1 at the right size, 0 at twice or half the
size, and symmetric (10% too big is judged like 10% too small).

### Position on the lines (weight 20%)

`offset = written bottom - template bottom` in line units: how far the
letter sits from the baseline (or, for g, j, p, q, y, from the descender
line). Score `1 - |offset| / 0.25`, so being off by half a small letter's
height scores 0. Negative offset = floating too high, positive = too low.

### Written the right way (weight 15%)

Strokes are compared one by one, after normalising the whole letter
together (so strokes keep their places). Checked in order; the first
problem found decides the score and tip:

| Check | How | Score | Tip |
|---|---|---|---|
| Number of strokes | written count ≠ template count | 0.5 (one off), 0.2 (more) | "Lift your pen like in the animation" |
| Order | a written stroke is clearly closer (by 0.08) to another template stroke than to the one in its place | 0.5 | "Do the dot last" if a dot came early, else "Write the parts in the order of the animation" |
| Direction | open strokes: start and end swapped; round strokes (ending near their start): turning the other way (sign of the enclosed area) | −0.5 per reversed stroke | "Go (round) the other way, like in the animation" |
| Start of a round stroke | right direction but starting more than 0.5 away | 0.7 | "Start where the animation starts" |

The stroke-count penalty is moderate on purpose: some children retrace
instead of lifting the pen (e.g. "n" in one stroke), which is not wrong.
The ordered (DTW) distance of version 1 is still saved with each attempt as
`orderedDistance`, for research.

## Overall, stars and tip

`overall = 0.45·looks + 0.2·size + 0.2·position + 0.15·movement`

| overall | stars |
|---|---|
| ≥ 0.85 | ★★★ |
| ≥ 0.60 | ★★ |
| below | ★ (never zero, to keep children motivated) |

So a letter that looks right, in the right size and place, but was written
backwards still gets 3 stars (0.925) with a tip about the direction.

**Tip**: the weakest measure below 0.8 gives one tip ("Make it a little
smaller", "Sit the letter on the baseline", "Go round the other way", …).
With none below 0.8: "Great job!". One tip at a time keeps it manageable
for a child.

## How the thresholds were chosen

From measurements on the 26 lowercase templates, not guesses:

* **Different letters** are typically 0.36 apart in looks (median over all
  650 pairs; 90% are above 0.24). So 0.25 = "this is another letter".
* **Copies with a wobble** of 0.02 line units are 0.04 apart (median), so
  0.05 = "a normal, slightly uneven copy" gets full marks.
* Look-alike pairs stay close: a/o 0.08, i/l 0.10, b/h 0.11. The scorer
  always knows which letter was asked for, and the stroke count and size
  usually separate them anyway.
* Movement checks: every stroke reversed and every stroke order swapped is
  caught for all 26 letters, with no false alarms on wobbly copies (tests
  in `letter_scorer_test.dart`).

Resulting stars on simulated writing (26 letters × 8 random variations,
including ±15% size and ±0.05 baseline drift):

| Writing | 1★ | 2★ | 3★ |
|---|---|---|---|
| Neat (wobble 0.02) | 0 | 2 | 206 |
| Moderate (0.04) | 0 | 72 | 136 |
| Messier (0.06) | 13 | 104 | 91 |
| Very messy (0.10) | 70 | 127 | 11 |
| Wrong letter | 624 | 24 | 2 |

Compared with version 1 (one ordered "shape" measure), wrong letters are
caught better (2 instead of 10 get 3 stars) but moderately wobbly writing
gets 3 stars less often (136 instead of 194 of 208). Raise `looksBad` to
be more forgiving.

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
| Looks right | 35% | mean of the letters' looks scores |
| Written the right way | 10% | mean of the letters' movement scores |
| Size | 15% | half *right size* (mean height ratio, like a letter), half *even size*: `1 - spread / 0.35`, spread = standard deviation / mean of the letters' height ratios |
| On the line | 20% | mean of the letters' position scores |
| Spacing | 20% | 70% gap size (each gap, rescaled to model size, scores 1 between 0.07 and 0.35, falling to 0 at 0 and 0.7) and 30% evenness (`1 - (widest - narrowest - 0.1) / 0.3`) |

Stars use the same bars as letters (≥ 0.85 three, ≥ 0.6 two). The tip
comes from the weakest measure below 0.8 and names the letter when it is
about one ("Make the "a" the same size as the others"). For looks and
movement the tip is judged by the worst letter, so one letter written
backwards gets a tip even when the rest are fine.
