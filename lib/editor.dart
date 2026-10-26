import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'util.dart';

const imageTools = <String, IconData>{
  'Resize': Icons.photo_size_select_large,
  'Compress': Icons.compress,
  'Enhance': Icons.auto_fix_high,
  'Upscale / 4K': Icons.zoom_out_map,
  'Remove BG': Icons.layers_clear,
  'Portrait': Icons.portrait,
  'Crop': Icons.crop,
  'Adjust': Icons.tune,
  'Rotate / Flip': Icons.rotate_90_degrees_cw,
  'Filters': Icons.filter_vintage,
  'Watermark': Icons.branding_watermark,
  'Border': Icons.border_outer,
  'Convert': Icons.swap_horiz,
};

img.Image _sharpen(img.Image im) =>
    img.convolution(im, filter: [0, -1, 0, -1, 5, -1, 0, -1, 0], div: 1);

Uint8List runOp(Uint8List b, String op, Map p) {
  var im = img.decodeImage(b)!;
  switch (op) {
    case 'resize':
      {
        var w = p['w'] as int?, h = p['h'] as int?;
        w ??= (h! * im.width / im.height).round();
        h ??= (w * im.height / im.width).round();
        im = img.copyResize(im, width: w, height: h, maintainAspect: false, interpolation: img.Interpolation.cubic);
        break;
      }
    case 'mlmask':
      {
        im = im.convert(numChannels: 4);
        final m = p['m'] as List<double>;
        final mw = p['mw'] as int, mh = p['mh'] as int;
        for (final px in im) {
          final fx = px.x / (im.width - 1) * (mw - 1), fy = px.y / (im.height - 1) * (mh - 1);
          final x0 = fx.floor(), y0 = fy.floor(), x1 = math.min(x0 + 1, mw - 1), y1 = math.min(y0 + 1, mh - 1);
          final tx = fx - x0, ty = fy - y0;
          final c = (m[y0 * mw + x0] * (1 - tx) + m[y0 * mw + x1] * tx) * (1 - ty) + (m[y1 * mw + x0] * (1 - tx) + m[y1 * mw + x1] * tx) * ty;
          px.a = (((c - .35) / .3).clamp(0.0, 1.0) * 255).round();
        }
        break;
      }
    case 'adjust':
      im = img.adjustColor(im, brightness: p['b'], contrast: p['c'], saturation: p['s']);
      break;
    case 'sketch':
      im = img.sketch(im);
      break;
    case 'pixel':
      im = img.pixelate(im, size: math.max(2, im.width ~/ 60));
      break;
    case 'vignette':
      im = img.vignette(im);
      break;
    case 'watermark':
      {
        final big = im.width > 1500;
        img.drawString(im, p['t'], font: big ? img.arial48 : img.arial24, x: 16, y: im.height - (big ? 64 : 36), color: img.ColorRgba8(255, 255, 255, 210));
        break;
      }
    case 'border':
      {
        final bw = p['w'] as int;
        final cv = img.Image(width: im.width + bw * 2, height: im.height + bw * 2);
        img.fill(cv, color: p['c'] == 'black' ? img.ColorRgb8(0, 0, 0) : img.ColorRgb8(255, 255, 255));
        img.compositeImage(cv, im, dstX: bw, dstY: bw);
        im = cv;
        break;
      }
    case 'passport':
      {
        var w = im.width, h = (w * 45 / 35).round();
        if (h > im.height) {
          h = im.height;
          w = (h * 35 / 45).round();
        }
        im = img.copyCrop(im, x: (im.width - w) ~/ 2, y: (im.height - h) ~/ 2, width: w, height: h);
        im = img.copyResize(im, width: 413, height: 531, interpolation: img.Interpolation.cubic);
        final bg = img.Image(width: 413, height: 531);
        img.fill(bg, color: img.ColorRgb8(255, 255, 255));
        img.compositeImage(bg, im);
        im = bg;
        break;
      }
    case 'upscale':
      final long = math.max(im.width, im.height);
      final target = p['f'] == 0 ? 3840 : long * (p['f'] as int);
      im = im.width >= im.height
          ? img.copyResize(im, width: target, interpolation: img.Interpolation.cubic)
          : img.copyResize(im, height: target, interpolation: img.Interpolation.cubic);
      im = _sharpen(im);
      break;
    case 'enhance':
      im = img.adjustColor(im, contrast: 1.12, saturation: 1.15, brightness: 1.04);
      im = _sharpen(im);
      break;
    case 'crop':
      final rw = p['rw'] as int, rh = p['rh'] as int;
      var w = im.width, h = (im.width * rh / rw).round();
      if (h > im.height) {
        h = im.height;
        w = (im.height * rw / rh).round();
      }
      im = img.copyCrop(im, x: (im.width - w) ~/ 2, y: (im.height - h) ~/ 2, width: w, height: h);
      break;
    case 'rotate':
      im = img.copyRotate(im, angle: p['a']);
      break;
    case 'flip':
      im = img.flip(im, direction: p['d'] == 'h' ? img.FlipDirection.horizontal : img.FlipDirection.vertical);
      break;
    case 'gray':
      im = img.grayscale(im);
      break;
    case 'sepia':
      im = img.sepia(im);
      break;
    case 'invert':
      im = img.invert(im);
      break;
    case 'blur':
      im = img.gaussianBlur(im, radius: 4);
      break;
    case 'removebg':
      im = im.convert(numChannels: 4);
      final cs = [im.getPixel(0, 0), im.getPixel(im.width - 1, 0), im.getPixel(0, im.height - 1), im.getPixel(im.width - 1, im.height - 1)];
      num r = 0, g = 0, bl = 0;
      for (final q in cs) {
        r += q.r;
        g += q.g;
        bl += q.b;
      }
      r /= 4;
      g /= 4;
      bl /= 4;
      final t = (p['tol'] as int).toDouble();
      for (final px in im) {
        final d = math.sqrt(math.pow(px.r - r, 2) + math.pow(px.g - g, 2) + math.pow(px.b - bl, 2));
        if (d < t) px.a = 0;
      }
      break;
  }
  return Uint8List.fromList(img.encodePng(im));
}

