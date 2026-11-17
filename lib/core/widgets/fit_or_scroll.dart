import 'package:material_ui/material_ui.dart';

/// Lays out [child] in the available height, or, on short screens (a phone
/// in landscape), gives it [minHeight] and lets the page scroll, instead of
/// squeezing it until it overflows.
///
/// Writing canvases inside keep their drags (see WritingCanvas), so the
/// page only scrolls when dragged outside the writing box.
class FitOrScroll extends StatelessWidget {
  const FitOrScroll({super.key, required this.minHeight, required this.child});

  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => box.maxHeight >= minHeight
        ? child
        : SingleChildScrollView(
            child: SizedBox(height: minHeight, child: child),
          ),
  );
}

/// Smallest heights at which each kind of exercise still works without
/// scrolling (writing boxes stay big enough to write in). Below them the
/// page scrolls; see [FitOrScroll].
abstract final class ExerciseHeights {
  static const watch = 240.0;
  static const trace = 280.0;
  static const copy = 260.0;
  static const check = 340.0;
}

/// Padding around exercise screens: less on short screens (a phone in
/// landscape), where every pixel of height goes to the writing box.
double pagePadding(BuildContext context) =>
    MediaQuery.sizeOf(context).height < 500 ? 8 : 16;
