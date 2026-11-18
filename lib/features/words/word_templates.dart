import '../../core/models/stroke.dart';
import '../templates/letter_templates.dart';

/// Gap between letters in a model word, in line units (the x-height is
/// 0.5, so a little under a third of a small letter).
const letterGap = 0.15;

/// One letter placed inside a word.
class PlacedLetter {
  const PlacedLetter(this.template, this.dx);

  final LetterTemplate template;

  /// How far the letter is moved right from its own x = 0.
  final double dx;

  Drawing get drawing => template.drawing.shifted(dx, 0);
}

/// A short word built from the letter templates, written left to right
/// with even gaps, so it shows the same stroke order as single letters.
class WordTemplate {
  WordTemplate(this.word)
    : assert(word.split('').every(latinLowercase.containsKey)),
      letters = _place(word);

  final String word;
  final List<PlacedLetter> letters;

  /// Id saved in history (Attempt.letter), kept apart from letter ids.
  String get id => 'word-$word';

  /// The whole word as one template, to show as a model.
  late final LetterTemplate model = LetterTemplate(id, [
    for (final l in letters) ...l.drawing.strokes,
  ], label: 'Word: $word');

  Drawing get drawing => model.drawing;

  /// Right edge in line units.
  double get width => model.width;

  static List<PlacedLetter> _place(String word) {
    final out = <PlacedLetter>[];
    var cursor = 0.0;
    for (final c in word.split('')) {
      final t = latinLowercase[c]!;
      final (minX, _, maxX, _) = t.drawing.bounds!;
      out.add(PlacedLetter(t, cursor - minX));
      cursor += maxX - minX + letterGap;
    }
    return out;
  }
}

/// A group of practice words that only use letters taught by then.
class WordGroup {
  const WordGroup(this.name, this.words);

  final String name;
  final List<String> words;
}

/// Short, familiar words, grouped by the journey level whose letters they
/// need (round letters; lines and arches; slants and more).
const wordGroups = [
  WordGroup('Round letters', ['go', 'dog', 'cod', 'add']),
  WordGroup('Lines and arches', ['cat', 'hat', 'pin', 'map', 'bird', 'lamp']),
  WordGroup('Slants and more', ['sun', 'yes', 'box', 'fox', 'web', 'jump']),
];

final Map<String, WordTemplate> practiceWords = {
  for (final g in wordGroups)
    for (final w in g.words) 'word-$w': WordTemplate(w),
};

bool isWordId(String id) => id.startsWith('word-');

/// The word itself from its id: "word-cat" → "cat".
String practiceWordText(String id) => id.replaceFirst('word-', '');
