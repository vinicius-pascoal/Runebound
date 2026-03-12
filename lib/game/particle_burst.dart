import 'dart:math';
import 'package:flutter/material.dart';

// Um único "esporo" de partícula.
class _Particle {
  _Particle({required this.color, required Random rng})
    : angle = rng.nextDouble() * 2 * pi,
      speed = rng.nextDouble() * 90 + 40,
      radius = rng.nextDouble() * 4 + 2,
      opacity = 1.0;

  final Color color;
  final double angle;
  final double speed;
  final double radius;
  double opacity;
}

class ParticleBurst extends StatefulWidget {
  const ParticleBurst({
    super.key,
    required this.color,
    required this.count,
    this.size = 80,
  });

  final Color color;
  final int count;
  final double size;

  @override
  State<ParticleBurst> createState() => _ParticleBurstState();
}

class _ParticleBurstState extends State<ParticleBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(
      widget.count,
      (_) => _Particle(color: widget.color, rng: rng),
    );
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 600),
        )..addListener(() {
          setState(() {
            for (final p in _particles) {
              p.opacity = (1.0 - _controller.value).clamp(0.0, 1.0);
            }
          });
        });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _ParticlePainter(
          particles: _particles,
          progress: _controller.value,
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.particles, required this.progress});

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (final p in particles) {
      final dist = p.speed * progress;
      final x = center.dx + cos(p.angle) * dist;
      final y = center.dy + sin(p.angle) * dist;
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), p.radius * (1 - progress * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
