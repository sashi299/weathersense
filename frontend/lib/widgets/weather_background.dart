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
  final List<Particle> _particles = [];
  final Random _random = Random();
  double _lightningOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _initParticles();
  }

  void _initParticles() {
    _particles.clear();
    int count = 0;
    if (widget.condition.contains('Rainy')) count = 100;
    if (widget.condition.contains('Thunderstorm')) count = 120;
    if (widget.condition.contains('Snowy')) count = 50;

    for (int i = 0; i < count; i++) {
      _particles.add(Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.01 + _random.nextDouble() * 0.02,
        size: 1 + _random.nextDouble() * 2,
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.condition.contains('Thunderstorm') && _random.nextDouble() > 0.98) {
      Future.delayed(Duration.zero, () {
        if (mounted) {
          setState(() => _lightningOpacity = 0.5);
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) setState(() => _lightningOpacity = 0.0);
          });
        }
      });
    }

    return Stack(
      children: [
        // Base Background Color
        Container(color: const Color(0xFF0B1220)),
        
        // Sunny/Clear Glow
        if (widget.condition.contains('Sunny') || widget.condition.contains('Clear'))
          Positioned(
            top: -100,
            right: -100,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE8935A).withOpacity(0.1 + (_controller.value * 0.05)),
                        blurRadius: 100,
                        spreadRadius: 50,
                      )
                    ],
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFE8935A).withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // Animated Particles (Rain/Snow)
        if (_particles.isNotEmpty)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: ParticlePainter(
                  particles: _particles,
                  condition: widget.condition,
                  progress: _controller.value,
                ),
                size: Size.infinite,
              );
            },
          ),

        // Cloudy Blobs
        if (widget.condition.contains('Cloudy') || widget.condition.contains('Overcast'))
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: CloudPainter(progress: _controller.value),
                size: Size.infinite,
              );
            },
          ),

        // Lightning Flash
        if (widget.condition.contains('Thunderstorm'))
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _lightningOpacity,
              duration: const Duration(milliseconds: 50),
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

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final String condition;
  final double progress;

  ParticlePainter({required this.particles, required this.condition, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = condition.contains('Snowy') ? Colors.white.withOpacity(0.6) : Colors.blue.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (var p in particles) {
      double currentY = (p.y + progress) % 1.0;
      double xPos = p.x * size.width;
      double yPos = currentY * size.height;

      if (condition.contains('Snowy')) {
        canvas.drawCircle(Offset(xPos, yPos), p.size, paint);
      } else {
        // Rain lines
        canvas.drawLine(
          Offset(xPos, yPos),
          Offset(xPos, yPos + 15),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CloudPainter extends CustomPainter {
  final double progress;
  CloudPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);

    for (int i = 0; i < 5; i++) {
      double x = (size.width * (i / 4) + (progress * 50)) % (size.width + 200) - 100;
      double y = 100.0 + (i * 40);
      canvas.drawCircle(Offset(x, y), 80 + (i * 20), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
