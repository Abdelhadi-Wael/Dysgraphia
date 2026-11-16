import 'dart:ui';

import 'stroke.dart';

/// Where the four handwriting guide lines sit inside a writing box, and how
/// to convert between screen pixels and line units (see stroke.dart).
///
/// The box is split vertically into: top margin | ascender zone (top line →
/// midline → baseline) | descender zone | bottom margin.
class GuideGeometry {
  GuideGeometry(this.size, {this.topMargin = 0.12, this.bottomMargin = 0.08})
    : assert(topMargin + bottomMargin < 0.8);

  final Size size;
  final double topMargin;
  final double bottomMargin;

  /// The writing zone covers 1.5 line units (top line at -1 to descender at +0.5).
  static const double _zoneUnits = 1.5;

  /// Pixels per line unit.
  double get unit => size.height * (1 - topMargin - bottomMargin) / _zoneUnits;

  /// Box height (default margins) that gives [unit] pixels per line unit.
  static double heightForUnit(double unit) =>
      unit * _zoneUnits / (1 - 0.12 - 0.08);

  double get topLineY => size.height * topMargin;
  double get baselineY => topLineY + unit;
  double get midlineY => baselineY - unit * 0.5;
  double get descenderY => baselineY + unit * 0.5;

  /// Left padding before writing starts, in pixels.
  double get originX => unit * 0.25;

  /// Width of the box in line units.
  double get widthUnits => (size.width - originX) / unit;

  StrokePoint toLine(Offset px, {int t = 0, double pressure = 0.5}) =>
      StrokePoint(
        (px.dx - originX) / unit,
        (px.dy - baselineY) / unit,
        t: t,
        pressure: pressure,
      );

  Offset toPixels(StrokePoint p) =>
      Offset(originX + p.x * unit, baselineY + p.y * unit);
}
