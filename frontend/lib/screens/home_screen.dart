import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:weather_sense/providers/weather_provider.dart';
import 'package:weather_sense/screens/analytics_screen.dart';
import 'package:weather_sense/screens/forecast_screen.dart';
import 'package:weather_sense/screens/search_screen.dart';
import 'package:weather_sense/screens/settings_screen.dart';

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
    Future.microtask(() {
      if (!mounted) return;
      context.read<WeatherProvider>().loadWeather('London');
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
          return RefreshIndicator(
            onRefresh: () => provider.loadWeather(provider.currentWeather?['city']?.toString() ?? 'London'),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF6B5B95), Color(0xFFE8935A), Color(0xFF0B1220)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(city, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen())), icon: const Icon(Icons.search_rounded)),
            ],
          ),
          const SizedBox(height: 14),
          Text(condition, style: const TextStyle(color: Color(0xFFF2F0EA), fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(temperature != null ? '${temperature.toStringAsFixed(0)}${provider.tempUnit}' : '--${provider.tempUnit}', style: GoogleFonts.spaceGrotesk(fontSize: 64, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              const Text('live readout', style: TextStyle(color: Color(0x70F2F0EA))),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            children: [
              _chip('Humidity', '${weather?['humidity'] ?? '--'}%'),
              _chip('Wind', '${weather?['wind_speed'] ?? '--'} m/s'),
              _chip('Pressure', '${weather?['pressure'] ?? '--'} hPa'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(Map<String, dynamic>? weather) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Live instrument panel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _statCard('UV Index', '${weather?['uv_index'] ?? '--'}', Icons.wb_sunny_outlined),
            _statCard('Air Quality', '${weather?['air_quality'] ?? '--'}', Icons.air_outlined),
            _statCard('Sunrise', weather?['sunrise'] ?? '--:--', Icons.wb_twilight),
            _statCard('Sunset', weather?['sunset'] ?? '--:--', Icons.nights_stay_outlined),
          ],
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _actionButton('Forecast', Icons.timeline, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForecastScreen())))),
        const SizedBox(width: 10),
        Expanded(child: _actionButton('Analytics', Icons.analytics_outlined, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnalyticsScreen())))),
        const SizedBox(width: 10),
        Expanded(child: _actionButton('Settings', Icons.tune, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())))),
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

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0x11FFFFFF), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF3FA9A0)),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0x70F2F0EA))),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0x22FFFFFF), borderRadius: BorderRadius.circular(999)),
      child: Text('$label $value', style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _actionButton(String label, IconData icon, VoidCallback onPressed) {
    return TextButton.icon(
      style: TextButton.styleFrom(backgroundColor: const Color(0x11FFFFFF), padding: const EdgeInsets.symmetric(vertical: 14)),
      onPressed: onPressed,
      icon: Icon(icon, color: const Color(0xFF3FA9A0)),
      label: Text(label, style: const TextStyle(color: Color(0xFFF2F0EA))),
    );
  }
}
