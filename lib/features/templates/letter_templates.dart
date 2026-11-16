import '../../core/models/stroke.dart';
import 'template_builder.dart';

/// The model of how one letter should be written: shape, number of
/// strokes, their order, where each starts and which way it goes.
class LetterTemplate {
  LetterTemplate(this.letter, List<Stroke> strokes)
    : drawing = Drawing(strokes);

  final String letter;
  final Drawing drawing;

  int get strokeCount => drawing.strokeCount;

  /// Right edge in line units (letters start at x = 0).
  double get width => drawing.bounds!.$3;
}

/// Lowercase print ("ball-and-stick") letters.
///
/// Conventions, as commonly taught:
/// * round letters start at about 1-2 o'clock and go counter-clockwise
///   (a, c, d, e, g, o, q); b and p bowls go clockwise from the stem;
/// * straight lines are written top to bottom and left to right;
/// * dots and crossbars come last.
/// Where print models retrace a line (h, m, n, r, u, b, p) we lift the pen
/// instead, which is easier to check. Stroke order varies between schools;
/// adjust a letter here if yours teaches it differently.
final Map<String, LetterTemplate> latinLowercase = {
  for (final t in _letters()) t.letter: t,
};

// Shared parts. x-height letters fit a 0.5 x 0.5 box on the baseline.
const _r = 0.25, _cx = 0.25, _cy = -0.25;

/// Circle from about 1-2 o'clock, counter-clockwise, all the way round.
Segment _circle() => arc(_cx, _cy, _r, 45, 360);

/// Bowl for b and p: from the stem, clockwise over the top and round.
Segment _bowl() => arc(_cx, _cy, _r, 180, -360);

/// Arch for h, m, n: from the stem up over the midline, then down.
List<Segment> _arch(double x0, double width) {
  final r = width / 2, cy = -0.5 + r;
  return [arc(x0 + r, cy, r, 160, -160), line(x0 + width, cy, x0 + width, 0)];
}

List<LetterTemplate> _letters() => [
  LetterTemplate('a', [
    stroke([_circle()]),
    stroke([line(0.5, -0.5, 0.5, 0)]),
  ]),
  LetterTemplate('b', [
    stroke([line(0, -1, 0, 0)]),
    stroke([_bowl()]),
  ]),
  LetterTemplate('c', [
    stroke([arc(_cx, _cy, _r, 45, 270)]),
  ]),
  LetterTemplate('d', [
    stroke([_circle()]),
    stroke([line(0.5, -1, 0.5, 0)]),
  ]),
  LetterTemplate('e', [
    stroke([line(0, -0.25, 0.5, -0.25), arc(_cx, _cy, _r, 0, 300)]),
  ]),
  LetterTemplate('f', [
    stroke([arc(0.35, -0.8, 0.2, 30, 150), line(0.15, -0.8, 0.15, 0)]),
    stroke([line(0, -0.5, 0.35, -0.5)]),
  ]),
  LetterTemplate('g', [
    stroke([_circle()]),
    stroke([line(0.5, -0.5, 0.5, 0.3), arc(0.3, 0.3, 0.2, 0, -160)]),
  ]),
  LetterTemplate('h', [
    stroke([line(0, -1, 0, 0)]),
    stroke(_arch(0, 0.5)),
  ]),
  LetterTemplate('i', [
    stroke([line(0, -0.5, 0, 0)]),
    stroke([dot(0, -0.75)]),
  ]),
  LetterTemplate('j', [
    stroke([line(0.4, -0.5, 0.4, 0.3), arc(0.2, 0.3, 0.2, 0, -160)]),
    stroke([dot(0.4, -0.75)]),
  ]),
  LetterTemplate('k', [
    stroke([line(0, -1, 0, 0)]),
    stroke([line(0.4, -0.5, 0.05, -0.25), line(0.05, -0.25, 0.42, 0)]),
  ]),
  LetterTemplate('l', [
    stroke([line(0, -1, 0, 0)]),
  ]),
  LetterTemplate('m', [
    stroke([line(0, -0.5, 0, 0)]),
    stroke(_arch(0, 0.4)),
    stroke(_arch(0.4, 0.4)),
  ]),
  LetterTemplate('n', [
    stroke([line(0, -0.5, 0, 0)]),
    stroke(_arch(0, 0.5)),
  ]),
  LetterTemplate('o', [
    stroke([_circle()]),
  ]),
  LetterTemplate('p', [
    stroke([line(0, -0.5, 0, 0.5)]),
    stroke([_bowl()]),
  ]),
  LetterTemplate('q', [
    stroke([_circle()]),
    stroke([line(0.5, -0.5, 0.5, 0.5)]),
  ]),
  LetterTemplate('r', [
    stroke([line(0, -0.5, 0, 0)]),
    stroke([arc(0.22, -0.28, 0.22, 160, -110)]),
  ]),
  LetterTemplate('s', [
    stroke([
      arc(0.2, -0.375, 0.2, 20, 250, ry: 0.125),
      arc(0.2, -0.125, 0.2, 90, -250, ry: 0.125),
    ]),
  ]),
  LetterTemplate('t', [
    stroke([line(0.2, -0.85, 0.2, 0)]),
    stroke([line(0, -0.5, 0.4, -0.5)]),
  ]),
  LetterTemplate('u', [
    stroke([line(0, -0.5, 0, -0.25), arc(_cx, _cy, _r, 180, 180)]),
    stroke([line(0.5, -0.5, 0.5, 0)]),
  ]),
  LetterTemplate('v', [
    stroke([line(0, -0.5, 0.25, 0), line(0.25, 0, 0.5, -0.5)]),
  ]),
  LetterTemplate('w', [
    stroke([
      line(0, -0.5, 0.2, 0),
      line(0.2, 0, 0.4, -0.5),
      line(0.4, -0.5, 0.6, 0),
      line(0.6, 0, 0.8, -0.5),
    ]),
  ]),
  LetterTemplate('x', [
    stroke([line(0, -0.5, 0.5, 0)]),
    stroke([line(0.5, -0.5, 0, 0)]),
  ]),
  LetterTemplate('y', [
    stroke([line(0, -0.5, 0.25, 0)]),
    stroke([line(0.5, -0.5, 0.05, 0.5)]),
  ]),
  LetterTemplate('z', [
    stroke([
      line(0, -0.5, 0.5, -0.5),
      line(0.5, -0.5, 0, 0),
      line(0, 0, 0.5, 0),
    ]),
  ]),
];
