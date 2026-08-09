import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:weather_sense/providers/weather_provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<WeatherProvider>().refreshAnalytics());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Weather Analytics'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) return _buildLoading();
          if (provider.errorMessage.isNotEmpty) return _buildError(provider);
          
          final data = provider.analytics;
          if (data == null || data.isEmpty) return _buildEmpty();

          return _buildDashboard(data);
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF3FA9A0)),
          SizedBox(height: 24),
          Text('Decoding satellite data...', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildError(WeatherProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text('Analytics Sync Failed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Unable to reach the AI engine. Please check your connection.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => provider.refreshAnalytics(),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3FA9A0)),
              child: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(child: Text('AI Insights not available yet.'));
  }

  Widget _buildDashboard(Map<String, dynamic> data) {
    final summary = data['dataset_summary'] as Map<String, dynamic>? ?? {};
    final metrics = (data['model_metrics'] as List?) ?? [];
    final bestModels = data['best_models'] as Map<String, dynamic>? ?? {};
    final insights = (data['ai_insights'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionHeader('DATASET OVERVIEW'),
        _buildDatasetCard(summary),
        const SizedBox(height: 32),
        
        _sectionHeader('MODEL PERFORMANCE'),
        _buildPerformanceCard('Temperature', 'temperature', bestModels),
        _buildPerformanceCard('Humidity', 'humidity', bestModels),
        _buildPerformanceCard('Rainfall', 'rainfall', bestModels),
        const SizedBox(height: 32),

        _sectionHeader('MODEL COMPARISON (R²)'),
        _buildComparisonChart(metrics),
        const SizedBox(height: 32),

        _sectionHeader('AI INTELLIGENCE'),
        ...insights.map((i) => _buildInsightCard(i)).toList(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2, color: const Color(0xFF3FA9A0))),
    );
  }

  Widget _buildDatasetCard(Map<String, dynamic> summary) {
    final start = summary['date_range']?[0] ?? '1981';
    final end = summary['date_range']?[1] ?? '2024';
    final records = summary['total_records'] ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF111727).withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dataPoint('Earliest', start.toString().substring(0, 4)),
              const Icon(Icons.arrow_forward, color: Colors.grey, size: 16),
              _dataPoint('Latest', end.toString().substring(0, 4)),
            ],
          ),
          const Divider(height: 40, color: Color(0x11FFFFFF)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dataPoint('Observations', records.toString()),
              _dataPoint('Cities', (summary['cities'] as List?)?.length.toString() ?? '0'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataPoint(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  Widget _buildPerformanceCard(String title, String key, Map<String, dynamic> bestModels) {
    final model = bestModels[key] ?? {};
    final name = model['model_name'] ?? 'N/A';
    final m = model['metrics'] as Map<String, dynamic>? ?? {};
    final r2 = (m['r2'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111727).withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF3FA9A0).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(name, style: const TextStyle(color: Color(0xFF3FA9A0), fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _metric('RMSE', (m['rmse'] as num?)?.toStringAsFixed(2) ?? '--'),
              _metric('MAE', (m['mae'] as num?)?.toStringAsFixed(2) ?? '--'),
              _metric('MAPE', '${(m['mape'] as num?)?.toStringAsFixed(1) ?? '--'}%'),
              _metric('R²', (m['r2'] as num?)?.toStringAsFixed(3) ?? '--'),
            ],
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: r2.clamp(0.0, 1.0),
            backgroundColor: const Color(0x11FFFFFF),
            color: r2 > 0.8 ? const Color(0xFF81C784) : const Color(0xFFE8935A),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildInsightCard(dynamic insight) {
    final iconName = insight['icon'] ?? 'info';
    final title = insight['title'] ?? 'Insight';
    final explanation = insight['explanation'] ?? '';
    final status = insight['status'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111727).withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_getInsightIcon(iconName), color: const Color(0xFFE8935A)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(status.toUpperCase(), style: const TextStyle(fontSize: 9, color: Color(0xFF3FA9A0), fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(explanation, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getInsightIcon(String name) {
    switch(name) {
      case 'history': return Icons.history_edu_rounded;
      case 'psychology': return Icons.psychology_rounded;
      case 'umbrella': return Icons.umbrella_rounded;
      case 'verified': return Icons.verified_user_rounded;
      case 'warning': return Icons.warning_amber_rounded;
      default: return Icons.insights_rounded;
    }
  }

  Widget _buildComparisonChart(List<dynamic> metrics) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111727).withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1.1,
          barGroups: _generateGroups(metrics),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: _getBottomTitles)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  List<BarChartGroupData> _generateGroups(List<dynamic> metrics) {
    // Group metrics by target
    final targets = ['temperature', 'humidity', 'rainfall'];
    List<BarChartGroupData> groups = [];
    
    for (int i = 0; i < targets.length; i++) {
      final target = targets[i];
      final prophet = metrics.firstWhere((m) => m['target'] == target && m['model'] == 'Prophet', orElse: () => {'r2': 0})['r2'] ?? 0;
      final xgboost = metrics.firstWhere((m) => m['target'] == target && m['model'] == 'XGBoost', orElse: () => {'r2': 0})['r2'] ?? 0;

      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(toY: (prophet as num).toDouble().clamp(0.0, 1.0), color: Colors.grey.withOpacity(0.3), width: 12),
          BarChartRodData(toY: (xgboost as num).toDouble().clamp(0.0, 1.0), color: const Color(0xFF3FA9A0), width: 12),
        ],
      ));
    }
    return groups;
  }

  Widget _getBottomTitles(double value, TitleMeta meta) {
    const labels = ['Temp', 'Humidity', 'Rain'];
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(labels[value.toInt()], style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
