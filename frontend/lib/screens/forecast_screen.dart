import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:weather_sense/providers/weather_provider.dart';
import 'package:weather_sense/widgets/weather_background.dart';

class ForecastScreen extends StatelessWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            const Text('7-Day Weather Forecast'),
            Text('Hourly Numerical Prediction', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: Colors.white70, letterSpacing: 1)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: const Color(0xFF0B1220),
        child: Text(
          'Forecast data: Open-Meteo',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(fontSize: 10, color: Colors.grey.withValues(alpha: 0.5)),
        ),
      ),
      body: Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          final forecast = provider.forecast;
          final items = (forecast?['forecast'] as List<dynamic>?) ?? [];
          final condition = provider.currentWeather?['condition']?.toString() ?? 'Clear';
          
          return WeatherBackground(
            condition: condition,
            child: items.isEmpty ? _buildEmptyState() : _buildForecastList(context, provider, items),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No forecast data yet.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildForecastList(BuildContext context, WeatherProvider provider, List<dynamic> items) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final day = items[index] as Map<String, dynamic>;
        final dateStr = day['date']?.toString() ?? '';
        final timeStr = day['time']?.toString() ?? '';
        final temp = provider.convertTemp((day['temp'] as num?)?.toDouble() ?? 0);
        final rain = (day['rainfall_mm'] as num?)?.toDouble() ?? 0;
        final humidity = (day['humidity'] as num?)?.toDouble() ?? 0;
        final condition = day['condition']?.toString() ?? 'Clear';

        bool showHeader = false;
        if (index == 0) {
          showHeader = true;
        } else {
          final prevDay = items[index - 1] as Map<String, dynamic>;
          if (prevDay['date'] != day['date']) {
            showHeader = true;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Color(0xFF3FA9A0)),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(dateStr).toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF3FA9A0),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF111727).withOpacity(0.8),
                    _getConditionColor(condition).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x0AFFFFFF)),
                boxShadow: [
                  BoxShadow(
                    color: _getConditionColor(condition).withOpacity(0.03),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        condition,
                        style: TextStyle(
                          color: _getConditionColor(condition),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _miniStat(Icons.water_drop_outlined, '${humidity.toInt()}%'),
                  const SizedBox(width: 16),
                  _miniStat(Icons.air, '${rain.toStringAsFixed(1)}mm'),
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x11FFFFFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(_getConditionIcon(condition), size: 20, color: _getConditionColor(condition)),
                        const SizedBox(width: 10),
                        Text(
                          '${temp.toStringAsFixed(1)}${provider.tempUnit}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _miniStat(IconData icon, String value) {
    return Column(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Color _getConditionColor(String condition) {
    if (condition.contains('Sunny') || condition.contains('Clear')) return const Color(0xFFE8935A);
    if (condition.contains('Rainy')) return const Color(0xFF4FA8FF);
    if (condition.contains('Cloudy') || condition.contains('Overcast')) return const Color(0xFF3FA9A0);
    return Colors.white70;
  }

  IconData _getConditionIcon(String condition) {
    if (condition.contains('Sunny')) return Icons.wb_sunny_rounded;
    if (condition.contains('Clear Night')) return Icons.nights_stay_rounded;
    if (condition.contains('Clear')) return Icons.wb_sunny_outlined;
    if (condition.contains('Partly Cloudy')) return Icons.wb_cloudy_outlined;
    if (condition.contains('Cloudy')) return Icons.cloud_outlined;
    if (condition.contains('Overcast')) return Icons.cloud_rounded;
    if (condition.contains('Rainy')) return Icons.umbrella_rounded;
    return Icons.wb_cloudy_rounded;
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }
}
