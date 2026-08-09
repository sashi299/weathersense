import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:weather_sense/providers/weather_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _sectionHeader('Preferences'),
              ListTile(
                title: const Text('Temperature Unit'),
                subtitle: Text(provider.isCelsius ? 'Celsius (°C)' : 'Fahrenheit (°F)'),
                trailing: Switch(
                  value: !provider.isCelsius,
                  onChanged: (_) => provider.toggleUnit(),
                  activeColor: const Color(0xFF3FA9A0),
                ),
                leading: const Icon(Icons.thermostat, color: Color(0xFFE8935A)),
              ),
              const Divider(color: Color(0x11FFFFFF)),
              _sectionHeader('Data Management'),
              ListTile(
                title: const Text('Clear Search History'),
                subtitle: const Text('Reset all saved locations'),
                leading: const Icon(Icons.history, color: Colors.grey),
                onTap: () => _confirmClearHistory(context, provider),
              ),
              const Divider(color: Color(0x11FFFFFF)),
              _sectionHeader('About'),
              const ListTile(
                title: Text('WeatherSense AI'),
                subtitle: Text('v1.0.0-production'),
                leading: Icon(Icons.info_outline, color: Colors.grey),
              ),
              const ListTile(
                title: Text('Data Source'),
                subtitle: Text('Railway Backend + OpenWeather'),
                leading: Icon(Icons.cloud_queue, color: Colors.grey),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF3FA9A0),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _confirmClearHistory(BuildContext context, WeatherProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111727),
        title: const Text('Clear History?'),
        content: const Text('This will remove all your recent searches.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search history cleared')),
              );
            },
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
