import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'app_sizebox.dart';

class LocationPickerDialog extends ConsumerStatefulWidget {
  final String? initialValue;
  final String? selectedState;
  const LocationPickerDialog({
    super.key,
    this.initialValue,
    this.selectedState,
  });

  @override
  ConsumerState<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends ConsumerState<LocationPickerDialog> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final Dio _dio = Dio();

  LatLng? _currentCenter;
  LatLng? _selectedLatLng;
  bool _isSearching = false;
  bool _isSatellite = false;

  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();

    _searchController.text = 'Fetching current location...';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final locData = await _fetchCurrentLocationData();
      if (!mounted) return;
      setState(() => _isSearching = false);

      if (locData != null) {
        final LatLng newLatLng = locData['latLng'];
        final String addr = locData['address'];
        setState(() {
          _selectedLatLng = newLatLng;
          _currentCenter = newLatLng;
          _searchController.text = addr;
        });
        _mapController.move(newLatLng, 15.0);
      } else {
        String startQuery = '';
        if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
          startQuery = widget.initialValue!;
        } else if (widget.selectedState != null &&
            widget.selectedState!.isNotEmpty) {
          startQuery = widget.selectedState!;
        }

        if (startQuery.isNotEmpty) {
          _searchController.text = startQuery;
          _performSearch(startQuery);
        } else {
          _searchController.text = 'Location unavailable';
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchCurrentLocationData() async {
    Position? position;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 4),
              ),
            );
          } catch (e) {
            debugPrint(
              'getCurrentPosition error/timeout, using getLastKnownPosition: $e',
            );
            position = await Geolocator.getLastKnownPosition();
          }
        }
      }
    } catch (e) {
      debugPrint('Geolocator error: $e');
    }

    if (position == null) {
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (e) {
        debugPrint('getLastKnownPosition error: $e');
      }
    }

    if (position != null) {
      final latLng = LatLng(position.latitude, position.longitude);
      String address = '';

      try {
        final response = await _dio.get(
          'https://nominatim.openstreetmap.org/reverse',
          queryParameters: {
            'lat': latLng.latitude,
            'lon': latLng.longitude,
            'format': 'json',
          },
          options: Options(
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
          ),
        );
        if (response.data != null && response.data['display_name'] != null) {
          address = response.data['display_name'].toString();
        }
      } catch (e) {
        debugPrint('Reverse geocode error (offline): $e');
      }

      if (address.isEmpty) {
        address =
            'Lat: ${latLng.latitude.toStringAsFixed(6)}, Lon: ${latLng.longitude.toStringAsFixed(6)}';
      }

      return {'latLng': latLng, 'address': address};
    }

    try {
      final ipResp = await _dio.get('https://ipapi.co/json/');
      if (ipResp.data != null && ipResp.data['latitude'] != null) {
        final double lat = double.parse(ipResp.data['latitude'].toString());
        final double lon = double.parse(ipResp.data['longitude'].toString());
        final String city = ipResp.data['city']?.toString() ?? '';
        final String region = ipResp.data['region']?.toString() ?? '';
        final String country =
            ipResp.data['country_name']?.toString() ?? 'India';
        final String address = [
          city,
          region,
          country,
        ].where((s) => s.isNotEmpty).join(', ');
        return {'latLng': LatLng(lat, lon), 'address': address};
      }
    } catch (e) {
      debugPrint('IP location error: $e');
    }

    return null;
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.trim().length < 2) {
      if (mounted) setState(() => _showSuggestions = false);
      return;
    }
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 5,
          'addressdetails': 1,
        },
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );
      if (response.data != null && response.data is List) {
        final list = (response.data as List).map((e) {
          return {
            'display_name': e['display_name']?.toString() ?? '',
            'lat': double.parse(e['lat'].toString()),
            'lon': double.parse(e['lon'].toString()),
            'boundingbox': e['boundingbox'],
          };
        }).toList();

        if (mounted) {
          setState(() {
            _suggestions = list;
            _showSuggestions = list.isNotEmpty;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching suggestions: $e');
    }
  }

  void _selectSuggestion(Map<String, dynamic> item) {
    final double lat = item['lat'];
    final double lon = item['lon'];
    final newLatLng = LatLng(lat, lon);
    final displayName = item['display_name'];

    setState(() {
      _selectedLatLng = newLatLng;
      _currentCenter = newLatLng;
      _searchController.text = displayName;
      _showSuggestions = false;
    });

    if (item['boundingbox'] != null && item['boundingbox'] is List) {
      final bbox = item['boundingbox'] as List;
      final south = double.parse(bbox[0].toString());
      final north = double.parse(bbox[1].toString());
      final west = double.parse(bbox[2].toString());
      final east = double.parse(bbox[3].toString());
      final latDiff = (north - south).abs();
      final lonDiff = (east - west).abs();
      if (latDiff > 1.5 || lonDiff > 1.5) {
        final bounds = LatLngBounds(LatLng(south, west), LatLng(north, east));
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(30)),
        );
        return;
      }
    }
    _mapController.move(newLatLng, 15.5);
  }

  Future<void> _performSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _showSuggestions = false;
    });

    try {
      final List<String> candidateQueries = [];
      final parts = query
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();

      if (parts.length >= 2 && !query.contains(',')) {
        candidateQueries.add('${parts.sublist(1).join(' ')}, ${parts.first}');
      }
      candidateQueries.add(query);
      if (parts.length >= 2 && !query.contains(',')) {
        candidateQueries.add(parts.last);
      }

      for (final searchQ in candidateQueries) {
        final response = await _dio.get(
          'https://nominatim.openstreetmap.org/search',
          queryParameters: {'q': searchQ, 'format': 'json', 'limit': 1},
          options: Options(
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            },
          ),
        );

        if (response.data != null &&
            response.data is List &&
            (response.data as List).isNotEmpty) {
          final item = response.data[0];
          final double lat = double.parse(item['lat'].toString());
          final double lon = double.parse(item['lon'].toString());
          final newLatLng = LatLng(lat, lon);
          final displayName = item['display_name']?.toString() ?? query;

          setState(() {
            _selectedLatLng = newLatLng;
            _currentCenter = newLatLng;
            _searchController.text = displayName;
          });

          if (item['boundingbox'] != null && item['boundingbox'] is List) {
            final bbox = item['boundingbox'] as List;
            final south = double.parse(bbox[0].toString());
            final north = double.parse(bbox[1].toString());
            final west = double.parse(bbox[2].toString());
            final east = double.parse(bbox[3].toString());
            final latDiff = (north - south).abs();
            final lonDiff = (east - west).abs();
            if (latDiff > 1.5 || lonDiff > 1.5) {
              final bounds = LatLngBounds(
                LatLng(south, west),
                LatLng(north, east),
              );
              _mapController.fitCamera(
                CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(30),
                ),
              );
              return;
            }
          }

          _mapController.move(newLatLng, 15.5);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error searching location: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': point.latitude,
          'lon': point.longitude,
          'format': 'json',
        },
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );
      if (response.data != null && response.data['display_name'] != null) {
        final String displayName = response.data['display_name'].toString();
        if (mounted) {
          setState(() {
            _searchController.text = displayName;
            _showSuggestions = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error reverse geocoding: $e');
    }

    if (mounted) {
      setState(() {
        _searchController.text =
            'Lat: ${point.latitude.toStringAsFixed(6)}, Lon: ${point.longitude.toStringAsFixed(6)}';
        _showSuggestions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFF0E73D3),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // Search Box
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const AppSizeBox.w(12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Search location...',
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) {
                          _fetchSuggestions(val);
                        },
                        onSubmitted: _performSearch,
                      ),
                    ),
                    if (_isSearching)
                      const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(
                          Icons.search,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onPressed: () => _performSearch(_searchController.text),
                      ),
                  ],
                ),
              ),
            ),

            // Map Area with flutter_map and auto-suggestions dropdown
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentCenter ?? const LatLng(0, 0),
                      initialZoom: 14.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _selectedLatLng = point;
                          _showSuggestions = false;
                        });
                        _reverseGeocode(point);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _isSatellite
                            ? 'https://{s}.google.com/vt/lyrs=s,h&x={x}&y={y}&z={z}'
                            : 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                        subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
                        tileProvider: NetworkTileProvider(
                          headers: {
                            'User-Agent':
                                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                          },
                        ),
                      ),
                      if (_selectedLatLng != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLatLng!,
                              width: 44,
                              height: 44,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF0E73D3),
                                    size: 40,
                                  ),
                                  Positioned(
                                    top: 6,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.person,
                                        color: Color(0xFF0E73D3),
                                        size: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // Floating Auto-Suggestions Dropdown
                  if (_showSuggestions && _suggestions.isNotEmpty)
                    Positioned(
                      left: 12,
                      right: 12,
                      top: 4,
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _suggestions.length,
                          separatorBuilder: (ctx, i) =>
                              Divider(height: 1, color: Colors.grey.shade200),
                          itemBuilder: (context, index) {
                            final item = _suggestions[index];
                            final text = item['display_name'] as String;
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: const Icon(
                                Icons.location_on_outlined,
                                size: 18,
                                color: Color(0xFF0E73D3),
                              ),
                              title: Text(
                                text,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectSuggestion(item),
                            );
                          },
                        ),
                      ),
                    ),

                  // Zoom Controls (Top-Left)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              final currentZoom = _mapController.camera.zoom;
                              _mapController.move(
                                _mapController.camera.center,
                                currentZoom + 1,
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.add,
                                size: 20,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Divider(height: 1, color: Colors.grey.shade300),
                          InkWell(
                            onTap: () {
                              final currentZoom = _mapController.camera.zoom;
                              _mapController.move(
                                _mapController.camera.center,
                                currentZoom - 1,
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.remove,
                                size: 20,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Map Layer Toggle (Top-Right)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isSatellite = !_isSatellite;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: _isSatellite
                              ? const Color(0xFF0E73D3)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.layers_outlined,
                          size: 20,
                          color: _isSatellite ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  // Reset Center / My Current Location Button (Top-Right under Layer Button)
                  Positioned(
                    right: 12,
                    top: 58,
                    child: GestureDetector(
                      onTap: () async {
                        setState(() => _isSearching = true);
                        final locData = await _fetchCurrentLocationData();
                        setState(() => _isSearching = false);
                        if (locData != null) {
                          final LatLng newLatLng = locData['latLng'];
                          final String addr = locData['address'];
                          setState(() {
                            _selectedLatLng = newLatLng;
                            _currentCenter = newLatLng;
                            if (addr.isNotEmpty) _searchController.text = addr;
                          });
                          _mapController.move(newLatLng, 15.0);
                        } else if (_selectedLatLng != null) {
                          _mapController.move(_selectedLatLng!, 14.0);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.my_location,
                          size: 20,
                          color: Color(0xFF0E73D3),
                        ),
                      ),
                    ),
                  ),

                  // Google Logo (Bottom-Left)
                  Positioned(
                    left: 12,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Google',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5F6368),
                          fontSize: 14,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),

                  // Map Copyright Attribution (Bottom-Right)
                  Positioned(
                    right: 12,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Map data ©2026 Google | Leaflet',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF5F6368),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.black87, fontSize: 13),
                    ),
                  ),
                  const AppSizeBox.w(10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, _searchController.text.trim());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E73D3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Select',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