Uint8List encodeOut(Uint8List b, String fmt, int q, int kb) {
  final im = img.decodeImage(b)!;
  Uint8List enc(int qq) {
    switch (fmt) {
      case 'png':
        return Uint8List.fromList(img.encodePng(im));
      case 'bmp':
        return Uint8List.fromList(img.encodeBmp(im));
      case 'gif':
        return Uint8List.fromList(img.encodeGif(im));
      default:
        return Uint8List.fromList(img.encodeJpg(im, quality: qq));
    }
  }

  var out = enc(q);
  if (kb > 0 && fmt == 'jpg') {
    for (var qq = q; qq >= 8 && out.length > kb * 1024; qq -= 6) {
      out = enc(qq);
    }
  }
  return out;
}

class Editor extends StatefulWidget {
  final String tool;
  const Editor({super.key, required this.tool});
  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  late String tool = widget.tool;
  Uint8List? cur;
  final hist = <Uint8List>[];
  bool busy = false;
  final wC = TextEditingController(), hC = TextEditingController(), kbC = TextEditingController();
  double quality = 80, tol = 40;
  String fmt = 'jpg';
  int upF = 0;
  String ratio = '3:4';
  List<double> adj = [1.0, 1.0, 1.0];
  final wmC = TextEditingController(text: 'Made with All In One');
  int bw = 25;
  String bc = 'white';

