import 'package:material_ui/material_ui.dart';

import '../assessment/assessment_page.dart';
import '../canvas/canvas_playground_page.dart';
import '../export/drawing_exporter.dart';
import '../templates/letter_gallery_page.dart';

/// Tools for development and research, kept out of the way of normal use
/// (Settings → Developer tools). Nothing done here is saved to a profile.
class DevToolsPage extends StatefulWidget {
  const DevToolsPage({super.key, this.exporter});

  /// Passed on to the screens that save files; tests use a temp folder.
  final DrawingExporter? exporter;

  @override
  State<DevToolsPage> createState() => _DevToolsPageState();
}

class _DevToolsPageState extends State<DevToolsPage> {
  final _participant = TextEditingController();

  @override
  void dispose() {
    _participant.dispose();
    super.dispose();
  }

  void _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Developer tools')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.gesture),
            title: const Text('Canvas test'),
            subtitle: const Text('Free writing, pen size, export a drawing'),
            onTap: () => _push(CanvasPlaygroundPage(exporter: widget.exporter)),
          ),
          ListTile(
            leading: const Icon(Icons.format_list_numbered),
            title: const Text('Letter gallery'),
            subtitle: const Text('All templates with stroke order'),
            onTap: () => _push(const LetterGalleryPage()),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _participant,
              decoration: const InputDecoration(
                labelText: 'Participant code (optional)',
                helperText: 'For a check outside any profile; not saved',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.assignment_outlined),
            title: const Text('Handwriting check without a profile'),
            subtitle: const Text('Exported to a file only'),
            onTap: () {
              // Read the code now, not when the screen was last drawn.
              final code = _participant.text.trim();
              _push(
                AssessmentPage(
                  participant: code.isEmpty ? null : code,
                  exporter: widget.exporter,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
