import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:weather_sense/providers/weather_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService();
  List<dynamic> _suggestions = [];
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search locations'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<WeatherProvider>(
        builder: (context, provider, _) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  onChanged: (value) async {
                    if (value.length >= 2) {
                      setState(() => _isSearching = true);
                      final results = await _apiService.getSuggestions(value);
                      setState(() {
                        _suggestions = results;
                        _isSearching = false;
                      });
                    } else {
                      setState(() => _suggestions = []);
                    }
                  },
                  onSubmitted: (value) => _performSearch(value.trim(), provider),
                  decoration: InputDecoration(
                    hintText: 'Try London, Tokyo, Tekkali...',
                    filled: true,
                    fillColor: const Color(0xFF111727),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _isSearching 
                      ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                      : IconButton(icon: const Icon(Icons.search), onPressed: () => _performSearch(_controller.text.trim(), provider)),
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111727),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const Divider(color: Color(0x11FFFFFF), height: 1),
                      itemBuilder: (context, index) {
                        final city = _suggestions[index];
                        final name = city['name'];
                        final state = city['state'];
                        final country = city['country'];
                        final display = "$name${state != null ? ', $state' : ''}, $country";
                        
                        return ListTile(
                          title: Text(display, style: const TextStyle(fontSize: 14)),
                          onTap: () {
                            _controller.text = name;
                            _performSearch(name, provider);
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 24),
                if (provider.isLoading) const CircularProgressIndicator(),
                if (provider.errorMessage.isNotEmpty) ...[
                  Text(provider.errorMessage, style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 16),
                ],
                if (provider.history.isNotEmpty && _suggestions.isEmpty) ...[
                  Align(alignment: Alignment.centerLeft, child: Text('Recent searches', style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: provider.history.map((city) => ActionChip(
                      backgroundColor: const Color(0xFF111727),
                      label: Text(city, style: const TextStyle(color: Colors.grey)), 
                      onPressed: () => _performSearch(city, provider),
                    )).toList(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _performSearch(String city, WeatherProvider provider) async {
    if (city.isEmpty) return;
    await provider.loadWeather(city);
    if (mounted && provider.errorMessage.isEmpty) {
      Navigator.of(context).pop();
    }
  }
}
