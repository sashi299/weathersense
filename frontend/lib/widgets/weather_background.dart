import 'dart:math';
import 'package:flutter/material.dart';

class WeatherBackground extends StatefulWidget {
  final String condition;
  final Widget child;

  const WeatherBackground({super.key, required this.condition, required this.child});

  @override
  State<WeatherBackground> createState() => _WeatherBackgroundState();
}

class _WeatherBackgroundState extends State<WeatherBackground> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _starController;
  final List<Particle> _particles = [];
  final List<Star> _stars = [];
  final Random _random = Random();
  double _lightningOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _starController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _initParticles();
    _initStars();
  }

  void _initParticles() {
    _particles.clear();
    int count = 0;
    if (widget.condition.contains('Rainy')) count = 100;
    if (widget.condition.contains('Thunderstorm')) count = 120;
    if (widget.condition.contains('Snowy')) count = 60;
    if (widget.condition.contains('Fog')) count = 10;

    for (int i = 0; i < count; i++) {
      _particles.add(Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.01 + _random.nextDouble() * 0.02,
        size: 1 + _random.nextDouble() * 2,
      ));
    }
  }

  void _initStars() {
    _stars.clear();
    for (int i = 0; i < 50; i++) {
      _stars.add(Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 0.5 + _random.nextDouble() * 1.5,
        twinkleSpeed: 0.5 + _random.nextDouble(),
      ));
    }
  }

  @override
  void didUpdateWidget(WeatherBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.condition != widget.condition) {
      _initParticles();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _starController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.condition.contains('Thunderstorm') && _random.nextDouble() > 0.985) {
      Future.delayed(Duration.zero, () {
        if (mounted) {
          setState(() => _lightningOpacity = 0.4);
          Future.delayed(const Duration(milliseconds: 80), () {
            if (mounted) setState(() => _lightningOpacity = 0.0);
          });
        }
      });
    }

    return Stack(
      children: [
        // Base Background Color
        Container(color: const Color(0xFF0B1220)),
        
        // Stars for Clear Night
        if (widget.condition.contains('Clear Night'))
          AnimatedBuilder(
            animation: _starController,
            builder: (context, _) => CustomPaint(
              painter: StarPainter(stars: _stars, progress: _starController.value),
              size: Size.infinite,
            ),
          ),

        // Sunny/Clear Glow
        if (widget.condition.contains('Sunny') || widget.condition.contains('Clear'))
          Positioned(
            top: -150,
            right: -150,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE8935A).withOpacity(0.08 + (_controller.value * 0.02)),
                        blurRadius: 150,
                        spreadRadius: 80,
                      )
                    ],
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFE8935A).withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // Cloudy Blobs
        if (widget.condition.contains('Cloudy') || widget.condition.contains('Overcast') || widget.condition.contains('Clouds'))
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => CustomPaint(
              painter: CloudPainter(progress: _controller.value, opacity: 0.04),
              size: Size.infinite,
            ),
          ),

        // Fog Layers
        if (widget.condition.contains('Fog') || widget.condition.contains('Mist'))
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => CustomPaint(
              painter: FogPainter(progress: _controller.value),
              size: Size.infinite,
            ),
          ),

        // Animated Particles (Rain/Snow)
        if (_particles.isNotEmpty)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: ParticlePainter(
                particles: _particles,
                condition: widget.condition,
                progress: _controller.value,
              ),
              size: Size.infinite,
            ),
          ),

        // Lightning Flash
        if (widget.condition.contains('Thunderstorm'))
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _lightningOpacity,
              duration: const Duration(milliseconds: 40),
              child: Container(color: Colors.white),
            ),
          ),

        widget.child,
      ],
    );
  }
}

class Particle {
  double x, y, speed, size;
  Particle({required this.x, required this.y, required this.speed, required this.size});
}

class Star {
  double x, y, size, twinkleSpeed;
  Star({required this.x, required this.y, required this.size, required this.twinkleSpeed});
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final String condition;
  final double progress;

  ParticlePainter({required this.particles, required this.condition, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = condition.contains('Snowy') ? Colors.white.withOpacity(0.5) : Colors.blue.withOpacity(0.3)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (var p in particles) {
      double currentY = (p.y + (progress * p.speed * 20)) % 1.0;
      double xPos = p.x * size.width;
      double yPos = currentY * size.height;

      if (condition.contains('Snowy')) {
        canvas.drawCircle(Offset(xPos, yPos), p.size, paint);
      } else if (condition.contains('Rainy') || condition.contains('Thunderstorm')) {
        canvas.drawLine(Offset(xPos, yPos), Offset(xPos, yPos + 12), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CloudPainter extends CustomPainter {
  final double progress;
  final double opacity;
  CloudPainter({required this.progress, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    for (int i = 0; i < 6; i++) {
      double x = (size.width * (i / 5) + (progress * 40)) % (size.width + 300) - 150;
      double y = 80.0 + (i * 50);
      canvas.drawCircle(Offset(x, y), 100 + (i * 15), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FogPainter extends CustomPainter {
  final double progress;
  FogPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    for (int i = 0; i < 4; i++) {
      double xOffset = sin(progress * 2 * pi + i) * 50;
      canvas.drawRect(
        Rect.fromLTWH(-100 + xOffset, size.height * (0.4 + i * 0.15), size.width + 200, 150),
        paint
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class StarPainter extends CustomPainter {
  final List<Star> stars;
  final double progress;
  StarPainter({required this.stars, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (var s in stars) {
      final opacity = 0.2 + (sin(progress * 2 * pi * s.twinkleSpeed) + 1) * 0.4;
      final paint = Paint()..color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
