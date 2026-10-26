import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'util.dart';

const fonts = [
  'Noto Sans Devanagari', 'Noto Serif Devanagari', 'Hind', 'Mukta', 'Kalam', 'Tiro Devanagari Hindi', 'Yatra One', 'Amita',
  'Baloo 2', 'Rozha One', 'Sahitya', 'Laila', 'Eczar', 'Khand', 'Karma', 'Modak', 'Poppins',
];
const palette = [Colors.black, Colors.white, Color(0xFF4F46E5), Color(0xFFDC2626), Color(0xFF16A34A), Color(0xFFF59E0B), Color(0xFF0EA5E9), Colors.transparent];

class TextImagePage extends StatefulWidget {
  const TextImagePage({super.key});
  @override
  State<TextImagePage> createState() => _TextImagePageState();
}

class _TextImagePageState extends State<TextImagePage> {
  final ctl = TextEditingController(text: 'नमस्ते दुनिया!\nHello World 🙏');
  final key = GlobalKey();
  String font = fonts.first;
  double size = 44;
  Color fg = Colors.black, bg = Colors.white;
  bool bold = false;
  TextAlign al = TextAlign.center;

  TextStyle style() {
    try {
      return GoogleFonts.getFont(font, fontSize: size, color: fg, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, height: 1.45);
    } catch (_) {
      return TextStyle(fontSize: size, color: fg, fontWeight: bold ? FontWeight.w700 : FontWeight.w400);
    }
  }

  Widget colors(Color sel, void Function(Color) on) => Wrap(spacing: 8, children: [
        for (final c in palette)
          GestureDetector(
            onTap: () => setState(() => on(c)),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: c == Colors.transparent ? null : c, shape: BoxShape.circle, border: Border.all(width: c == sel ? 3 : 1, color: c == sel ? Theme.of(context).colorScheme.primary : Colors.grey)),
              child: c == Colors.transparent ? const Icon(Icons.block, size: 18) : null,
            ),
          ),
      ]);

  Future<void> save() async {
    try {
      await GoogleFonts.pendingFonts();
      await Future.delayed(const Duration(milliseconds: 200));
      final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final im = await b.toImage(pixelRatio: 4);
      final d = await im.toByteData(format: ui.ImageByteFormat.png);
      if (mounted) await saveBytes(context, d!.buffer.asUint8List(), 'text_${DateTime.now().millisecondsSinceEpoch}.png');
    } catch (e) {
      if (mounted) toast(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Text to Image'), actions: [IconButton(icon: const Icon(Icons.save_alt), onPressed: save)]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(.4)), borderRadius: BorderRadius.circular(12)),
          child: FittedBox(
            child: RepaintBoundary(
              key: key,
              child: Container(width: 360, color: bg, padding: const EdgeInsets.all(28), child: Text(ctl.text, textAlign: al, style: style())),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(controller: ctl, maxLines: 4, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Text (Hindi / English / Maithili / Bhojpuri)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        const Text('Font'),
        Wrap(spacing: 8, children: [for (final f in fonts) ChoiceChip(label: Text(f), selected: f == font, onSelected: (_) => setState(() => font = f))]),
        Text('Size ${size.round()}'),
        Slider(value: size, min: 16, max: 120, onChanged: (v) => setState(() => size = v)),
        Row(children: [
          FilterChip(label: const Text('Bold'), selected: bold, onSelected: (v) => setState(() => bold = v)),
          const SizedBox(width: 8),
          for (final a in [TextAlign.left, TextAlign.center, TextAlign.right])
            IconButton(icon: Icon(a == TextAlign.left ? Icons.format_align_left : a == TextAlign.center ? Icons.format_align_center : Icons.format_align_right), isSelected: al == a, onPressed: () => setState(() => al = a)),
        ]),
        const Text('Text color'),
        const SizedBox(height: 6),
        colors(fg, (c) => fg = c),
        const SizedBox(height: 12),
        const Text('Background'),
        const SizedBox(height: 6),
        colors(bg, (c) => bg = c),
        const SizedBox(height: 12),
        const Text('Fonts pehli baar internet se download hote hain, phir cache ho jaate hain.', style: TextStyle(fontSize: 12)),
      ]),
    );
  }
}
