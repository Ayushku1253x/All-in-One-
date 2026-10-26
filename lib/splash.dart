import 'package:flutter/material.dart';
import 'main.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward();

  Animation<double> iv(double a, double b, [Curve k = Curves.easeOut]) => CurvedAnimation(parent: c, curve: Interval(a, b, curve: k));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3400), () {
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 600),
            pageBuilder: (_, __, ___) => const Home(),
            transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
          ));
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const Spacer(flex: 3),
          ScaleTransition(
            scale: iv(0, .55, Curves.elasticOut),
            child: RotationTransition(
              turns: Tween(begin: -.25, end: 0.0).animate(iv(0, .55, Curves.easeOutBack)),
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(36),
                  gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF9333EA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: cs.primary.withOpacity(.4), blurRadius: 40, offset: const Offset(0, 16))],
                ),
                child: const Icon(Icons.auto_awesome_mosaic_rounded, size: 68, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 28),
          FadeTransition(opacity: iv(.45, .75), child: Text('All In One', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: .5))),
          const SizedBox(height: 12),
          FadeTransition(
            opacity: iv(.65, .95),
            child: SlideTransition(
              position: Tween(begin: const Offset(0, .6), end: Offset.zero).animate(iv(.65, .95)),
              child: Text('Created by Ayush!! 🎉', style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          const Spacer(flex: 3),
          FadeTransition(opacity: iv(.8, 1), child: const Text('Made in India 🇮🇳 ❤️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          const SizedBox(height: 28),
        ]),
      ),
    );
  }
}
