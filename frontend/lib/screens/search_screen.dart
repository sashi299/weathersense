import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:weather_sense/providers/weather_provider.dart';
import 'package:weather_sense/services/api_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService();
  final _searchSubject = PublishSubject<String>();
  StreamSubscription? _subscription;
  
  List<dynamic> _suggestions = [];
  bool _isSearching = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _subscription = _searchSubject
        .debounceTime(const Duration(milliseconds: 500))
        .distinct()
        .listen(_fetchSuggestions);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchSubject.close();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _apiService.getSuggestions(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _useCurrentLocation(WeatherProvider provider) async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        await provider.loadWeather(
          'Current Location', 
          lat: position.latitude, 
          lon: position.longitude
        );
        if (mounted && provider.errorMessage.isEmpty) {
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        title: Text('Search Locations', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                _buildSearchField(),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (_controller.text.isEmpty) _buildCurrentLocationButton(provider),
                      if (_isSearching) _buildLoadingIndicator(),
                      if (_suggestions.isNotEmpty) ...[
                        _sectionLabel('SEARCH RESULTS'),
                        ..._suggestions.map((s) => _buildResultItem(s, provider)).toList(),
                      ] else if (_controller.text.length >= 2 && !_isSearching)
                        _buildNoResults(),
                      
                      if (provider.history.isNotEmpty && _suggestions.isEmpty && !_isSearching) ...[
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _sectionLabel('RECENT SEARCHES'),
                            TextButton(
                              onPressed: () => provider.clearHistory(),
                              child: const Text('Clear', style: TextStyle(color: Color(0xFF3FA9A0), fontSize: 12)),
                            ),
                          ],
                        ),
                        _buildRecentSearches(provider),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111727),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        onChanged: (val) => _searchSubject.add(val),
        decoration: InputDecoration(
          hintText: 'Enter city name...',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF3FA9A0)),
          suffixIcon: _controller.text.isNotEmpty 
            ? IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 20), onPressed: () {
                _controller.clear();
                _searchSubject.add('');
              })
            : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildCurrentLocationButton(WeatherProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: InkWell(
        onTap: () => _useCurrentLocation(provider),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF3FA9A0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3FA9A0).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              _isLocating 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3FA9A0)))
                : const Icon(Icons.my_location, color: Color(0xFF3FA9A0)),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Use my current location', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: Colors.white)),
                  const Text('Detects your city automatically', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultItem(dynamic suggestion, WeatherProvider provider) {
    final name = suggestion['name'] ?? 'Unknown';
    final state = suggestion['state'];
    final country = suggestion['country'] ?? '';
    final lat = suggestion['lat'];
    final lon = suggestion['lon'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111727).withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: const CircleAvatar(
          backgroundColor: Color(0x113FA9A0),
          child: Icon(Icons.location_on, color: Color(0xFF3FA9A0), size: 20),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(
          "${state != null ? '$state, ' : ''}$country",
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
        onTap: () async {
          await provider.loadWeather(name, lat: lat, lon: lon);
          if (mounted && provider.errorMessage.isEmpty) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildRecentSearches(WeatherProvider provider) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: provider.history.map((city) => InkWell(
        onTap: () => provider.loadWeather(city).then((_) {
          if (mounted && provider.errorMessage.isEmpty) Navigator.pop(context);
        }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF111727),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.history, color: Colors.grey, size: 14),
              const SizedBox(width: 8),
              Text(city, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      )).toList(),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        text, 
        style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: const Color(0xFF3FA9A0))
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(color: Color(0xFF3FA9A0)),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('No locations found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
