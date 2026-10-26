import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class About extends StatelessWidget {
  const About({super.key});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    const upi = 'ayushku92sk@okicici';
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('About', style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      const Text('All In One is a free, minimal toolkit for images and PDFs. Everything runs on your device: no ads, no sign-up, no paid features.', style: TextStyle(height: 1.5)),
      const SizedBox(height: 16),
      const Text('Our mission: powerful tools should be free for everyone.', style: TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 24),
      const Text('This app is created by Ayush, with the help of Claude AI. Ayush is currently studying at IIEST Shibpur.\n\nThank you, Claude 💙', style: TextStyle(height: 1.5)),
      const SizedBox(height: 32),
      Text('Contribute', style: tt.titleLarge),
      const SizedBox(height: 8),
      const Text('If you like the app, you can support it with any UPI app (Google Pay, PhonePe, Paytm). Totally optional!'),
      const SizedBox(height: 16),
      Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: QrImageView(data: 'upi://pay?pa=$upi&pn=Ayush&cu=INR', size: 240, backgroundColor: Colors.white),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SelectableText(upi),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () {
            Clipboard.setData(const ClipboardData(text: upi));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI ID copied')));
          },
        ),
      ]),
      const SizedBox(height: 24),
      const Center(child: Text('Made in India 🇮🇳 ❤️', style: TextStyle(fontWeight: FontWeight.w600))),
    ]);
  }
}
