import 'package:flutter/foundation.dart';

import '../../core/models/stroke.dart';

/// Collects strokes as the user writes. Works purely in line units; the
/// canvas widget does the pixel conversion.
///
/// Every change (adding a stroke, clearing) is undoable and redoable.
class WritingController extends ChangeNotifier {
  WritingController({this.minPointDistance = 0.004, this.acceptStroke});

  /// Points closer than this (line units) to the previous one are dropped,
  /// which removes jitter and keeps the data small.
  final double minPointDistance;

  /// Called when the pen lifts. Returning false discards the stroke, e.g. a
  /// traced stroke going the wrong way. Null accepts everything.
  final bool Function(Stroke stroke)? acceptStroke;

  final List<Stroke> _strokes = [];
  List<StrokePoint>? _current;
  int? _t0;

  final List<_Edit> _undo = [];
  final List<_Edit> _redo = [];

  /// Finished strokes plus the one in progress (so the painter shows it live).
  List<Stroke> get strokes => [
    ..._strokes,
    if (_current != null) Stroke(_current!),
  ];

  Drawing get drawing => Drawing(_strokes);
  bool get isWriting => _current != null;
  bool get isEmpty => _strokes.isEmpty && _current == null;
  bool get canUndo => _current != null || _undo.isNotEmpty;
  bool get canRedo => _current == null && _redo.isNotEmpty;

  /// [p.t] is an absolute timestamp in ms; it is stored relative to the first
  /// point of the drawing.
  void beginStroke(StrokePoint p) {
    // A fresh drawing restarts the clock. Otherwise keep it, so strokes
    // brought back by undo/redo keep consistent times.
    if (_strokes.isEmpty) _t0 = p.t;
    _current = [_rel(p)];
    notifyListeners();
  }

  void addPoint(StrokePoint p) {
    final cur = _current;
    if (cur == null) return;
    final rel = _rel(p);
    if (cur.last.distanceTo(rel) < minPointDistance) return;
    cur.add(rel);
    notifyListeners();
  }

  /// Returns the finished stroke, or null if no stroke was in progress or
  /// [acceptStroke] rejected it.
  Stroke? endStroke() {
    final cur = _current;
    if (cur == null) return null;
    _current = null;
    final stroke = Stroke(cur);
    if (acceptStroke?.call(stroke) == false) {
      // Rejected: never part of the drawing, nothing to undo or redo.
      notifyListeners();
      return null;
    }
    _strokes.add(stroke);
    _record(_AddStroke(stroke));
    notifyListeners();
    return stroke;
  }

  /// Abandons the stroke in progress (e.g. pointer cancelled by the OS).
  void cancelStroke() {
    if (_current == null) return;
    _current = null;
    notifyListeners();
  }

  void undo() {
    if (_current != null) {
      _current = null;
    } else if (_undo.isNotEmpty) {
      final edit = _undo.removeLast();
      switch (edit) {
        case _AddStroke():
          _strokes.removeLast();
        case _Clear(:final removed):
          _strokes.addAll(removed);
      }
      _redo.add(edit);
    } else {
      return;
    }
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    final edit = _redo.removeLast();
    switch (edit) {
      case _AddStroke(:final stroke):
        _strokes.add(stroke);
      case _Clear():
        _strokes.clear();
    }
    _undo.add(edit);
    notifyListeners();
  }

  /// Removes everything. Can be undone.
  void clear() {
    _current = null;
    if (_strokes.isNotEmpty) {
      _record(_Clear(List.of(_strokes)));
      _strokes.clear();
    }
    notifyListeners();
  }

  void _record(_Edit e) {
    _undo.add(e);
    _redo.clear();
  }

  StrokePoint _rel(StrokePoint p) =>
      StrokePoint(p.x, p.y, t: p.t - _t0!, pressure: p.pressure);
}

sealed class _Edit {}

class _AddStroke extends _Edit {
  _AddStroke(this.stroke);
  final Stroke stroke;
}

class _Clear extends _Edit {
  _Clear(this.removed);
  final List<Stroke> removed;
}
