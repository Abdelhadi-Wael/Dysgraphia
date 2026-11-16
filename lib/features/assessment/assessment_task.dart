import 'dart:math' as math;

import '../../core/models/stroke.dart';

/// One step of the handwriting check.
class AssessmentTask {
  const AssessmentTask({
    required this.id,
    required this.instruction,
    this.target,
    this.modelText,
    this.modelDrawing,
    this.expectedChars = 12,
    this.showGuides = true,
  });

  /// Stable identifier stored in result files, e.g. "alphabet_a_m".
  final String id;

  /// Shown to the user.
  final String instruction;

  /// What should be written, for scoring later (null for free writing).
  final String? target;

  /// Text to copy, shown above the canvas.
  final String? modelText;

  /// Picture to copy, shown above the canvas.
  final Drawing? modelDrawing;

  /// Roughly how many characters must fit on the line; the writing size
  /// shrinks so they fit the screen width.
  final double expectedChars;

  final bool showGuides;

  /// Line units needed across: ~0.75 per character plus the left margin.
  double get requiredWidthUnits => expectedChars * 0.75 + 0.5;
}

/// The default handwriting check: about 5 minutes, recording only.
final defaultAssessmentTasks = <AssessmentTask>[
  AssessmentTask(
    id: 'shapes',
    instruction: 'Copy these shapes',
    target: 'circle cross square triangle',
    modelDrawing: _shapesModel(),
    expectedChars: 9,
    showGuides: false,
  ),
  const AssessmentTask(
    id: 'alphabet_a_m',
    instruction: 'Write the small letters from a to m',
    target: 'abcdefghijklm',
    expectedChars: 13,
  ),
  const AssessmentTask(
    id: 'alphabet_n_z',
    instruction: 'Write the small letters from n to z',
    target: 'nopqrstuvwxyz',
    expectedChars: 13,
  ),
  const AssessmentTask(
    id: 'copy_sentence',
    instruction: 'Copy this sentence',
    target: 'the dog ran fast',
    modelText: 'the dog ran fast',
    expectedChars: 16,
  ),
];

/// Circle, cross, square and triangle side by side, each in a 1x1 box.
Drawing _shapesModel() {
  Stroke poly(double ox, List<(double, double)> pts) =>
      Stroke([for (final (x, y) in pts) StrokePoint(ox + x, y - 1)]);
  const gap = 1.5;
  return Drawing([
    Stroke([
      for (var i = 0; i <= 40; i++)
        StrokePoint(
          0.5 + 0.45 * math.cos(i / 40 * 2 * math.pi),
          -0.5 - 0.45 * math.sin(i / 40 * 2 * math.pi),
        ),
    ]),
    poly(gap, [(0.5, 0.05), (0.5, 0.95)]),
    poly(gap, [(0.05, 0.5), (0.95, 0.5)]),
    poly(2 * gap, [
      (0.05, 0.05),
      (0.95, 0.05),
      (0.95, 0.95),
      (0.05, 0.95),
      (0.05, 0.05),
    ]),
    poly(3 * gap, [(0.5, 0.05), (0.95, 0.95), (0.05, 0.95), (0.5, 0.05)]),
  ]);
}
