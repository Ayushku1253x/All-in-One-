import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

void toast(BuildContext c, String m) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
}

Future<void> saveBytes(BuildContext c, Uint8List b, String name) async {
  try {
    final p = await FilePicker.platform.saveFile(fileName: name, bytes: b);
    if (c.mounted) toast(c, p == null ? 'Cancelled' : 'Saved ✓');
  } catch (e) {
    if (c.mounted) toast(c, 'Save failed: $e');
  }
}
