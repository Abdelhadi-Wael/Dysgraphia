import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'writing_controller.dart';

/// Keyboard shortcuts for any screen with a writing canvas:
/// Ctrl+Z undo, Ctrl+Shift+Z / Ctrl+Y redo (Cmd on macOS/iPad keyboards).
class WritingShortcuts extends StatelessWidget {
  const WritingShortcuts({
    super.key,
    required this.controller,
    required this.child,
  });

  final WritingController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bindings = <ShortcutActivator, VoidCallback>{};
    for (final (ctrl, meta) in [(true, false), (false, true)]) {
      bindings[SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: ctrl,
            meta: meta,
          )] =
          controller.undo;
      bindings[SingleActivator(
            LogicalKeyboardKey.keyZ,
            control: ctrl,
            meta: meta,
            shift: true,
          )] =
          controller.redo;
      bindings[SingleActivator(
            LogicalKeyboardKey.keyY,
            control: ctrl,
            meta: meta,
          )] =
          controller.redo;
    }
    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(autofocus: true, child: child),
    );
  }
}
