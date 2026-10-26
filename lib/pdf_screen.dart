import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'util.dart';

class PTool {
  final String name, k;
  final IconData icon;
  const PTool(this.name, this.k, this.icon);
}

const pdfTools = [
  PTool('Merge PDFs', 'merge', Icons.merge_type),
  PTool('Unlock PDF', 'unlock', Icons.lock_open),
  PTool('Protect PDF', 'protect', Icons.lock),
  PTool('Extract / Reorder', 'extract', Icons.content_cut),
  PTool('Split PDF', 'split', Icons.call_split),
  PTool('Rotate PDF', 'rotate', Icons.rotate_90_degrees_cw),
  PTool('Compress PDF', 'compress', Icons.compress),
  PTool('PDF to Text', 'p2t', Icons.text_snippet),
  PTool('Text to PDF', 't2p', Icons.edit_note),
  PTool('Image to PDF', 'i2p', Icons.picture_as_pdf),
  PTool('PDF to Images', 'p2i', Icons.photo_library),
];

List<int>? parseRange(String s) {
  final out = <int>[];
  for (final part in s.split(',')) {
    final x = part.trim().split('-');
    if (x.isEmpty || x[0].isEmpty) continue;
    final a = int.tryParse(x[0]), b = x.length > 1 ? int.tryParse(x[1]) : a;
    if (a == null || b == null) return null;
    for (var i = a; i <= b; i++) {
      out.add(i);
    }
  }
  return out.isEmpty ? null : out;
}

// Real PDF page copy: keeps text selectable (vector content preserved).
Future<Uint8List> sfBuild(List<(Uint8List, String?, List<int>?)> srcs) => Isolate.run(() async {
      final out = sf.PdfDocument();
      out.pageSettings.margins.all = 0;
      final docs = <sf.PdfDocument>[];
      for (final s in srcs) {
        final d = sf.PdfDocument(inputBytes: s.$1, password: s.$2);
        docs.add(d);
        final idx = s.$3 ?? List.generate(d.pages.count, (i) => i + 1);
        for (final n in idx) {
          if (n < 1 || n > d.pages.count) continue;
          final pg = d.pages[n - 1];
          out.pageSettings.size = pg.size;
          out.pages.add().graphics.drawPdfTemplate(pg.createTemplate(), Offset.zero, pg.size);
        }
      }
      final bytes = Uint8List.fromList(await out.save());
      out.dispose();
      for (final d in docs) {
        d.dispose();
      }
      return bytes;
    });

Future<Uint8List> sfEdit(Uint8List b, String? pass, void Function(sf.PdfDocument) f) async {
  final d = sf.PdfDocument(inputBytes: b, password: pass);
  f(d);
  final o = Uint8List.fromList(await d.save());
  d.dispose();
  return o;
}

Future<List<Uint8List>> pdfPages(String path, {String? pass, double scale = 2, int q = 88, List<int>? only}) async {
  final doc = await PdfDocument.openFile(path, passwordProvider: pass == null ? null : () => pass);
  final out = <Uint8List>[];
  final idx = only ?? List.generate(doc.pages.length, (i) => i + 1);
  for (final n in idx) {
    if (n < 1 || n > doc.pages.length) continue;
    final p = doc.pages[n - 1];
    final r = await p.render(fullWidth: p.width * scale, fullHeight: p.height * scale);
    if (r == null) continue;
    final w = r.width, h = r.height;
    final px = Uint8List.fromList(r.pixels);
    r.dispose();
    out.add(await Isolate.run(() {
      final im = img.Image.fromBytes(width: w, height: h, bytes: px.buffer, order: img.ChannelOrder.bgra, numChannels: 4);
      return Uint8List.fromList(img.encodeJpg(im, quality: q));
    }));
  }
  doc.dispose();
  return out;
}

Future<Uint8List> buildPdf(List<Uint8List> imgs) => Isolate.run(() async {
      final d = pw.Document();
      for (final b in imgs) {
        final m = pw.MemoryImage(b);
        d.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: pw.EdgeInsets.zero, build: (_) => pw.Center(child: pw.Image(m, fit: pw.BoxFit.contain))));
      }
      return Uint8List.fromList(await d.save());
    });

Future<Uint8List> textPdf(String t) => Isolate.run(() async {
      final d = pw.Document();
      d.addPage(pw.MultiPage(margin: const pw.EdgeInsets.all(36), build: (_) => [pw.Paragraph(text: t, style: const pw.TextStyle(fontSize: 12))]));
      return Uint8List.fromList(await d.save());
    });

class PdfPage extends StatefulWidget {
  final PTool t;
  const PdfPage({super.key, required this.t});
  @override
  State<PdfPage> createState() => _PdfPageState();
}

class _PdfPageState extends State<PdfPage> {
  List<String> paths = [];
  List<Uint8List> imgs = [];
  final pass = TextEditingController(), range = TextEditingController(), text = TextEditingController();
  String status = '';
  bool busy = false;
  String get k => widget.t.k;
  String? get pw0 => pass.text.isEmpty ? null : pass.text;

