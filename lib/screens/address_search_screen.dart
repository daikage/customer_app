import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import '../utils/app_theme.dart';

class AddressSearchScreen extends StatefulWidget {
  final String title;
  const AddressSearchScreen({super.key, this.title = 'Search Address'});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final _searchC = TextEditingController();
  final _dio = Dio(BaseOptions(
    headers: {'User-Agent': 'PairrideCustomerApp/1.0.0'}, // Nominatim requires User-Agent
  ));
  
  List<dynamic> _results = [];
  bool _loading = false;
  Timer? _debounce;
  String? _error;

  @override
  void dispose() {
    _searchC.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _search(query.trim());
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Using OpenStreetMap Nominatim API (Free, no API key required)
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'addressdetails': 1,
          'limit': 8,
          // Optional: Restrict to Nigeria (uncomment and adjust if needed)
          // 'countrycodes': 'ng', 
        },
      );
      
      if (mounted) {
        setState(() {
          _results = response.data as List<dynamic>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load results. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppGradients.primary),
        ),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Search Input ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: TextField(
              controller: _searchC,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter destination...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchC.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchC.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.cardDark : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          // ── Results ─────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
                    : _results.isEmpty && _searchC.text.isNotEmpty
                        ? const Center(child: Text('No results found.'))
                        : ListView.builder(
                            itemCount: _results.length,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              // Nominatim provides lat/lon as strings
                              final lat = double.tryParse(item['lat'] ?? '');
                              final lng = double.tryParse(item['lon'] ?? '');
                              final displayName = item['display_name'] as String? ?? '';
                              
                              final parts = displayName.split(', ');
                              final title = parts.isNotEmpty ? parts.first : '';
                              final subtitle = parts.length > 1 ? parts.sublist(1).join(', ') : '';

                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.location_on, color: AppColors.primary),
                                ),
                                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  subtitle, 
                                  maxLines: 1, 
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                                onTap: () {
                                  if (lat != null && lng != null) {
                                    Navigator.pop(context, {
                                      'address': displayName,
                                      'lat': lat,
                                      'lng': lng,
                                    });
                                  }
                                },
                              ).animate().fadeIn(delay: Duration(milliseconds: 50 * index));
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
