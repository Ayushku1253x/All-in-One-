import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'pdf_screen.dart';
import 'util.dart';

class OcrPage extends StatefulWidget {
  const OcrPage({super.key});
  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> {
  bool deva = true, busy = false;
  String text = '', status = '';

  Future<void> run() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'pdf']);
    if (r == null || r.files.first.path == null) return;
    setState(() {
      busy = true;
      text = '';
      status = 'Reading…';
    });
    final rec = TextRecognizer(script: deva ? TextRecognitionScript.devanagiri : TextRecognitionScript.latin);
    try {
      final path = r.files.first.path!;
      final files = <String>[];
      if (path.toLowerCase().endsWith('.pdf')) {
        final dir = await Directory.systemTemp.createTemp('ocr');
        final pages = await pdfPages(path, scale: 2.5, q: 92);
        for (var i = 0; i < pages.length; i++) {
          final f = File('${dir.path}/p$i.jpg');
          await f.writeAsBytes(pages[i]);
          files.add(f.path);
        }
      } else {
        files.add(path);
      }
      final sb = StringBuffer();
      for (var i = 0; i < files.length; i++) {
        setState(() => status = 'Page ${i + 1}/${files.length}');
        final t = await rec.processImage(InputImage.fromFilePath(files[i]));
        sb.writeln(t.text);
        if (files.length > 1) sb.writeln('\n--- page ${i + 1} ---\n');
      }
      setState(() {
        text = sb.toString().trim();
        status = text.isEmpty ? 'Koi text nahi mila' : 'Done ✓';
      });
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
    await rec.close();
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR - Image/PDF to Text')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Wrap(spacing: 8, children: [
          ChoiceChip(label: const Text('Hindi / Maithili / Bhojpuri + English'), selected: deva, onSelected: (_) => setState(() => deva = true)),
          ChoiceChip(label: const Text('English only'), selected: !deva, onSelected: (_) => setState(() => deva = false)),
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: busy ? null : run, icon: const Icon(Icons.document_scanner), label: const Text('Image / PDF chuno')),
        const SizedBox(height: 8),
        if (busy) const LinearProgressIndicator(),
        Text(status),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: SelectableText(text, style: const TextStyle(fontSize: 16, height: 1.5)))),
          Row(children: [
            TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  toast(context, 'Copied');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy')),
            TextButton.icon(onPressed: () => saveBytes(context, Uint8List.fromList(utf8.encode(text)), 'ocr_${DateTime.now().millisecondsSinceEpoch}.txt'), icon: const Icon(Icons.save_alt), label: const Text('Save .txt')),
          ]),
        ],
      ]),
    );
  }
}
