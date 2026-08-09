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
  late AnimationController _fadeController;
  
  final List<Particle> _particles = [];
  final List<Star> _stars = [];
  final Random _random = Random();
  
  double _lightningOpacity = 0.0;
  String _previousCondition = '';
  String _currentCondition = '';

  @override
  void initState() {
    super.initState();
    _currentCondition = widget.condition;
    _previousCondition = widget.condition;

    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
    _starController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();

    _initParticles();
    _initStars();
  }

  void _initParticles() {
    _particles.clear();
    int count = 0;
    final cond = _currentCondition.toUpperCase();
    if (cond.contains('RAIN') || cond.contains('DRIZZLE')) count = 120;
    if (cond.contains('THUNDERSTORM')) count = 150;
    if (cond.contains('SNOW')) count = 80;
    if (cond.contains('FOG') || cond.contains('MIST') || cond.contains('HAZE') || cond.contains('ATMOSPHERE')) count = 15;

    for (int i = 0; i < count; i++) {
      _particles.add(Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.005 + _random.nextDouble() * 0.025,
        size: 0.8 + _random.nextDouble() * 2.5,
      ));
    }
  }

  void _initStars() {
    _stars.clear();
    for (int i = 0; i < 80; i++) {
      _stars.add(Star(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 0.3 + _random.nextDouble() * 1.8,
        twinkleSpeed: 0.4 + _random.nextDouble() * 1.2,
      ));
    }
  }

  @override
  void didUpdateWidget(WeatherBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.condition != widget.condition) {
      _previousCondition = oldWidget.condition;
      _currentCondition = widget.condition;
      _fadeController.reset();
      _fadeController.forward();
      _initParticles();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _starController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentCondition.contains('Thunderstorm') && _random.nextDouble() > 0.99) {
      Future.delayed(Duration.zero, () {
        if (mounted) {
          setState(() => _lightningOpacity = 0.3);
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) setState(() => _lightningOpacity = 0.0);
          });
        }
      });
    }

    return Stack(
      children: [
        // Base Ambient Gradient
        _buildAmbientLayer(_previousCondition),
        
        // Transition Overlay
        FadeTransition(
          opacity: _fadeController,
          child: _buildAmbientLayer(_currentCondition),
        ),

        // Deep Space Layer (Stars)
        if (_currentCondition.contains('Night'))
          AnimatedBuilder(
            animation: _starController,
            builder: (context, _) => CustomPaint(
              painter: StarPainter(stars: _stars, progress: _starController.value),
              size: Size.infinite,
            ),
          ),

        // Sun / Moon / Atmosphere
        _buildAtmosphericEffect(_currentCondition),

        // Dynamic Particles (Rain, Snow, Fog)
        if (_particles.isNotEmpty)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: ParticlePainter(
                particles: _particles,
                condition: _currentCondition,
                progress: _controller.value,
              ),
              size: Size.infinite,
            ),
          ),

        // Flash Effect
        if (_currentCondition.contains('Thunderstorm'))
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _lightningOpacity,
              duration: const Duration(milliseconds: 50),
              child: Container(color: Colors.white.withValues(alpha: 0.8)),
            ),
          ),

        // The actual UI
        widget.child,
      ],
    );
  }

  Widget _buildAmbientLayer(String condition) {
    final colors = _getAmbientColors(condition);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
    );
  }

  List<Color> _getAmbientColors(String condition) {
    final cond = condition.toUpperCase();
    if (cond.contains('SUNNY') || cond.contains('CLEAR')) {
      return cond.contains('NIGHT') 
        ? [const Color(0xFF040812), const Color(0xFF0B1220)] 
        : [const Color(0xFF1E3A5F), const Color(0xFF0B1220)];
    }
    if (cond.contains('RAIN') || cond.contains('THUNDERSTORM') || cond.contains('DRIZZLE')) {
      return [const Color(0xFF0F172A), const Color(0xFF020617)];
    }
    if (cond.contains('CLOUD') || cond.contains('OVERCAST') || cond.contains('FOG') || cond.contains('MIST') || cond.contains('HAZE') || cond.contains('ATMOSPHERE')) {
      return [const Color(0xFF1E293B), const Color(0xFF0F172A)];
    }
    return [const Color(0xFF0B1220), const Color(0xFF020617)];
  }

  Widget _buildAtmosphericEffect(String condition) {
    final cond = condition.toUpperCase();
    bool isDay = !cond.contains('NIGHT');
    
    if (cond.contains('SUNNY') || cond.contains('CLEAR') || cond.contains('PARTLY CLOUDY') || cond.contains('MAINLY CLEAR')) {
      return Positioned(
        top: isDay ? -200 : -100,
        right: isDay ? -200 : 0,
        left: isDay ? null : 0,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            double pulse = sin(_controller.value * 2 * pi) * 0.05;
            return Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isDay 
                    ? [const Color(0xFFE8935A).withValues(alpha: 0.15 + pulse), Colors.transparent]
                    : [const Color(0xFF94A3B8).withValues(alpha: 0.1 + pulse), Colors.transparent],
                ),
              ),
            );
          }
        ),
      );
    }
    
    if (cond.contains('CLOUD') || cond.contains('OVERCAST')) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: CloudPainter(progress: _controller.value, isDay: isDay),
          size: Size.infinite,
        ),
      );
    }

    return const SizedBox.shrink();
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
    final cond = condition.toUpperCase();
    final paint = Paint()
      ..color = cond.contains('SNOW') ? Colors.white.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (var p in particles) {
      double currentY = (p.y + (progress * p.speed * 40)) % 1.0;
      double xPos = p.x * size.width;
      double yPos = currentY * size.height;

      if (cond.contains('SNOW')) {
        canvas.drawCircle(Offset(xPos, yPos), p.size, paint);
      } else if (cond.contains('RAIN') || cond.contains('THUNDERSTORM') || cond.contains('DRIZZLE')) {
        // Rain - slanted lines
        canvas.drawLine(Offset(xPos, yPos), Offset(xPos - 2, yPos + 15), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CloudPainter extends CustomPainter {
  final double progress;
  final bool isDay;
  CloudPainter({required this.progress, required this.isDay});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDay ? Colors.white.withValues(alpha: 0.06) : Colors.blueGrey.withValues(alpha: 0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    for (int i = 0; i < 5; i++) {
      double x = (size.width * (i / 4) + (progress * 30)) % (size.width + 400) - 200;
      double y = 100.0 + (i * 80);
      canvas.drawCircle(Offset(x, y), 150 + (i * 20), paint);
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
      final opacity = 0.1 + (sin(progress * 2 * pi * s.twinkleSpeed) + 1) * 0.4;
      final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
