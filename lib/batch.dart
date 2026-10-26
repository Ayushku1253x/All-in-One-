import 'dart:isolate';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'util.dart';

Uint8List batchOne(Uint8List b, String fmt, int q, int mw) {
  var im = img.decodeImage(b)!;
  if (mw > 0 && im.width > mw) im = img.copyResize(im, width: mw, interpolation: img.Interpolation.cubic);
  switch (fmt) {
    case 'png':
      return Uint8List.fromList(img.encodePng(im));
    case 'bmp':
      return Uint8List.fromList(img.encodeBmp(im));
    default:
      return Uint8List.fromList(img.encodeJpg(im, quality: q));
  }
}

class BatchPage extends StatefulWidget {
  const BatchPage({super.key});
  @override
  State<BatchPage> createState() => _BatchPageState();
}

class _BatchPageState extends State<BatchPage> {
  List<PlatformFile> files = [];
  String fmt = 'jpg', status = '';
  double q = 75;
  final mw = TextEditingController();
  bool busy = false;

  Future<void> run() async {
    setState(() {
      busy = true;
      status = 'Working…';
    });
    try {
      final za = Archive();
      final w = int.tryParse(mw.text) ?? 0, qq = q.round(), f = fmt;
      for (var i = 0; i < files.length; i++) {
        final src = files[i].bytes!;
        final o = await Isolate.run(() => batchOne(src, f, qq, w));
        za.addFile(ArchiveFile('img_${i + 1}.$f', o.length, o));
        setState(() => status = '${i + 1}/${files.length}');
      }
      final z = Uint8List.fromList(ZipEncoder().encode(za)!);
      if (mounted) await saveBytes(context, z, 'aio_batch.zip');
      setState(() => status = 'Done ✓');
    } catch (e) {
      setState(() => status = 'Error: $e');
    }
    setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batch Convert / Compress')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        OutlinedButton.icon(
          onPressed: () async {
            final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true, withData: true);
            if (r != null) setState(() => files = r.files.where((x) => x.bytes != null).toList());
          },
          icon: const Icon(Icons.collections),
          label: Text(files.isEmpty ? 'Images chuno' : '${files.length} selected'),
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: [for (final v in ['jpg', 'png', 'bmp']) ChoiceChip(label: Text(v.toUpperCase()), selected: fmt == v, onSelected: (_) => setState(() => fmt = v))]),
        Text('JPG quality ${q.round()}'),
        Slider(value: q, min: 10, max: 100, onChanged: (v) => setState(() => q = v)),
        TextField(controller: mw, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max width px (optional)', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton(onPressed: busy || files.isEmpty ? null : run, child: const Text('Run & Save ZIP')),
        const SizedBox(height: 12),
        if (busy) const LinearProgressIndicator(),
        Text(status),
      ]),
    );
  }
}
