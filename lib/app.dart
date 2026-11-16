import 'package:material_ui/material_ui.dart';

import 'features/home/home_page.dart';

class DysgraphiaApp extends StatelessWidget {
  const DysgraphiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2A9D8F),
        brightness: b,
      ),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Handwriting Helper',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const HomePage(),
    );
  }
}
