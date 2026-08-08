import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:weather_sense/providers/weather_provider.dart';

class ForecastScreen extends StatelessWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('7-Day Forecast'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          final forecast = provider.forecast;
          final items = (forecast?['forecast'] as List<dynamic>?) ?? [];
          
          if (items.isEmpty) {
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

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111727),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x11FFFFFF)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(dateStr),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeStr,
                            style: const TextStyle(color: Color(0xFF3FA9A0), fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_getConditionIcon(condition), size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(condition, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.water_drop_outlined, size: 14, color: Color(0xFF3FA9A0)),
                              const SizedBox(width: 4),
                              Text('${rain.toStringAsFixed(1)}mm', style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 12),
                              const Icon(Icons.wb_cloudy_outlined, size: 14, color: Color(0xFFE8935A)),
                              const SizedBox(width: 4),
                              Text('${humidity.toInt()}%', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${temp.toStringAsFixed(1)}${provider.tempUnit}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getConditionIcon(String condition) {
    switch (condition) {
      case 'Rainy': return Icons.umbrella_outlined;
      case 'Cloudy': return Icons.wb_cloudy_outlined;
      default: return Icons.wb_sunny_outlined;
    }
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