  Future<void> pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (r == null || r.files.first.bytes == null) return;
    setState(() => busy = true);
    final raw = r.files.first.bytes!;
    final n = await Isolate.run(() => Uint8List.fromList(img.encodePng(img.bakeOrientation(img.decodeImage(raw)!))));
    setState(() {
      cur = n;
      hist.clear();
      busy = false;
    });
  }

  Future<void> apply(String op, Map p) async {
    if (cur == null) return toast(context, 'Pehle image chuno');
    setState(() => busy = true);
    try {
      final src = cur!;
      final out = await Isolate.run(() => runOp(src, op, p));
      hist.add(src);
      setState(() => cur = out);
    } catch (e) {
      if (mounted) toast(context, 'Error: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> aiBg() async {
    if (cur == null) return toast(context, 'Pehle image chuno');
    setState(() => busy = true);
    try {
      final f = File('${Directory.systemTemp.path}/aio_seg.png');
      await f.writeAsBytes(cur!);
      final seg = SelfieSegmenter(mode: SegmenterMode.single, enableRawSizeMask: true);
      final mask = await seg.processImage(InputImage.fromFilePath(f.path));
      await seg.close();
      if (mask == null) throw 'Person detect nahi hua';
      fmt = 'png';
      await apply('mlmask', {'m': mask.confidences, 'mw': mask.width, 'mh': mask.height});
    } catch (e) {
      if (mounted) toast(context, 'AI error: $e');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> save() async {
    if (cur == null) return;
    setState(() => busy = true);
    final src = cur!, f = fmt, q = quality.round(), kb = int.tryParse(kbC.text) ?? 0;
    final out = await Isolate.run(() => encodeOut(src, f, q, kb));
    if (mounted) {
      setState(() => busy = false);
      await saveBytes(context, out, 'aio_${DateTime.now().millisecondsSinceEpoch}.$f');
    }
  }

  Widget chips<T>(List<T> v, T sel, void Function(T) on, [String Function(T)? l]) => Wrap(
        spacing: 8,
        children: v.map((e) => ChoiceChip(label: Text(l?.call(e) ?? '$e'), selected: e == sel, onSelected: (_) => setState(() => on(e)))).toList(),
      );

  Widget panel() {
    switch (tool) {
      case 'Resize':
        return Column(children: [
          Wrap(spacing: 8, children: [for (final v in [1080, 1920, 3840]) ActionChip(label: Text('${v}px wide'), onPressed: () => setState(() { wC.text = '$v'; hC.clear(); }))]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: wC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Width px', border: OutlineInputBorder()))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: hC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height px', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 8),
          FilledButton(
              onPressed: () {
                final w = int.tryParse(wC.text), h = int.tryParse(hC.text);
                if (w == null && h == null) return toast(context, 'Width ya height daalo');
                apply('resize', {'w': w, 'h': h});
              },
              child: const Text('Apply')),
        ]);
      case 'Adjust':
        return Column(children: [
          for (var i = 0; i < 3; i++)
            Row(children: [
              SizedBox(width: 90, child: Text(['Brightness', 'Contrast', 'Saturation'][i])),
              Expanded(child: Slider(value: adj[i], min: .5, max: 1.5, onChanged: (v) => setState(() => adj[i] = v))),
            ]),
          FilledButton(
              onPressed: () {
                apply('adjust', {'b': adj[0], 'c': adj[1], 's': adj[2]});
                setState(() => adj = [1.0, 1.0, 1.0]);
              },
              child: const Text('Apply')),
        ]);
      case 'Watermark':
        return Column(children: [
          TextField(controller: wmC, decoration: const InputDecoration(labelText: 'Watermark text', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => apply('watermark', {'t': wmC.text}), child: const Text('Add watermark')),
        ]);
      case 'Border':
        return Column(children: [
          chips<int>([10, 25, 50, 90], bw, (v) => bw = v, (v) => '${v}px'),
          chips<String>(['white', 'black'], bc, (v) => bc = v),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => apply('border', {'w': bw, 'c': bc}), child: const Text('Add border')),
        ]);
      case 'Upscale / 4K':
        return Column(children: [
          chips<int>([2, 4, 0], upF, (v) => upF = v, (v) => v == 0 ? '4K' : '${v}x'),
          const SizedBox(height: 8),
          FilledButton(onPressed: () => apply('upscale', {'f': upF}), child: const Text('Upscale')),
        ]);
      case 'Enhance':
        return FilledButton(onPressed: () => apply('enhance', {}), child: const Text('Auto Enhance'));
      case 'Remove BG':
        return Column(children: [
          Text('Tolerance ${tol.round()}'),
          Slider(value: tol, min: 5, max: 120, onChanged: (v) => setState(() => tol = v)),
          FilledButton.icon(onPressed: aiBg, icon: const Icon(Icons.auto_awesome), label: const Text('AI Remove BG (people)')),
          OutlinedButton(onPressed: () { setState(() => fmt = 'png'); apply('removebg', {'tol': tol.round()}); }, child: const Text('Plain background mode')),
          const Text('Saves as PNG. Best on plain backgrounds.', style: TextStyle(fontSize: 12)),
        ]);
      case 'Portrait':
      case 'Crop':
        final list = tool == 'Portrait' ? ['3:4', '4:5', '9:16', '35:45'] : ['1:1', '4:3', '16:9', '3:2', '3:4'];
        return Column(children: [
          chips<String>(list, ratio, (v) => ratio = v),
          const SizedBox(height: 8),
          FilledButton(
              onPressed: () {
                final s = ratio.split(':');
                apply('crop', {'rw': int.parse(s[0]), 'rh': int.parse(s[1])});
              },
              child: const Text('Crop (center)')),
          if (tool == 'Portrait') OutlinedButton(onPressed: () => apply('passport', {}), child: const Text('Passport photo 35x45 (white bg)')),
        ]);
      case 'Rotate / Flip':
        return Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: () => apply('rotate', {'a': 90}), child: const Text('Rotate 90°')),
          OutlinedButton(onPressed: () => apply('rotate', {'a': 180}), child: const Text('180°')),
          OutlinedButton(onPressed: () => apply('flip', {'d': 'h'}), child: const Text('Flip H')),
          OutlinedButton(onPressed: () => apply('flip', {'d': 'v'}), child: const Text('Flip V')),
        ]);
      case 'Filters':
        return Wrap(spacing: 8, children: [
          for (final f in ['gray', 'sepia', 'invert', 'blur', 'sketch', 'pixel', 'vignette']) OutlinedButton(onPressed: () => apply(f, {}), child: Text(f)),
        ]);
      default: // Compress, Convert
        return Column(children: [
          chips<String>(['jpg', 'png', 'bmp', 'gif'], fmt, (v) => fmt = v, (v) => v.toUpperCase()),
          if (tool == 'Compress') ...[
            Text('Quality ${quality.round()}'),
            Slider(value: quality, min: 10, max: 100, onChanged: (v) => setState(() => quality = v)),
            TextField(controller: kbC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target size KB (optional, JPG)', border: OutlineInputBorder())),
          ],
          const Text('Format/quality tab Save dabate hi apply hoga.', style: TextStyle(fontSize: 12)),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tool), actions: [
        IconButton(icon: const Icon(Icons.folder_open), onPressed: pick),
        IconButton(icon: const Icon(Icons.undo), onPressed: hist.isEmpty ? null : () => setState(() => cur = hist.removeLast())),
        IconButton(icon: const Icon(Icons.save_alt), onPressed: cur == null || busy ? null : save),
      ]),
      body: Column(children: [
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: cur == null
              ? Center(child: FilledButton.icon(onPressed: pick, icon: const Icon(Icons.add_photo_alternate), label: const Text('Image chuno')))
              : InteractiveViewer(child: Center(child: Image.memory(cur!))),
        ),
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
            for (final e in imageTools.entries)
              Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(avatar: Icon(e.value, size: 18), label: Text(e.key), selected: tool == e.key, onSelected: (_) => setState(() => tool = e.key))),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), child: panel()),
      ]),
    );
  }
}
