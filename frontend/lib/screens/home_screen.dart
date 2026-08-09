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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    Future.microtask(() async {
      if (!mounted) return;
      final provider = context.read<WeatherProvider>();
      await provider.loadSettings();
      await provider.loadWeather(provider.lastCity);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          final weather = provider.currentWeather;
          final forecast = provider.forecast;
          final condition = weather?['condition']?.toString() ?? 'Clear';

          return WeatherBackground(
            condition: condition,
            child: RefreshIndicator(
              onRefresh: () => provider.loadWeather(provider.currentWeather?['city']?.toString() ?? provider.lastCity),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHero(weather, provider)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildQuickStats(weather),
                        const SizedBox(height: 18),
                        _buildActionRow(context),
                        const SizedBox(height: 18),
                        if (provider.isLoading) ...[
                          _buildSkeleton(),
                        ] else if (provider.errorMessage.isNotEmpty) ...[
                          _buildErrorState(provider.errorMessage),
                        ] else ...[
                          _buildMiniForecast(forecast),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHero(Map<String, dynamic>? weather, WeatherProvider provider) {
    if (weather == null && provider.isLoading) {
      return _buildSkeleton();
    }
    
    final temperatureRaw = weather?['temperature_c'];
    final temperature = temperatureRaw != null ? provider.convertTemp((temperatureRaw as num).toDouble()) : null;
    final condition = weather?['condition'] ?? (provider.isLoading ? 'Connecting...' : 'No Data');
    final city = weather?['city'] ?? (provider.isLoading ? 'Loading...' : 'Select City');
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(35),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6B5B95).withOpacity(0.9),
            const Color(0xFFE8935A).withOpacity(0.8),
            const Color(0xFF0B1220).withOpacity(0.4)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(city, style: GoogleFonts.spaceGrotesk(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Text(
                      _getFormattedDate(),
                      style: const TextStyle(color: Color(0xB0F2F0EA), fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())),
                  icon: const Icon(Icons.search_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(temperature != null ? '${temperature.toStringAsFixed(0)}${provider.tempUnit}' : '--${provider.tempUnit}', 
                    style: GoogleFonts.spaceGrotesk(fontSize: 82, fontWeight: FontWeight.bold, height: 1.0)),
                  Text(condition, style: const TextStyle(color: Color(0xFFF2F0EA), fontSize: 20, fontWeight: FontWeight.w300, letterSpacing: 1.0)),
                ],
              ),
              // Large dynamic icon
              Icon(_getLargeIcon(condition), size: 100, color: Colors.white.withOpacity(0.9)),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _heroStat(Icons.water_drop_outlined, '${weather?['humidity'] ?? '--'}%', 'Humidity'),
                _heroStat(Icons.air, '${weather?['wind_speed'] ?? '--'}m/s', 'Wind'),
                _heroStat(Icons.speed, '${weather?['pressure'] ?? '--'}', 'hPa'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF3FA9A0)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0x70F2F0EA))),
      ],
    );
  }

  IconData _getLargeIcon(String condition) {
    if (condition.contains('Rainy')) return Icons.umbrella_rounded;
    if (condition.contains('Thunderstorm')) return Icons.bolt_rounded;
    if (condition.contains('Cloudy') || condition.contains('Overcast')) return Icons.cloud_rounded;
    if (condition.contains('Clear Night')) return Icons.nights_stay_rounded;
    return Icons.wb_sunny_rounded;
  }

  Widget _buildQuickStats(Map<String, dynamic>? weather) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('INSTRUMENT PANEL', 
            style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2, color: const Color(0xFF3FA9A0))),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.4,
          children: [
            _statCard('UV INDEX', '${weather?['uv_index'] ?? '--'}', Icons.wb_sunny_outlined, const Color(0xFFFFB74D)),
            _statCard('AIR QUALITY', '${weather?['air_quality'] ?? '--'}', Icons.air_outlined, const Color(0xFF81C784)),
            _statCard('SUNRISE', weather?['sunrise'] ?? '--:--', Icons.wb_twilight, const Color(0xFF64B5F6)),
            _statCard('SUNSET', weather?['sunset'] ?? '--:--', Icons.nights_stay_outlined, const Color(0xFF9575CD)),
          ],
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _actionButton('Forecast', Icons.timeline_rounded, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForecastScreen())))),
        const SizedBox(width: 12),
        Expanded(child: _actionButton('Analytics', Icons.auto_graph_rounded, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalyticsScreen())))),
        const SizedBox(width: 12),
        Expanded(child: _actionButton('Settings', Icons.settings_input_component_rounded, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())))),
      ],
    );
  }

  Widget _buildMiniForecast(Map<String, dynamic>? forecast) {
    final items = (forecast?['forecast'] as List<dynamic>?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Signal window', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(items.length, (index) {
                    final tempCelsius = ((items[index] as Map<String, dynamic>?)?['temp'] ?? 0).toDouble();
                    return FlSpot(index.toDouble(), context.read<WeatherProvider>().convertTemp(tempCelsius));
                  }),
                  color: const Color(0xFF3FA9A0),
                  barWidth: 3,
                  belowBarData: BarAreaData(show: true, color: const Color(0x663FA9A0)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Loading signal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(height: 120, decoration: BoxDecoration(color: const Color(0x11FFFFFF), borderRadius: BorderRadius.circular(20))),
      ],
    );
  }

  Widget _buildErrorState(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0x11FFFFFF), borderRadius: BorderRadius.circular(20)),
      child: Text(message),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111727).withOpacity(0.4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 22, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF111727).withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF3FA9A0), size: 24),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[now.weekday % 7]}, ${now.day} ${months[now.month - 1]}';
  }
}
