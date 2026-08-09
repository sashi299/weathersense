import 'package:flutter/material.dart';

class SkyBand extends StatelessWidget {
  final String city;
  final double temperature;
  final String condition;

  const SkyBand({super.key, required this.city, required this.temperature, required this.condition});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF6B5B95), Color(0xFFE8935A), Color(0xFF0B1220)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(city, style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 18)),
          const SizedBox(height: 8),
          Text('${temperature.toStringAsFixed(1)}°', style: const TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 56, fontWeight: FontWeight.bold)),
          Text(condition, style: const TextStyle(color: Color(0xFFF2F0EA))),
        ],
      ),
    );
  }
}
