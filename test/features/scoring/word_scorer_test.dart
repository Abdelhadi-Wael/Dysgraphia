import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/features/scoring/word_scorer.dart';
import 'package:dysgraphia_app/features/templates/letter_templates.dart';
import 'package:dysgraphia_app/features/words/word_templates.dart';
import 'package:flutter_test/flutter_test.dart';

const scorer = WordScorer();

/// Writes [word] letter by letter: [gaps] between letters (model: 0.15),
/// each letter scaled by [scale] around its baseline and moved down by
/// [drop] (line units).
Drawing write(
  String word, {
  List<double>? gaps,
  Map<int, double> scale = const {},
  Map<int, double> drop = const {},
  Map<int, String> swap = const {},
  double k = 1,
}) {
  final strokes = <Stroke>[];
  var cursor = 0.3;
  for (final (i, c) in word.split('').indexed) {
    final t = latinLowercase[swap[i] ?? c]!;
    final (minX, _, maxX, _) = t.drawing.bounds!;
    final s = (scale[i] ?? 1) * k;
    for (final st in t.drawing.strokes) {
      strokes.add(
        Stroke([
          for (final p in st.points)
            StrokePoint(cursor + (p.x - minX) * s, p.y * s + (drop[i] ?? 0)),
        ]),
      );
    }
    cursor += (maxX - minX) * s + (gaps == null ? letterGap : gaps[i]) * k;
  }
  return Drawing(strokes);
}

void main() {
  test('model words are built from letters with even gaps', () {
    final cat = WordTemplate('cat');
    expect(cat.letters.map((l) => l.template.letter), ['c', 'a', 't']);
    final groups = scorer.splitLetters(cat.drawing, 3);
    expect(groups.map((g) => g.strokeCount), [1, 2, 2]);
    expect(practiceWords, hasLength(16));
  });

  test('a neat copy gets three stars and no tip', () {
    for (final w in practiceWords.values) {
      final s = scorer.score(write(w.word), w);
      expect(s.stars, 3, reason: w.word);
      expect(s.tip.kind, WordTipKind.none, reason: w.word);
      expect(s.letters, hasLength(w.letters.length));
    }
  });

  test('writing the whole word bigger still scores well on spacing', () {
    final s = scorer.score(write('dog', k: 1.3), WordTemplate('dog'));
    expect(s.spacing, 1);
    expect(s.tip.kind, isNot(WordTipKind.tooFar));
  });

  test('touching letters ask for gaps', () {
    final s = scorer.score(
      write('dog', gaps: [-0.02, -0.02, 0]),
      WordTemplate('dog'),
    );
    expect(s.letters, isNull);
    expect(s.tip.kind, WordTipKind.tooClose);
    expect(s.stars, lessThan(3));
  });

  test('letters far apart', () {
    final s = scorer.score(
      write('sun', gaps: [0.7, 0.7, 0]),
      WordTemplate('sun'),
    );
    expect(s.tip.kind, WordTipKind.tooFar);
  });

  test('uneven gaps', () {
    final s = scorer.score(
      write('lamp', gaps: [0.06, 0.4, 0.06, 0]),
      WordTemplate('lamp'),
    );
    expect(s.tip.kind, WordTipKind.unevenSpacing);
  });

  test('one letter too big is named', () {
    final s = scorer.score(write('cat', scale: {1: 1.8}), WordTemplate('cat'));
    expect(s.tip.kind, WordTipKind.unevenSize);
    expect(s.tip.letter, 'a');
    expect(s.tip.text, 'Make the "a" the same size as the others');
  });

  test('one letter off the line is named', () {
    final s = scorer.score(write('hat', drop: {1: -0.2}), WordTemplate('hat'));
    expect(s.tip.kind, WordTipKind.offLine);
    expect(s.tip.letter, 'a');
    expect(s.tip.below, isFalse);
    expect(s.tip.text, 'Sit the "a" on the baseline');
  });

  test('a wrong letter is named', () {
    final s = scorer.score(write('pin', swap: {2: 'o'}), WordTemplate('pin'));
    expect(s.tip.kind, WordTipKind.shape);
    expect(s.tip.letter, 'n');
  });

  test('a k written with a gap is still one letter', () {
    // Stem far from the arms.
    final k = Drawing([
      Stroke([const StrokePoint(0, -1), const StrokePoint(0, 0)]),
      Stroke([
        const StrokePoint(0.15, -0.5),
        const StrokePoint(0.1, -0.25),
        const StrokePoint(0.45, 0),
      ]),
    ]);
    final i = Drawing([
      Stroke([const StrokePoint(0.7, -0.5), const StrokePoint(0.7, 0)]),
      Stroke([const StrokePoint(0.7, -0.75)]),
    ]);
    final groups = scorer.splitLetters(
      Drawing([...k.strokes, ...i.strokes]),
      2,
    );
    expect(groups.map((g) => g.strokeCount), [2, 2]);
  });

  test('score JSON is complete', () {
    final j = scorer.score(write('go'), WordTemplate('go')).toJson();
    expect(j.keys, containsAll(['overall', 'stars', 'spacing', 'letters']));
  });
}
