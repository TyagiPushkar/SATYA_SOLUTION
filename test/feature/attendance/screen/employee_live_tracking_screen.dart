import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_service.dart';
import 'monthly_records_screen.dart';

enum TimelineItemType { punchIn, punchOut, travelled, stoppage, task }

class EmployeeLiveTrackingScreen extends ConsumerStatefulWidget {
  final dynamic employeeExtra;
  final int? employeeId;
  final String? date;
  const EmployeeLiveTrackingScreen({
    super.key,
    this.employeeExtra,
    this.employeeId,
    this.date,
  });

  @override
  ConsumerState<EmployeeLiveTrackingScreen> createState() =>
      _EmployeeLiveTrackingScreenState();
}

class _EmployeeLiveTrackingScreenState
    extends ConsumerState<EmployeeLiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final MapController _mapController;
  LatLng? _currentLocation;
  String _selectedAttendanceOption = 'Attendance';
  String _selectedLeaveOption = 'Leave';
  bool _isVerticalPanelOpen = true;
  bool _isPlayingbackPlaying = false;
  double _playbackProgress = 0.3;
  bool _isFilterCollapsed = false;

  List<LatLng> _fieldVisitRoutePoints = [];
  List<LatLng> _stoppageRoutePoints = [];
  bool _isLoadingVisits = false;

  final List<Map<String, dynamic>> _tabs = [
    {'title': 'Live', 'icon': Icons.sensors},
    {'title': 'Playback', 'icon': Icons.play_circle_outline},
    {'title': 'Task', 'icon': Icons.assignment_outlined},
    {'title': 'All Attendance', 'hasDropdown': true, 'key': 'attendance'},
    {'title': 'All Leave', 'hasDropdown': true, 'key': 'leave'},
    {'title': 'Payment', 'icon': Icons.payments_outlined},
    {'title': 'Details', 'icon': Icons.badge_outlined},
    {'title': 'Managers', 'icon': Icons.person_outline},
    {'title': 'Documents', 'icon': Icons.description_outlined},
    {'title': 'Feeds', 'icon': Icons.rss_feed},
    {'title': 'Audit History', 'icon': Icons.fact_check_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _mapController = MapController();
    Future.microtask(() {
      final empId = _getEmployeeId();
      final date = _getVisitDate();
      fetchFieldVisits(empId, date);
    });
  }

  int _getEmployeeId() {
    if (widget.employeeId != null) return widget.employeeId!;
    if (widget.employeeExtra is int) return widget.employeeExtra as int;
    if (widget.employeeExtra is Map) {
      if (widget.employeeExtra['id'] != null) {
        return int.tryParse(widget.employeeExtra['id'].toString()) ?? 7;
      }
      if (widget.employeeExtra['emp_id'] != null) {
        return int.tryParse(widget.employeeExtra['emp_id'].toString()) ?? 7;
      }
    }
    return 7;
  }

  String _getVisitDate() {
    if (widget.date != null && widget.date!.isNotEmpty) return widget.date!;
    if (widget.employeeExtra is Map) {
      final map = widget.employeeExtra as Map;
      if (map['date'] != null && map['date'].toString().isNotEmpty) {
        return map['date'].toString();
      }
      if (map['created_at'] != null &&
          map['created_at'].toString().isNotEmpty) {
        final str = map['created_at'].toString();
        if (str.length >= 10) return str.substring(0, 10);
      }
      if (map['createdAt'] != null && map['createdAt'].toString().isNotEmpty) {
        final str = map['createdAt'].toString();
        if (str.length >= 10) return str.substring(0, 10);
      }
    }
    final now = DateTime.now();
    final y = now.year;
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<List<LatLng>> _getRoadSnappedRoute(List<LatLng> points) async {
    if (points.length < 2) return points;

    try {
      List<LatLng> sampledPoints = points;
      if (points.length > 25) {
        sampledPoints = [];
        final step = (points.length / 25).ceil();
        for (int i = 0; i < points.length; i += step) {
          sampledPoints.add(points[i]);
        }
        if (sampledPoints.last != points.last) {
          sampledPoints.add(points.last);
        }
      }

      final coordsString = sampledPoints
          .map(
            (p) =>
                '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}',
          )
          .join(';');

      final osrmUrl =
          'https://router.project-osrm.org/route/v1/driving/$coordsString?overview=full&geometries=geojson';

      final dio = Dio();
      final response = await dio.get(osrmUrl);

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          if (geometry != null && geometry['coordinates'] != null) {
            final coordinates = geometry['coordinates'] as List<dynamic>;
            final List<LatLng> snappedPoints = [];
            for (final coord in coordinates) {
              if (coord is List && coord.length >= 2) {
                final lng = double.tryParse(coord[0].toString());
                final lat = double.tryParse(coord[1].toString());
                if (lat != null && lng != null) {
                  snappedPoints.add(LatLng(lat, lng));
                }
              }
            }
            if (snappedPoints.isNotEmpty) {
              return snappedPoints;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("OSRM Road snapping error: $e");
    }

    return points;
  }

  Map<String, dynamic>? _attendanceData;
  List<dynamic> _visitsData = [];

  String _formatTimeOnly(dynamic raw, {required String fallback}) {
    if (raw == null) return fallback;
    final str = raw.toString().trim();
    if (str.isEmpty) return fallback;

    if (str.contains('T')) {
      final parts = str.split('T');
      if (parts.length > 1) {
        final timePart = parts[1];
        if (timePart.length >= 8) {
          return timePart.substring(0, 8);
        }
      }
    }

    try {
      final dt = DateTime.parse(str);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    } catch (_) {
      return str;
    }
  }

  Future<void> fetchFieldVisits(int empId, String date) async {
    setState(() {
      _isLoadingVisits = true;
    });

    final fallbackPoints = [
      const LatLng(28.518909, 77.2833571),
      const LatLng(28.518909, 77.2833571),
      const LatLng(28.5202165, 77.2844728),
      const LatLng(28.5206844, 77.2846856),
      const LatLng(28.5206535, 77.2852117),
      const LatLng(28.5206221, 77.284631),
      const LatLng(28.5191987, 77.2846941),
      const LatLng(28.519491, 77.2845128),
      const LatLng(28.5189225, 77.283353),
    ];

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get(
        ApiEndpoints.getFieldVisits,
        queryParameters: {'date': date, 'id': empId},
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final responseData = response.data;
      if (responseData is Map && responseData['success'] == true) {
        final data = responseData['data'] ?? {};
        final attendance = data['attendance'] is Map
            ? Map<String, dynamic>.from(data['attendance'])
            : null;
        final visits = data['visits'] as List<dynamic>? ?? [];
        setState(() {
          _attendanceData = attendance;
          _visitsData = visits;
        });

        final List<LatLng> fetchedPoints = [];
        final List<LatLng> stoppagePoints = [];

        for (final visit in visits) {
          final locations = visit['locations'] as List<dynamic>? ?? [];
          for (final loc in locations) {
            if (loc['latitude'] != null && loc['longitude'] != null) {
              final lat = double.tryParse(loc['latitude'].toString());
              final lng = double.tryParse(loc['longitude'].toString());
              final timeVal = int.tryParse(loc['time']?.toString() ?? '0') ?? 0;
              if (lat != null && lng != null) {
                final pt = LatLng(lat, lng);
                fetchedPoints.add(pt);
                if (timeVal > 0) {
                  stoppagePoints.add(pt);
                }
              }
            }
          }
        }
        if (fetchedPoints.isNotEmpty) {
          final snapped = await _getRoadSnappedRoute(fetchedPoints);
          setState(() {
            _fieldVisitRoutePoints = snapped;
            _stoppageRoutePoints = stoppagePoints;
            _isLoadingVisits = false;
          });
          _mapController.move(snapped.first, 17.8);
          return;
        }
      } else {
        debugPrint(
          "Field visits status code ${responseData?['statusCode']}: ${responseData?['message']}",
        );
      }
    } catch (e) {
      debugPrint("Error fetching field visits: $e");
    }

    final fallbackLocations = [
      {"time": 0, "latitude": 28.518909, "longitude": 77.2833571},
      {"time": 9, "latitude": 28.518909, "longitude": 77.2833571},
      {"time": 2, "latitude": 28.5202165, "longitude": 77.2844728},
      {"time": 6, "latitude": 28.5206844, "longitude": 77.2846856},
      {"time": 15, "latitude": 28.5206535, "longitude": 77.2852117},
      {"time": 6, "latitude": 28.5206221, "longitude": 77.284631},
      {"time": 1, "latitude": 28.5191987, "longitude": 77.2846941},
      {"time": 0, "latitude": 28.519491, "longitude": 77.2845128},
      {"time": 0, "latitude": 28.5189225, "longitude": 77.283353},
    ];

    final List<LatLng> fallbackStoppagePoints = [];
    for (final loc in fallbackLocations) {
      if ((loc['time'] as int) > 0) {
        fallbackStoppagePoints.add(
          LatLng(loc['latitude'] as double, loc['longitude'] as double),
        );
      }
    }

    final snappedFallback = await _getRoadSnappedRoute(fallbackPoints);
    setState(() {
      _fieldVisitRoutePoints = snappedFallback;
      _stoppageRoutePoints = fallbackStoppagePoints;
      _isLoadingVisits = false;
    });
    _mapController.move(snappedFallback.first, 17.8);
  }

  List<Marker> _buildRouteMarkers() {
    if (_fieldVisitRoutePoints.isEmpty) return [];

    List<Marker> markers = [];

    // Start Marker (Green Pin)
    markers.add(
      Marker(
        point: _fieldVisitRoutePoints.first,
        width: 36,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
        ),
      ),
    );

    // End Marker
    if (_fieldVisitRoutePoints.length > 1) {
      markers.add(
        Marker(
          point: _fieldVisitRoutePoints.last,
          width: 44,
          height: 44,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 26),
          ),
        ),
      );
    }

    // Stoppage Waypoint Markers (bindi) ONLY for points where time > 0
    for (final stopPoint in _stoppageRoutePoints) {
      markers.add(
        Marker(
          point: stopPoint,
          width: 14,
          height: 14,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0038A8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Employee Live Tracking',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Top Employee Info Header Container matching Trackwick UI
          _buildEmployeeHeaderContainer(),

          // Navigation TabBar matching Trackwick tab UI
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.black87,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: _tabs.map((tab) {
                if (tab['key'] == 'attendance') {
                  return PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    offset: const Offset(0, 42),
                    elevation: 6,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onCanceled: () {
                      _tabController.animateTo(3);
                    },
                    onSelected: (value) {
                      _tabController.animateTo(3);
                      setState(() {
                        _selectedAttendanceOption = value;
                      });
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'Attendance',
                        child: Row(
                          children: [
                            Stack(
                              children: const [
                                Icon(
                                  Icons.fingerprint,
                                  color: Color(0xFF1976D2),
                                  size: 24,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF1976D2),
                                    size: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Attendance',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'Monthly Attendance',
                        child: Row(
                          children: [
                            Stack(
                              children: const [
                                Icon(
                                  Icons.fingerprint,
                                  color: Color(0xFF1976D2),
                                  size: 24,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF1976D2),
                                    size: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Monthly Attendance',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tab['title'] as String),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, size: 18),
                        ],
                      ),
                    ),
                  );
                }

                if (tab['key'] == 'leave') {
                  return PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    offset: const Offset(0, 42),
                    elevation: 6,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onCanceled: () {
                      _tabController.animateTo(4);
                    },
                    onSelected: (value) {
                      _tabController.animateTo(4);
                      setState(() {
                        _selectedLeaveOption = value;
                      });
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem<String>(
                        value: 'Leave',
                        child: Row(
                          children: const [
                            Icon(
                              Icons.calendar_month_outlined,
                              color: Color(0xFF1976D2),
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Leave',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'Leave Summary',
                        child: Row(
                          children: const [
                            Icon(
                              Icons.assignment_outlined,
                              color: Color(0xFF1976D2),
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Leave Summary',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'Leave Balance',
                        child: Row(
                          children: const [
                            Icon(
                              Icons.edit_calendar_outlined,
                              color: Color(0xFF1976D2),
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Leave Balance',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'Leave Balance Audit',
                        child: Row(
                          children: const [
                            Icon(
                              Icons.edit_calendar_outlined,
                              color: Color(0xFF1976D2),
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Leave Balance Audit',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tab['title'] as String),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, size: 18),
                        ],
                      ),
                    ),
                  );
                }

                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tab['icon'] != null) ...[
                        Icon(tab['icon'] as IconData, size: 18),
                        const SizedBox(width: 6),
                      ],
                      Text(tab['title'] as String),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

          // Views for each tab
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLiveTab(),
                _buildPlaybackTab(),
                _buildTabContent('Task View', Icons.assignment_outlined),
                _buildAttendanceTab(),
                _buildLeaveTab(),
                _buildTabContent('Payment View', Icons.payments_outlined),
                _buildTabContent('Details View', Icons.badge_outlined),
                _buildTabContent('Managers View', Icons.person_outline),
                _buildTabContent('Documents View', Icons.description_outlined),
                _buildTabContent('Feeds View', Icons.rss_feed),
                _buildTabContent(
                  'Audit History View',
                  Icons.fact_check_outlined,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final userLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = userLatLng;
      });
      _mapController.move(userLatLng, 15.0);
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  Widget _buildLiveTab() {
    final activeRoutePoints = _fieldVisitRoutePoints.isNotEmpty
        ? _fieldVisitRoutePoints
        : [
            const LatLng(28.518909, 77.2833571),
            const LatLng(28.518909, 77.2833571),
            const LatLng(28.5202165, 77.2844728),
            const LatLng(28.5206844, 77.2846856),
            const LatLng(28.5206535, 77.2852117),
            const LatLng(28.5206221, 77.284631),
            const LatLng(28.5191987, 77.2846941),
            const LatLng(28.519491, 77.2845128),
            const LatLng(28.5189225, 77.283353),
          ];

    final initialCenter = activeRoutePoints.first;

    return Stack(
      children: [
        if (_isLoadingVisits)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              color: AppColors.primary,
              minHeight: 3,
            ),
          ),
        // 1. Real Google Maps View
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: initialCenter, initialZoom: 17.8),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
              userAgentPackageName: 'com.example.satyasolution',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: activeRoutePoints,
                  strokeWidth: 4.5,
                  color: const Color(0xFF0038A8),
                ),
              ],
            ),
            MarkerLayer(
              markers: _buildRouteMarkers().isNotEmpty
                  ? _buildRouteMarkers()
                  : [
                      Marker(
                        point: initialCenter,
                        width: 48,
                        height: 48,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 6,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
            ),
          ],
        ),

        // 2. Top Left Vertical Floating Panel Overlay (or Collapsed Button when closed)
        if (_isVerticalPanelOpen)
          Positioned(
            top: 12,
            left: 0,
            bottom: 12,
            child: _buildTopLeftVerticalPanel(),
          )
        else
          Positioned(top: 12, left: 0, child: _buildCollapsedToggleButton()),

        // 3. Right side Map Control Buttons (Layers, Center, Zoom In, Zoom Out, Fullscreen, Route)
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _buildMapControlButton(
                icon: Icons.layers_outlined,
                onPressed: () {},
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMapControlIconButton(Icons.my_location, () {
                      _getCurrentLocation();
                    }),
                    const Divider(height: 1, thickness: 1),
                    _buildMapControlIconButton(Icons.add, () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      );
                    }),
                    const Divider(height: 1, thickness: 1),
                    _buildMapControlIconButton(Icons.remove, () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      );
                    }),
                    const Divider(height: 1, thickness: 1),
                    _buildMapControlIconButton(Icons.fullscreen, () {}),
                    const Divider(height: 1, thickness: 1),
                    _buildMapControlIconButton(Icons.alt_route, () {}),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Trackwick Playback Tab View: 100% Full-Screen Map with 360° Overlay, Right Map Controls & Bottom Player Bar
  Widget _buildPlaybackTab() {
    final liveLocation = _currentLocation ?? const LatLng(26.650, 84.910);
    final routePoints = [
      const LatLng(26.635, 84.885),
      const LatLng(26.640, 84.895),
      const LatLng(26.645, 84.902),
      liveLocation,
      const LatLng(26.648, 84.918),
      const LatLng(26.640, 84.925),
      const LatLng(26.630, 84.930),
      const LatLng(26.618, 84.932),
    ];

    return Stack(
      children: [
        // 1. 100% Full-Screen Google Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: liveLocation, initialZoom: 17.8),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
              userAgentPackageName: 'com.example.satyasolution',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 4.5,
                  color: const Color(0xFF0038A8),
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: liveLocation,
                  width: 48,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // 2. Top-Left Vertical Panel Overlay (Playback tab: View Filter & Stats Panel)
        if (_isVerticalPanelOpen)
          Positioned(
            top: 12,
            left: 0,
            bottom: 65,
            child: _buildPlaybackTopLeftVerticalPanel(),
          )
        else
          Positioned(
            top: 12,
            left: 0,
            child: _buildCollapsedToggleButton(
              icon: Icons.calendar_month,
              title: 'View',
            ),
          ),

        // 3. Right Side Floating Map Controls (Layers, Center, Zoom In, Zoom Out, Fullscreen, Filter)
        Positioned(
          top: 12,
          right: 12,
          child: Column(
            children: [
              _buildMapControlButton(
                icon: Icons.layers_outlined,
                onPressed: () {},
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMapControlIconButton(Icons.my_location, () {
                      _getCurrentLocation();
                    }),
                    const Divider(height: 1, thickness: 1),
                    _buildMapControlIconButton(Icons.add, () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      );
                    }),
                    const Divider(height: 1, thickness: 1),
                    _buildMapControlIconButton(Icons.remove, () {
                      _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      );
                    }),
                    const Divider(height: 1, thickness: 1),
                    _buildMapControlIconButton(Icons.fullscreen, () {}),
                    const Divider(height: 1, thickness: 1),
                    _buildMapControlIconButton(
                      Icons.tune,
                      _showPlaybackFilterBottomSheet,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 4. Bottom Playback Player Controls Bar (Full Width Floating Overlay)
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: _buildBottomPlaybackPlayerBar(),
        ),
      ],
    );
  }

  void _showPlaybackFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPlaybackFilterCard(),
                const SizedBox(height: 12),
                _buildBatteryStatisticsCard(),
                const SizedBox(height: 12),
                _buildPlaybackMapStatsList(),
              ],
            ),
          ),
        );
      },
    );
  }

  // Bottom Playback Player Controls Bar (Play/Pause, Slider, Speed & Timestamp)
  Widget _buildBottomPlaybackPlayerBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _isPlayingbackPlaying ? Icons.pause : Icons.play_arrow,
              size: 22,
              color: Colors.black87,
            ),
            onPressed: () {
              setState(() {
                _isPlayingbackPlaying = !_isPlayingbackPlaying;
              });
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 3,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: _playbackProgress,
                activeColor: const Color(0xFF0066D4),
                inactiveColor: Colors.grey.shade300,
                onChanged: (val) {
                  setState(() {
                    _playbackProgress = val;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: const [
              Icon(Icons.speed, size: 15, color: Color(0xFF0066D4)),
              SizedBox(width: 4),
              Text(
                '2.00 KM/H  2026-07-28 07:05',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Playback Right Sidebar Date & Speed Filter Card (Expandable / Collapsible)
  Widget _buildPlaybackFilterCard() {
    if (_isFilterCollapsed) {
      return InkWell(
        onTap: () {
          setState(() {
            _isFilterCollapsed = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Row(
                children: [
                  Icon(Icons.filter_alt, size: 15, color: Colors.black87),
                  SizedBox(width: 8),
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black87),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Start-End Date*',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isFilterCollapsed = true;
                  });
                },
                child: Row(
                  children: const [
                    Text(
                      'Hide',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    Icon(Icons.keyboard_arrow_up, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildRadioOption('DateRange', true),
              const SizedBox(width: 12),
              _buildRadioOption('DateRangeTime', false),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFCBD5E1)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Today', style: TextStyle(fontSize: 12)),
                Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Speed Limit*',
                      style: TextStyle(fontSize: 10, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('100', style: TextStyle(fontSize: 11)),
                          Text(
                            'Km',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Stoppage Time*',
                      style: TextStyle(fontSize: 10, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('30', style: TextStyle(fontSize: 11)),
                          Text(
                            'Min',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEEEEE),
                foregroundColor: Colors.grey,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () {},
              child: const Text('Apply', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption(String label, bool isSelected) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? const Color(0xFF0066D4) : Colors.grey,
              width: 2,
            ),
          ),
          child: isSelected
              ? Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0066D4),
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 10.5)),
      ],
    );
  }

  // Battery Statistics Button Bar
  Widget _buildBatteryStatisticsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        children: const [
          Icon(Icons.battery_std, size: 18, color: Color(0xFF0066D4)),
          SizedBox(width: 8),
          Text(
            'Battery Statistics',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0066D4),
            ),
          ),
          Spacer(),
          Icon(Icons.chevron_right, size: 18, color: Color(0xFF0066D4)),
        ],
      ),
    );
  }

  // Stats viewing in map List
  Widget _buildPlaybackMapStatsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stats you are viewing in the map',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        _buildStatTile(Icons.alt_route, 'Km', '50.93', const Color(0xFF0066D4)),
        const SizedBox(height: 8),
        _buildStatTile(
          Icons.speed,
          'Speed Violations',
          '0',
          const Color(0xFFE53935),
        ),
        const SizedBox(height: 8),
        _buildStatTile(
          Icons.settings,
          'Stoppage',
          '0',
          const Color(0xFF1E88E5),
        ),
        const SizedBox(height: 8),
        _buildStatTile(
          Icons.assignment_turned_in,
          'Tasks Completed',
          '15',
          const Color(0xFF1E88E5),
        ),
      ],
    );
  }

  Widget _buildStatTile(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Floating Vertical Panel overlay at top-left
  Widget _buildTopLeftVerticalPanel({String title = '360° View'}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Blue Title Bar matching Trackwick (360° View or View + Refresh & Close icon)
          _buildTopBlueHeaderBar(title: title),

          // 2. Sub-Header Stats Row (Today date pill + Completed 10 + Distance 38.51Km)
          _buildSubHeaderStatsRow(),

          const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

          // 3. Scrollable Vertical Timeline Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: _buildVerticalTimelineList(),
            ),
          ),
        ],
      ),
    );
  }

  // Floating Vertical Panel overlay at top-left for Playback Tab (View Filter & Stats)
  Widget _buildPlaybackTopLeftVerticalPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Blue Title Bar: "View" + Refresh & Close arrow
          _buildTopBlueHeaderBar(title: 'View'),

          // 2. Scrollable Content (Filter Card, Battery Stats, Map Stats)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPlaybackFilterCard(),
                  const SizedBox(height: 10),
                  _buildBatteryStatisticsCard(),
                  const SizedBox(height: 10),
                  _buildPlaybackMapStatsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Top Blue Title Bar matching Trackwick header
  Widget _buildTopBlueHeaderBar({String title = '360° View'}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0066D4),
        borderRadius: BorderRadius.only(topRight: Radius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              InkWell(
                onTap: () {},
                child: const Icon(Icons.refresh, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () {
                  setState(() {
                    _isVerticalPanelOpen = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_left,
                    color: Colors.black87,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Collapsed Toggle Button floating at top-left when panel is closed
  Widget _buildCollapsedToggleButton({
    IconData icon = Icons.threesixty,
    String title = '360° View',
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isVerticalPanelOpen = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0066D4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 15, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Icon(
                Icons.keyboard_arrow_right,
                size: 16,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateDistanceInKm(List<LatLng> points) {
    if (points.length < 2) return 0.0;
    final Distance distance = const Distance();
    double totalMeters = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalMeters += distance.as(LengthUnit.Meter, points[i], points[i + 1]);
    }
    return totalMeters / 1000.0;
  }

  // Sub-Header Stats Row matching Trackwick (Today date pill + Completed count + Distance Km)
  Widget _buildSubHeaderStatsRow() {
    final distanceKm = _calculateDistanceInKm(_fieldVisitRoutePoints);
    final distanceStr = distanceKm > 0
        ? '${distanceKm.toStringAsFixed(2)}Km'
        : '1.45Km';
    final completedCount = _visitsData.isNotEmpty
        ? '${_visitsData.length}'
        : '1';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // Split Date Pill Box: "Today" | [📅]
          Container(
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFD0D5DD)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Today',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(width: 1, height: 30, color: const Color(0xFFD0D5DD)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Completed Count Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Completed',
                style: TextStyle(fontSize: 10, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                completedCount,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0066D4),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Distance Km Column
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Distance',
                style: TextStyle(fontSize: 10, color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                distanceStr,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0066D4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Vertical Timeline List matching exact API data dynamically
  Widget _buildVerticalTimelineList() {
    List<Widget> items = [];

    final punchInOffice =
        _attendanceData?['punchInOffice'] as Map<String, dynamic>?;
    final punchOutOffice =
        _attendanceData?['punchOutOffice'] as Map<String, dynamic>?;

    String punchInAddress = 'Vedanta Tech3, Okhla Phase 1, New Delhi';
    if (punchInOffice != null) {
      final name = punchInOffice['name']?.toString() ?? '';
      final addr = punchInOffice['address']?.toString() ?? '';
      if (name.isNotEmpty && addr.isNotEmpty) {
        punchInAddress = '$name, $addr';
      } else if (addr.isNotEmpty) {
        punchInAddress = addr;
      } else if (name.isNotEmpty) {
        punchInAddress = name;
      }
    }

    String punchOutAddress = 'Vedanta Tech3, Okhla Phase 1, New Delhi';
    if (punchOutOffice != null) {
      final name = punchOutOffice['name']?.toString() ?? '';
      final addr = punchOutOffice['address']?.toString() ?? '';
      if (name.isNotEmpty && addr.isNotEmpty) {
        punchOutAddress = '$name, $addr';
      } else if (addr.isNotEmpty) {
        punchOutAddress = addr;
      } else if (name.isNotEmpty) {
        punchOutAddress = name;
      }
    }

    final clockInTime = _formatTimeOnly(
      _attendanceData?['clock_in'],
      fallback: '08:20:19',
    );
    final clockOutTime = _formatTimeOnly(
      _attendanceData?['clock_out'],
      fallback: '09:18:01',
    );

    // 1. Punch In
    items.add(
      _buildTrackwickPunchInItem(
        title: 'Punch In',
        time: clockInTime,
        address: punchInAddress,
        isFirst: true,
        isLast: false,
      ),
    );

    // 2. Extract locations from visits
    List<Map<String, dynamic>> locationsList = [];
    for (final visit in _visitsData) {
      if (visit is Map && visit['locations'] is List) {
        for (final loc in visit['locations']) {
          if (loc is Map) {
            locationsList.add(Map<String, dynamic>.from(loc));
          }
        }
      }
    }

    // Default fallback from API payload if _visitsData is empty
    if (locationsList.isEmpty) {
      locationsList = [
        {
          "time": 0,
          "addedAt": "2026-07-29T08:20:31.372Z",
          "latitude": 28.518909,
          "longitude": 77.2833571,
        },
        {
          "time": 9,
          "addedAt": "2026-07-29T08:29:59.775Z",
          "latitude": 28.518909,
          "longitude": 77.2833571,
        },
        {
          "time": 2,
          "addedAt": "2026-07-29T08:32:50.610Z",
          "latitude": 28.5202165,
          "longitude": 77.2844728,
        },
        {
          "time": 6,
          "addedAt": "2026-07-29T08:38:53.976Z",
          "latitude": 28.5206844,
          "longitude": 77.2846856,
        },
        {
          "time": 15,
          "addedAt": "2026-07-29T08:54:23.895Z",
          "latitude": 28.5206535,
          "longitude": 77.2852117,
        },
        {
          "time": 6,
          "addedAt": "2026-07-29T09:00:41.738Z",
          "latitude": 28.5206221,
          "longitude": 77.284631,
        },
        {
          "time": 1,
          "addedAt": "2026-07-29T09:01:47.850Z",
          "latitude": 28.5191987,
          "longitude": 77.2846941,
        },
        {
          "time": 0,
          "addedAt": "2026-07-29T09:03:59.167Z",
          "latitude": 28.519491,
          "longitude": 77.2845128,
        },
        {
          "time": 0,
          "addedAt": "2026-07-29T09:05:42.411Z",
          "latitude": 28.5189225,
          "longitude": 77.283353,
        },
      ];
    }

    for (int i = 0; i < locationsList.length; i++) {
      final loc = locationsList[i];
      final addedAtStr = loc['addedAt']?.toString();
      final timeFormatted = _formatTimeOnly(addedAtStr, fallback: '08:20:31');
      final int stoppageMin = int.tryParse(loc['time']?.toString() ?? '0') ?? 0;
      final double? lat = double.tryParse(loc['latitude']?.toString() ?? '');
      final double? lng = double.tryParse(loc['longitude']?.toString() ?? '');

      final locAddrStr = (lat != null && lng != null)
          ? 'Okhla Phase 1, New Delhi (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})'
          : 'Okhla Phase 1, New Delhi';

      if (loc['customer'] != null && loc['customer'] is Map) {
        final cust = loc['customer'] as Map<String, dynamic>;
        items.add(
          _buildTrackwickTaskItem(
            taskId: 'TASK-${cust['id'] ?? '1001'}',
            timeRange: timeFormatted,
            duration: '',
            personName: cust['name']?.toString() ?? 'Customer',
            taskType: 'Field Visit',
            address: locAddrStr,
            isFirst: false,
            isLast: false,
          ),
        );
      } else if (stoppageMin > 0) {
        final stopMinStr = stoppageMin.toString().padLeft(2, '0');
        items.add(
          _buildTrackwickStoppageItem(
            title: 'Stoppage of 00:$stopMinStr',
            address: locAddrStr,
            isFirst: false,
            isLast: false,
          ),
        );
      } else {
        items.add(
          _buildTrackwickTravelledItem(
            title: 'Travelled ($timeFormatted)',
            distance: '',
            timeRange: timeFormatted,
            duration: '',
            isFirst: false,
            isLast: false,
          ),
        );
      }
    }

    // 3. Punch Out
    items.add(
      _buildTrackwickPunchOutItem(
        title: 'Punch Out',
        time: clockOutTime,
        duration: '(00:58)',
        address: punchOutAddress,
        isFirst: false,
        isLast: true,
      ),
    );

    return Column(children: items);
  }

  // Exact Trackwick Punch Out Item with Fingerprint Icon & Red Exit Badge
  Widget _buildTrackwickPunchOutItem({
    required String title,
    required String time,
    required String duration,
    required String address,
    required bool isFirst,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Vertical Line & Fingerprint Node Icon with Red Exit Badge
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(child: Container(width: 1.5, color: Colors.black)),
                Stack(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD0D7DE),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        color: Colors.blueGrey,
                        size: 15,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cancel,
                          color: Color(0xFFE53935),
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1.5, color: Colors.black)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Details Column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        duration,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E88E5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 13,
                        color: Color(0xFF1E88E5),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.black54,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Exact Trackwick Punch In Item with Fingerprint Icon & Checkmark
  Widget _buildTrackwickPunchInItem({
    required String title,
    required String time,
    required String address,
    required bool isFirst,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Vertical Line & Fingerprint Node Icon with Green Checkmark
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(child: Container(width: 1.5, color: Colors.black)),
                Stack(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F8),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD0D7DE),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        color: Colors.blueGrey,
                        size: 15,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Color(0xFF2E7D32),
                          size: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1.5, color: Colors.black)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Details Column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 13,
                        color: Color(0xFF1E88E5),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.black54,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Exact Trackwick Task Node Item
  Widget _buildTrackwickTaskItem({
    required String taskId,
    required String timeRange,
    required String duration,
    required String personName,
    required String taskType,
    required String address,
    required bool isFirst,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Vertical Line & Circle Node
          SizedBox(
            width: 24,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(child: Container(width: 1.5, color: Colors.black)),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF90CAF9),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1.5, color: Colors.black)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Content Details Column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task ID
                  Text(
                    taskId,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Time Range & Duration
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        timeRange,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        duration,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E88E5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Person Icon & Name
                  Row(
                    children: [
                      const Icon(Icons.person, size: 13, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text(
                        personName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E88E5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Task Type
                  Text(
                    'Type : $taskType',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 3),

                  // Address Pin & Location
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 13,
                        color: Color(0xFF1E88E5),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.black54,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Exact Trackwick Stoppage Node Item
  Widget _buildTrackwickStoppageItem({
    required String title,
    required String address,
    required bool isFirst,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Vertical Line & Red Stop Icon Node
          SizedBox(
            width: 24,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(child: Container(width: 1.5, color: Colors.black)),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFEF9A9A),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.stop_circle_outlined,
                    color: Color(0xFFE53935),
                    size: 11,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1.5, color: Colors.black)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Content Column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 13,
                        color: Color(0xFF1E88E5),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Colors.black54,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Exact Trackwick Travelled Node Item
  Widget _buildTrackwickTravelledItem({
    required String title,
    required String distance,
    required String timeRange,
    required String duration,
    required bool isFirst,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Vertical Line & Route Icon Node
          SizedBox(
            width: 24,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(child: Container(width: 1.5, color: Colors.black)),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF90CAF9),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.alt_route,
                    color: Color(0xFF1976D2),
                    size: 11,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 1.5, color: Colors.black)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Content Column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        distance,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        timeRange,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        duration,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF1E88E5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 20, color: Colors.black87),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildMapControlIconButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 38,
      height: 38,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: Colors.black87),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildAttendanceTab() {
    if (_selectedAttendanceOption == 'Monthly Attendance') {
      return const MonthlyRecordsScreen();
    }
    return _buildTabContent('Attendance View', Icons.fingerprint);
  }

  Widget _buildLeaveTab() {
    return _buildTabContent(
      'Leave View ($_selectedLeaveOption)',
      Icons.event_note_outlined,
    );
  }

  Widget _buildTabContent(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic>? _getEmployeeData() {
    if (_attendanceData?['employee'] is Map) {
      return Map<String, dynamic>.from(_attendanceData!['employee']);
    }
    if (widget.employeeExtra is Map) {
      return Map<String, dynamic>.from(widget.employeeExtra);
    }
    return null;
  }

  Widget _buildEmployeeHeaderContainer() {
    final emp = _getEmployeeData();
    final name = emp?['name']?.toString() ?? 'Ratan Verma';
    final designation =
        emp?['designations']?.toString() ??
        emp?['designation']?.toString() ??
        'Software Engineer';
    final identity =
        emp?['identity']?.toString() ?? emp?['emp_id']?.toString() ?? 'EMP1003';
    final mobile =
        emp?['mobile']?.toString() ?? emp?['phone']?.toString() ?? '9876843231';
    final department = emp?['department']?.toString() ?? 'Engineering';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Image
            const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFE0E0E0),
              child: Icon(Icons.person, color: Colors.grey, size: 26),
            ),
            const SizedBox(width: 12),

            // Name & Role
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1E88E5),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.settings_outlined,
                        color: Color(0xFF1E88E5),
                        size: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  designation,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(width: 16),
            _buildVerticalDivider(),
            const SizedBox(width: 16),

            // Details Column 1
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailItem(Icons.badge_outlined, identity, isBlue: false),
                const SizedBox(height: 4),
                _buildDetailItem(
                  Icons.phone_outlined,
                  mobile.startsWith('+') ? mobile : '+$mobile',
                  isBlue: false,
                ),
              ],
            ),

            const SizedBox(width: 20),

            // Details Column 2
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailItem(Icons.lock_outlined, mobile, isBlue: false),
                const SizedBox(height: 4),
                _buildDetailItem(Icons.public_outlined, 'IST', isBlue: false),
              ],
            ),

            const SizedBox(width: 16),
            _buildVerticalDivider(),
            const SizedBox(width: 16),

            // Details Column 3
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailItem(
                  Icons.grid_view_outlined,
                  department,
                  isBlue: true,
                ),
                const SizedBox(height: 4),
                _buildDetailItem(
                  Icons.sync_outlined,
                  'Credit Mitra and Off...',
                  isBlue: true,
                ),
              ],
            ),

            const SizedBox(width: 20),

            // Details Column 4
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailItem(
                  Icons.work_outline,
                  'Credit Mitra',
                  isBlue: true,
                ),
                const SizedBox(height: 4),
                _buildDetailItem(
                  Icons.event_note_outlined,
                  'Default',
                  isBlue: true,
                ),
              ],
            ),

            const SizedBox(width: 20),

            // Details Column 5
            _buildDetailItem(
              Icons.event_available_outlined,
              '29 Jul 2026',
              isBlue: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(height: 32, width: 1, color: const Color(0xFFE0E0E0));
  }

  Widget _buildDetailItem(IconData icon, String label, {required bool isBlue}) {
    final color = isBlue ? const Color(0xFF1E88E5) : Colors.black87;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: isBlue ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
