import 'package:material_ui/material_ui.dart';

import 'letter_page.dart';
import 'letter_template_view.dart';
import 'letter_templates.dart';

/// All letter templates with their stroke order. Tap one to watch and trace.
/// Mainly for reviewing the templates; later reused for the "watch" step.
class LetterGalleryPage extends StatelessWidget {
  const LetterGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final letters = latinLowercase.values.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Letter templates')),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: letters.length,
        itemBuilder: (context, i) {
          final t = letters[i];
          return Card(
            key: Key('letter-${t.letter}'),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LetterPage(letter: t.letter),
                ),
              ),
              child: Column(
                children: [
                  Expanded(child: LetterTemplateView(template: t)),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${t.letter} · ${t.strokeCount} '
                      '${t.strokeCount == 1 ? 'stroke' : 'strokes'}',
                      style: text.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