  Future<void> pick() async {
    if (k == 'i2p') {
      final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
      if (r != null) setState(() => imgs = r.files.where((f) => f.bytes != null).map((f) => f.bytes!).toList());
    } else {
      final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: k == 'merge');
      if (r != null) setState(() => paths = r.files.where((f) => f.path != null).map((f) => f.path!).toList());
    }
  }

  Future<void> run() async {
    setState(() {
      busy = true;
      status = 'Working…';
    });
    try {
      Uint8List out;
      String name = 'aio_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final first = paths.isEmpty ? null : await File(paths.first).readAsBytes();
      switch (k) {
        case 'merge':
          {
            final srcs = <(Uint8List, String?, List<int>?)>[];
            for (final p in paths) {
              srcs.add((await File(p).readAsBytes(), null, null));
            }
            out = await sfBuild(srcs);
            break;
          }
        case 'unlock':
          out = await sfBuild([(first!, pw0, null)]);
          break;
        case 'protect':
          if (pw0 == null) throw 'Password daalo';
          out = await sfEdit(first!, null, (d) {
            d.security.userPassword = pass.text;
            d.security.ownerPassword = pass.text;
          });
          break;
        case 'rotate':
          out = await sfEdit(first!, pw0, (d) {
            for (var i = 0; i < d.pages.count; i++) {
              d.pages[i].rotation = sf.PdfPageRotateAngle.rotateAngle90;
            }
          });
          break;
        case 'extract':
          {
            final pr = parseRange(range.text);
            if (pr == null) throw 'Pages likho, jaise 3,1,2 ya 1-3,5';
            out = await sfBuild([(first!, pw0, pr)]);
            break;
          }
        case 'split':
          {
            final cnt = sf.PdfDocument(inputBytes: first!, password: pw0);
            final n = cnt.pages.count;
            cnt.dispose();
            final za = Archive();
            for (var i = 1; i <= n; i++) {
              final one = await sfBuild([(first, pw0, [i])]);
              za.addFile(ArchiveFile('page_$i.pdf', one.length, one));
            }
            out = Uint8List.fromList(ZipEncoder().encode(za)!);
            name = name.replaceAll('.pdf', '.zip');
            break;
          }
        case 'compress':
          out = await buildPdf(await pdfPages(paths.first, pass: pw0, scale: 1.2, q: 55));
          break;
        case 'p2t':
          {
            final doc = await PdfDocument.openFile(paths.first, passwordProvider: pw0 == null ? null : () => pw0!);
            final sb = StringBuffer();
            for (final p in doc.pages) {
              final tx = await p.loadText();
              sb.writeln(tx?.fullText ?? '');
              sb.writeln('\n--- page ${p.pageNumber} ---\n');
            }
            doc.dispose();
            out = Uint8List.fromList(utf8.encode(sb.toString()));
            name = name.replaceAll('.pdf', '.txt');
            break;
          }
        case 't2p':
          out = await textPdf(text.text);
          break;
        case 'i2p':
          out = await buildPdf(imgs);
          break;
        default: // p2i
          {
            final pages = await pdfPages(paths.first, pass: pw0, scale: 2.5, q: 92);
            final a = Archive();
            for (var i = 0; i < pages.length; i++) {
              a.addFile(ArchiveFile('page_${i + 1}.jpg', pages[i].length, pages[i]));
            }
            out = Uint8List.fromList(ZipEncoder().encode(a)!);
            name = name.replaceAll('.pdf', '.zip');
          }
      }
      setState(() => status = 'Done ✓');
      if (mounted) await saveBytes(context, out, name);
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final needsFile = !['t2p', 'i2p'].contains(k);
    final needsPass = ['unlock', 'protect', 'rotate', 'extract', 'split', 'compress', 'p2t', 'p2i'].contains(k);
    final keepsText = ['merge', 'unlock', 'extract', 'split', 'rotate', 'protect'].contains(k);
    return Scaffold(
      appBar: AppBar(title: Text(widget.t.name)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        if (k != 't2p')
          OutlinedButton.icon(
            onPressed: pick,
            icon: const Icon(Icons.attach_file),
            label: Text(needsFile ? (paths.isEmpty ? 'PDF chuno' : '${paths.length} file(s) selected') : (imgs.isEmpty ? 'Images chuno' : '${imgs.length} image(s) selected')),
          ),
        const SizedBox(height: 12),
        if (needsPass) TextField(controller: pass, obscureText: true, decoration: InputDecoration(labelText: k == 'protect' ? 'New password' : 'PDF password (agar locked ho)', border: const OutlineInputBorder())),
        if (k == 'extract') ...[
          const SizedBox(height: 12),
          TextField(controller: range, decoration: const InputDecoration(labelText: 'Pages / order (e.g. 3,1,2 or 1-3,5)', border: OutlineInputBorder())),
        ],
        if (k == 't2p') TextField(controller: text, maxLines: 12, decoration: const InputDecoration(labelText: 'Text likho (English)', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton(onPressed: busy ? null : run, child: const Text('Run & Save')),
        const SizedBox(height: 12),
        if (busy) const LinearProgressIndicator(),
        Text(status),
        const SizedBox(height: 16),
        Text(keepsText ? 'Text select/copy hoga: pages original rehte hain.' : k == 'compress' ? 'Compress pages ko images banata hai (text select nahi hoga).' : k == 't2p' ? 'Hindi text ke liye: Text to Image banao, phir Image to PDF.' : '', style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}
