import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:weather_sense/providers/weather_provider.dart';
import 'package:weather_sense/screens/analytics_screen.dart';
import 'package:weather_sense/screens/forecast_screen.dart';
import 'package:weather_sense/screens/search_screen.dart';
import 'package:weather_sense/screens/settings_screen.dart';
import 'package:weather_sense/widgets/weather_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final provider = context.read<WeatherProvider>();
      await provider.loadSettings();
      await provider.loadWeather(provider.lastCity);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          final weather = provider.currentWeather;
          final forecast = provider.forecast;
          final condition = weather?['condition']?.toString() ?? 'Clear';

          return WeatherBackground(
            condition: condition,
            child: SafeArea(
              child: RefreshIndicator(
                color: const Color(0xFF3FA9A0),
                backgroundColor: const Color(0xFF111727),
                onRefresh: () => provider.loadWeather(provider.currentWeather?['city']?.toString() ?? provider.lastCity),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildAppBar(context, weather),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHero(weather, provider),
                            const SizedBox(height: 32),
                            _buildInstrumentPanel(weather),
                            const SizedBox(height: 32),
                            _buildActionRow(context),
                            const SizedBox(height: 32),
                            _buildSolarLunarPanel(weather),
                            const SizedBox(height: 32),
                            _buildSignalWindow(forecast, provider),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, Map<String, dynamic>? weather) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      floating: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (weather?['city'] ?? 'WeatherSense').toString().toUpperCase(),
            style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 2, color: const Color(0xFF3FA9A0)),
          ),
          Text(
            _getFormattedDate(),
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
          icon: const Icon(Icons.location_searching_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHero(Map<String, dynamic>? weather, WeatherProvider provider) {
    if (weather == null) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    
    final tempRaw = weather['temperature_c'];
    final temp = tempRaw != null ? provider.convertTemp((tempRaw as num).toDouble()) : 0.0;
    final condition = weather['condition'] ?? 'Unknown';
    final description = weather['description'] ?? 'Atmospheric conditions';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${temp.toStringAsFixed(0)}°',
              style: GoogleFonts.spaceGrotesk(fontSize: 100, fontWeight: FontWeight.bold, color: Colors.white, height: 1.1),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20, left: 4),
              child: Text(
                provider.tempUnit,
                style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w300, color: const Color(0xFF3FA9A0)),
              ),
            ),
            const Spacer(),
            Icon(_getConditionIcon(condition), size: 64, color: Colors.white),
          ],
        ),
        Text(
          condition.toString().toUpperCase(),
          style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 4, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          description.toString(),
          style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _miniHeroStat('HUMIDITY', '${weather['humidity']}%'),
            _verticalDivider(),
            _miniHeroStat('WIND', '${weather['wind_speed']} m/s'),
            _verticalDivider(),
            _miniHeroStat('PRESSURE', '${weather['pressure']} hPa'),
          ],
        ),
      ],
    );
  }

  Widget _miniHeroStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w900, letterSpacing: 1)),
        Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 20,
      width: 1,
      color: Colors.white10,
      margin: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Widget _buildInstrumentPanel(Map<String, dynamic>? weather) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('INSTRUMENT PANEL'),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.6,
          children: [
            _instrumentCard('UV INDEX', '${weather?['uv_index'] ?? '--'}', Icons.wb_sunny_outlined, const Color(0xFFE8935A)),
            _instrumentCard('AIR QUALITY', '${weather?['air_quality'] ?? '--'}', Icons.air_rounded, const Color(0xFF3FA9A0)),
            _instrumentCard('VISIBILITY', '10 km', Icons.visibility_outlined, const Color(0xFF94A3B8)),
            _instrumentCard('DEW POINT', '21°', Icons.water_drop_outlined, const Color(0xFF4FA8FF)),
          ],
        ),
      ],
    );
  }

  Widget _instrumentCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111727).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
              Icon(icon, size: 14, color: color),
            ],
          ),
          Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      children: [
        _miniAction('Forecast', Icons.timeline_rounded, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForecastScreen()))),
        const SizedBox(width: 12),
        _miniAction('AI Analytics', Icons.auto_graph_rounded, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalyticsScreen()))),
        const SizedBox(width: 12),
        _miniAction('Settings', Icons.tune_rounded, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))),
      ],
    );
  }

  Widget _miniAction(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF111727).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF3FA9A0).withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF3FA9A0), size: 20),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSolarLunarPanel(Map<String, dynamic>? weather) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _sectionHeader('SOLAR & LUNAR'),
            const SizedBox(width: 8),
            const Icon(Icons.wb_twilight_rounded, size: 14, color: Color(0xFF3FA9A0)),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF111727).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              _buildSolarTimeline(weather),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Divider(color: Colors.white10),
              ),
              _buildLunarCycle(weather),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSolarTimeline(Map<String, dynamic>? weather) {
    final sunrise = weather?['sunrise'] ?? '06:00';
    final sunset = weather?['sunset'] ?? '18:00';
    
    // Parse times for position calculation
    double progress = 0.0;
    try {
      final now = DateTime.now();
      final sunriseParts = sunrise.split(':');
      final sunsetParts = sunset.split(':');
      
      final sr = DateTime(now.year, now.month, now.day, int.parse(sunriseParts[0]), int.parse(sunriseParts[1]));
      final ss = DateTime(now.year, now.month, now.day, int.parse(sunsetParts[0]), int.parse(sunsetParts[1]));
      
      if (now.isBefore(sr)) {
        progress = 0.0;
      } else if (now.isAfter(ss)) {
        progress = 1.0;
      } else {
        final totalDaylight = ss.difference(sr).inMinutes;
        final elapsed = now.difference(sr).inMinutes;
        progress = (elapsed / totalDaylight).clamp(0.0, 1.0);
      }
    } catch (_) {}

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: CustomPaint(
            painter: SolarArcPainter(
              progress: progress,
              sunrise: sunrise,
              sunset: sunset,
            ),
            size: Size.infinite,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _timePoint('Sunrise', sunrise, Icons.wb_twilight_rounded, const Color(0xFFE8935A)),
            _timePoint('Sunset', sunset, Icons.nights_stay_rounded, const Color(0xFF4B427B)),
          ],
        ),
      ],
    );
  }

  Widget _timePoint(String label, String time, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w900)),
            Text(time, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ],
    );
  }

  Widget _buildLunarCycle(Map<String, dynamic>? weather) {
    final phase = weather?['moon_phase'] ?? 'Unknown';
    final ill = weather?['moon_illumination'] ?? '--';
    final rise = weather?['moonrise'] ?? '--:--';
    final set = weather?['moonset'] ?? '--:--';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _getMoonPhaseVisual(phase),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(phase.toString().toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                    Text('Illumination: $ill%', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _moonTimeTile('MOONRISE', rise, Icons.vertical_align_top_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _moonTimeTile('MOONSET', set, Icons.vertical_align_bottom_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _moonTimeTile(String label, String time, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.w900)),
              Text(time, style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _getMoonPhaseVisual(String phase) {
    IconData icon = Icons.brightness_3_rounded;
    if (phase.contains('Full')) icon = Icons.brightness_1_rounded;
    if (phase.contains('New')) icon = Icons.radio_button_unchecked_rounded;
    
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ],
      ),
      child: Icon(icon, size: 30, color: Colors.white.withValues(alpha: 0.9)),
    );
  }

  Widget _buildSignalWindow(Map<String, dynamic>? forecast, WeatherProvider provider) {
    final items = (forecast?['forecast'] as List<dynamic>?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('ATMOSPHERIC SIGNAL'),
        const SizedBox(height: 16),
        Container(
          height: 220,
          padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF111727).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
          ),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(items.length > 24 ? 24 : items.length, (index) {
                    final tempCelsius = ((items[index] as Map<String, dynamic>?)?['temp'] ?? 0).toDouble();
                    return FlSpot(index.toDouble(), provider.convertTemp(tempCelsius));
                  }),
                  isCurved: true,
                  color: const Color(0xFF3FA9A0),
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true, 
                    gradient: LinearGradient(
                      colors: [const Color(0xFF3FA9A0).withValues(alpha: 0.3), Colors.transparent],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title, 
      style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2, color: const Color(0xFF3FA9A0))
    );
  }

  IconData _getConditionIcon(String condition) {
    if (condition.contains('Rainy') || condition.contains('Drizzle')) return Icons.umbrella_rounded;
    if (condition.contains('Thunderstorm')) return Icons.bolt_rounded;
    if (condition.contains('Cloudy') || condition.contains('Fog') || condition.contains('Mist') || condition.contains('Haze')) return Icons.cloud_rounded;
    if (condition.contains('Clear Night')) return Icons.nights_stay_rounded;
    return Icons.wb_sunny_rounded;
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]}'.toUpperCase();
  }
}

class SolarArcPainter extends CustomPainter {
  final double progress;
  final String sunrise;
  final String sunset;

  SolarArcPainter({required this.progress, required this.sunrise, required this.sunset});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width * 0.45;
    
    // 1. Draw the Arc Path
    final arcPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final dashPath = Path();
    for (double i = pi; i <= 2 * pi; i += 0.1) {
      dashPath.addArc(Rect.fromCircle(center: center, radius: radius), i, 0.05);
    }
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi, pi, false, arcPaint);

    // 2. Draw Progress Arc
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE8935A), Color(0xFF4B427B)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi, pi * progress, false, progressPaint);

    // 3. Draw the Sun Marker
    final angle = pi + (pi * progress);
    final sunX = center.dx + radius * cos(angle);
    final sunY = center.dy + radius * sin(angle);
    final sunPos = Offset(sunX, sunY);

    // Sun Glow
    final sunGlowPaint = Paint()
      ..color = const Color(0xFFE8935A).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawCircle(sunPos, 12, sunGlowPaint);

    final sunPaint = Paint()..color = Colors.white;
    canvas.drawCircle(sunPos, 5, sunPaint);
    
    // 4. Horizon line
    final horizonPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), horizonPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
