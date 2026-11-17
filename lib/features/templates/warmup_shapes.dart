import 'letter_templates.dart';
import 'template_builder.dart';

/// Pre-writing warm-ups: the basic movements letters are made of, practised
/// on their own first. Each trains movements used by later letters:
/// * lines down: l, i, t, h, b, k, p …
/// * lines across: t, f, e, z
/// * circles: a, c, d, g, o, q
/// * slants: k, v, w, x, y, z
/// * zigzags: changing direction sharply (v, w, z)
/// * waves: smooth curves over and under (n, m, u, s)
///
/// Same rules as letters: lines top to bottom and left to right, circles
/// counter-clockwise from about 1-2 o'clock. All fit in 1.2 × 1 line units.
final Map<String, LetterTemplate> warmUpShapes = {
  for (final t in _shapes()) t.letter: t,
};

List<LetterTemplate> _shapes() => [
  LetterTemplate(
    'warmup-down',
    [
      for (final x in [0.0, 0.4, 0.8]) stroke([line(x, -0.9, x, 0)]),
    ],
    label: 'Lines down',
    isShape: true,
  ),
  LetterTemplate(
    'warmup-across',
    [
      for (final y in [-0.85, -0.45, -0.05]) stroke([line(0, y, 0.9, y)]),
    ],
    label: 'Lines across',
    isShape: true,
  ),
  LetterTemplate(
    'warmup-circle',
    [
      stroke([arc(0.45, -0.45, 0.45, 45, 360)]),
    ],
    label: 'Circles',
    isShape: true,
  ),
  LetterTemplate(
    'warmup-slants',
    [
      stroke([line(0, -0.9, 0.4, 0)]),
      stroke([line(1.0, -0.9, 0.6, 0)]),
    ],
    label: 'Slants',
    isShape: true,
  ),
  LetterTemplate(
    'warmup-zigzag',
    [
      stroke([
        line(0, -0.8, 0.25, -0.1),
        line(0.25, -0.1, 0.5, -0.8),
        line(0.5, -0.8, 0.75, -0.1),
        line(0.75, -0.1, 1.0, -0.8),
      ]),
    ],
    label: 'Zigzags',
    isShape: true,
  ),
  LetterTemplate(
    'warmup-waves',
    [
      // Over the top (clockwise), then under (counter-clockwise), twice.
      stroke([
        arc(0.15, -0.45, 0.15, 180, -180),
        arc(0.45, -0.45, 0.15, 180, 180),
        arc(0.75, -0.45, 0.15, 180, -180),
        arc(1.05, -0.45, 0.15, 180, 180),
      ]),
    ],
    label: 'Waves',
    isShape: true,
  ),
];

/// Any template by id: a letter ("a") or a warm-up shape.
LetterTemplate templateFor(String id) =>
    latinLowercase[id] ?? warmUpShapes[id]!;
