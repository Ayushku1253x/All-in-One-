import 'package:flutter/material.dart';
import 'editor.dart';
import 'pdf_screen.dart';
import 'about.dart';
import 'splash.dart';
import 'batch.dart';
import 'ocr.dart';
import 'textimage.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    ThemeData t(Brightness b) => ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF4F46E5),
          brightness: b,
        );
    return MaterialApp(
      title: 'All In One',
      debugShowCheckedModeBanner: false,
      theme: t(Brightness.light),
      darkTheme: t(Brightness.dark),
      home: const Splash(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int i = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [
      Grid(title: 'Image Tools', items: [...imageTools.entries.map((e) => Item(e.key, e.value, () => Navigator.push(context, MaterialPageRoute(builder: (_) => Editor(tool: e.key))))), Item('Batch', Icons.collections, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BatchPage()))), Item('OCR', Icons.document_scanner, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrPage()))), Item('Text to Image', Icons.text_fields, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TextImagePage())))]),
      Grid(title: 'PDF Tools', items: [...pdfTools.map((t) => Item(t.name, t.icon, () => Navigator.push(context, MaterialPageRoute(builder: (_) => PdfPage(t: t))))), Item('OCR PDF', Icons.document_scanner, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrPage())))]),
      const About(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[i]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: (v) => setState(() => i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.image_outlined), selectedIcon: Icon(Icons.image), label: 'Images'),
          NavigationDestination(icon: Icon(Icons.picture_as_pdf_outlined), selectedIcon: Icon(Icons.picture_as_pdf), label: 'PDF'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'About'),
        ],
      ),
    );
  }
}

class Item {
  final String name;
  final IconData icon;
  final VoidCallback onTap;
  Item(this.name, this.icon, this.onTap);
}

class Grid extends StatelessWidget {
  final String title;
  final List<Item> items;
  const Grid({super.key, required this.title, required this.items});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 8), child: Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)))),
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: items
              .map((e) => Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    color: cs.surfaceContainerHighest.withOpacity(.5),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: e.onTap,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Icon(e.icon, size: 30, color: cs.primary),
                          Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        ]),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    ]);
  }
}
