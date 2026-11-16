import 'package:material_ui/material_ui.dart';

import '../assessment/assessment_page.dart';
import '../canvas/canvas_playground_page.dart';
import '../export/drawing_exporter.dart';

/// Start screen. Simple for now; the real home (practice, progress) comes later.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.exporter});

  /// Passed on to the screens that save files; tests use a temp folder.
  final DrawingExporter? exporter;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _participant = TextEditingController();

  @override
  void dispose() {
    _participant.dispose();
    super.dispose();
  }

  void _startAssessment() {
    final code = _participant.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AssessmentPage(
          participant: code.isEmpty ? null : code,
          exporter: widget.exporter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Handwriting Helper',
                style: text.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _participant,
                decoration: const InputDecoration(
                  labelText: 'Participant code (optional)',
                  helperText: 'Use a code like P01, not a real name',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _startAssessment(),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _startAssessment,
                icon: const Icon(Icons.edit_note),
                label: const Text('Start handwriting check'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CanvasPlaygroundPage(exporter: widget.exporter),
                  ),
                ),
                child: const Text('Canvas test'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
