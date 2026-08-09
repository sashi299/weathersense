import 'dart:async';
import 'dart:convert';
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
  Map<String, dynamic>? _detectedLocation;
  bool _isSearching = false;
  bool _isLocating = false;
  String? _locationError;

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

    setState(() {
      _isSearching = true;
      _detectedLocation = null;
      _locationError = null; // Clear any previous errors
    });
    
    try {
      final results = await _apiService.getSuggestions(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _locationError = "Unable to search locations. Please check your connection.";
        });
      }
    }
  }

  Future<void> _detectCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
      _detectedLocation = null;
      _suggestions = [];
      _controller.clear();
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied. Please enable them in settings.';
      }

      // Use a timeout to avoid getting stuck
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final result = await _apiService.reverseGeocode(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() {
          _detectedLocation = result;
          _isLocating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = e.toString();
          _isLocating = false;
        });
      }
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
                      if (_isLocating) 
                        _buildStatusCard(
                          icon: const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3FA9A0)),
                          title: 'Detecting location...',
                          subtitle: 'Consulting satellites for your coordinates',
                        )
                      else if (_locationError != null)
                        _buildStatusCard(
                          icon: const Icon(Icons.location_off, color: Colors.redAccent),
                          title: 'Error',
                          subtitle: _locationError!,
                          action: TextButton(
                            onPressed: () {
                              if (_controller.text.length >= 2) {
                                _fetchSuggestions(_controller.text);
                              } else {
                                _detectCurrentLocation();
                              }
                            },
                            child: const Text('Retry', style: TextStyle(color: Color(0xFF3FA9A0))),
                          ),
                        )
                      else if (_detectedLocation != null)
                        _buildDetectedLocationCard(_detectedLocation!, provider)
                      else if (_controller.text.isEmpty)
                        _buildCurrentLocationTrigger(),

                      if (_isSearching) _buildLoadingIndicator(),
                      
                      if (_suggestions.isNotEmpty) ...[
                        _sectionLabel('SEARCH RESULTS'),
                        ..._suggestions.map((s) => _buildResultItem(s, provider)).toList(),
                      ] else if (_controller.text.length >= 2 && !_isSearching && _locationError == null)
                        _buildNoResults(),
                      
                      if (provider.history.isNotEmpty && _suggestions.isEmpty && !_isSearching && _detectedLocation == null) ...[
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
        autofocus: false,
        style: const TextStyle(color: Colors.white),
        onChanged: (val) {
          if (val.length >= 2) setState(() => _isSearching = true);
          _searchSubject.add(val);
        },
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

  Widget _buildCurrentLocationTrigger() {
    return InkWell(
      onTap: _detectCurrentLocation,
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
            const Icon(Icons.my_location, color: Color(0xFF3FA9A0)),
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
    );
  }

  Widget _buildStatusCard({required Widget icon, required String title, required String subtitle, Widget? action}) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF111727),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, height: 24, child: icon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _buildDetectedLocationCard(Map<String, dynamic> location, WeatherProvider provider) {
    final name = location['name'] ?? 'Detected Location';
    final state = location['state'];
    final country = location['country'] ?? '';
    final lat = location['lat'];
    final lon = location['lon'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('CURRENT LOCATION'),
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF3FA9A0).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF3FA9A0)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(20),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF3FA9A0),
              child: Icon(Icons.location_on, color: Colors.white),
            ),
            title: Text(name, style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text("${state != null ? '$state, ' : ''}$country", style: const TextStyle(color: Colors.white70)),
            trailing: const Icon(Icons.check_circle, color: Color(0xFF3FA9A0)),
            onTap: () async {
              await provider.loadWeather(name, lat: lat, lon: lon);
              if (mounted && provider.errorMessage.isEmpty) {
                Navigator.pop(context);
              }
            },
          ),
        ),
      ],
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
          // Store full info in history
          final fullInfo = {
            'name': name,
            'state': state,
            'country': country,
            'lat': lat,
            'lon': lon,
          };
          await provider.loadWeather(name, lat: lat, lon: lon, extra: fullInfo);
          if (mounted && provider.errorMessage.isEmpty) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Widget _buildRecentSearches(WeatherProvider provider) {
    return Column(
      children: provider.history.map((historyItem) {
        Map<String, dynamic> data;
        try {
          data = json.decode(historyItem);
        } catch (_) {
          data = {'name': historyItem, 'country': ''};
        }

        final name = data['name'] ?? 'Unknown';
        final state = data['state'];
        final country = data['country'] ?? '';
        final lat = data['lat'];
        final lon = data['lon'];

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111727).withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.history, color: Colors.grey, size: 18),
            title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: country.isNotEmpty 
              ? Text("${state != null ? '$state, ' : ''}$country", style: const TextStyle(color: Colors.grey, fontSize: 11))
              : null,
            onTap: () {
              provider.loadWeather(name, lat: lat, lon: lon);
              Navigator.pop(context);
            },
          ),
        );
      }).toList(),
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
