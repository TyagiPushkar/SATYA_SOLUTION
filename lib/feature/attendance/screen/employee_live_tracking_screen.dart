import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../provider/field_visit_provider.dart';
import '../provider/field_visit_state.dart';
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
  double _playbackProgress = 0.0;
  bool _isFilterCollapsed = false;

  // Data state now lives in fieldVisitProvider (Riverpod)

  // Playback animation state
  int _playbackCurrentIndex = 0;
  Timer? _playbackTimer;
  int _playbackSpeedMultiplier = 1; // 1x, 2x, 4x, 8x
  LatLng? _playbackMarkerPosition;
  // _locationTimestamps and _locationSpeeds now in fieldVisitProvider
  String _playbackCurrentTimestamp = '';
  double _playbackCurrentSpeed = 0.0;
  late DateTime _playbackSelectedDate; // currently selected date for playback

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
    final initialDate = _getVisitDate();
    try {
      _playbackSelectedDate = DateTime.parse(initialDate);
    } catch (_) {
      _playbackSelectedDate = DateTime.now();
    }
    Future.microtask(() {
      final empId = _getEmployeeId();
      final date = _getVisitDate();
      ref.read(fieldVisitProvider.notifier).fetchFieldVisits(empId, date);
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

  // _attendanceData and _visitsData now in fieldVisitProvider

  String _formatTimeOnly(dynamic raw, {required String fallback}) {
    if (raw == null) return fallback;
    final str = raw.toString().trim();
    if (str.isEmpty) return fallback;

    try {
      DateTime? dt;
      if (str.contains('T') || str.contains('-') || str.contains('Z')) {
        String isoStr = str;
        if (str.contains('T') && !str.endsWith('Z') && !str.contains('+')) {
          final timePart = str.split('T').last;
          if (!timePart.contains('+') && !timePart.contains('-')) {
            isoStr = '${str}Z';
          }
        }
        dt = DateTime.tryParse(isoStr)?.toLocal();
      } else {
        dt =
            DateTime.tryParse(str)?.toLocal() ??
            DateTime.tryParse('2026-01-01 $str');
      }

      if (dt != null) {
        int hour12 = dt.hour % 12;
        if (hour12 == 0) hour12 = 12;
        final h = hour12.toString().padLeft(2, '0');
        final m = dt.minute.toString().padLeft(2, '0');
        final s = dt.second.toString().padLeft(2, '0');
        final period = dt.hour >= 12 ? 'PM' : 'AM';
        return '$h:$m:$s $period';
      }
    } catch (_) {}

    if (str.contains('T')) {
      final parts = str.split('T');
      if (parts.length > 1 && parts[1].length >= 8) {
        final timePart = parts[1].substring(0, 8);
        final timeDt = DateTime.tryParse('2026-01-01 $timePart');
        if (timeDt != null) {
          int hour12 = timeDt.hour % 12;
          if (hour12 == 0) hour12 = 12;
          final h = hour12.toString().padLeft(2, '0');
          final m = timeDt.minute.toString().padLeft(2, '0');
          final s = timeDt.second.toString().padLeft(2, '0');
          final period = timeDt.hour >= 12 ? 'PM' : 'AM';
          return '$h:$m:$s $period';
        }
        return timePart;
      }
    }

    return str;
  }

  // fetchFieldVisits and _fetchRoadRoute now in FieldVisitNotifier (fieldVisitProvider)

  double _calculateBearing(LatLng start, LatLng end) {
    final startLat = start.latitudeInRad;
    final startLng = start.longitudeInRad;
    final endLat = end.latitudeInRad;
    final endLng = end.longitudeInRad;

    final dLng = endLng - startLng;

    final y = math.sin(dLng) * math.cos(endLat);
    final x = math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    final bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi + 360) % 360;
  }

  List<Marker> _buildDirectionArrowMarkers(List<LatLng> points) {
    if (points.length < 2) return [];
    List<Marker> arrowMarkers = [];

    const double minDistanceMeters = 60.0;
    LatLng lastPlacedPt = points.first;

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final dist = const Distance().as(LengthUnit.Meter, p1, p2);

      if (dist > 5.0) {
        final distFromLast =
            const Distance().as(LengthUnit.Meter, lastPlacedPt, p2);
        if (i == 0 || distFromLast >= minDistanceMeters) {
          lastPlacedPt = p2;
          final bearing = _calculateBearing(p1, p2);

          final midLat = (p1.latitude + p2.latitude) / 2;
          final midLng = (p1.longitude + p2.longitude) / 2;
          final midPoint = LatLng(midLat, midLng);

          arrowMarkers.add(
            Marker(
              point: midPoint,
              width: 22,
              height: 22,
              child: Transform.rotate(
                angle: bearing * (math.pi / 180),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0038A8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.navigation,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
              ),
            ),
          );
        }
      }
    }
    return arrowMarkers;
  }

  void _fitMapBounds() {
    final visitState = ref.read(fieldVisitProvider);
    final points = visitState.fieldVisitRoutePoints.isNotEmpty
        ? visitState.fieldVisitRoutePoints
        : visitState.rawVisitPoints;

    if (points.isNotEmpty) {
      if (points.length == 1) {
        _mapController.move(points.first, 16.0);
      } else {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(60),
          ),
        );
      }
    } else if (_currentLocation != null) {
      _mapController.move(_currentLocation!, 16.0);
    }
  }

  List<Marker> _buildRouteMarkers() {
    final visitState = ref.read(fieldVisitProvider);
    final rawPts = visitState.rawVisitPoints.isNotEmpty
        ? visitState.rawVisitPoints
        : visitState.fieldVisitRoutePoints;
    if (rawPts.isEmpty) return [];

    List<Marker> markers = [];

    // Directional Arrow Markers along polyline route
    markers.addAll(_buildDirectionArrowMarkers(rawPts));

    // Start Marker (Green Pin) at exact raw user start location
    markers.add(
      Marker(
        point: rawPts.first,
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

    // End Marker (Blue Person Icon) at exact raw user current location
    if (rawPts.length > 1) {
      markers.add(
        Marker(
          point: rawPts.last,
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
    for (final stopPoint in visitState.stoppageRoutePoints) {
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

  // ──────────────────────────────────────────────────────────
  // Playback animation controls
  // ──────────────────────────────────────────────────────────

  void _startPlayback() {
    final visitState = ref.read(fieldVisitProvider);
    if (visitState.fieldVisitRoutePoints.isEmpty) return;
    _playbackTimer?.cancel();
    // Interval: ~100ms / speedMultiplier gives smooth animation
    final interval = Duration(
      milliseconds: (120 ~/ _playbackSpeedMultiplier).clamp(30, 500),
    );
    _playbackTimer = Timer.periodic(interval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final total = visitState.fieldVisitRoutePoints.length;
      if (_playbackCurrentIndex >= total - 1) {
        // Reached end — stop playback
        timer.cancel();
        setState(() {
          _isPlayingbackPlaying = false;
          _playbackProgress = 1.0;
        });
        return;
      }
      setState(() {
        _playbackCurrentIndex++;
        _playbackProgress = _playbackCurrentIndex / (total - 1);
        _playbackMarkerPosition =
            visitState.fieldVisitRoutePoints[_playbackCurrentIndex];
        _playbackCurrentTimestamp =
            visitState.locationTimestamps.length > _playbackCurrentIndex
            ? visitState.locationTimestamps[_playbackCurrentIndex]
            : '';
        _playbackCurrentSpeed =
            visitState.locationSpeeds.length > _playbackCurrentIndex
            ? visitState.locationSpeeds[_playbackCurrentIndex]
            : 0.0;
      });
      // Smoothly move map camera to follow the marker
      if (_playbackMarkerPosition != null) {
        _mapController.move(
          _playbackMarkerPosition!,
          _mapController.camera.zoom,
        );
      }
    });
  }

  void _pausePlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    setState(() {
      _isPlayingbackPlaying = false;
    });
  }

  void _seekPlayback(double sliderValue) {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    final visitState = ref.read(fieldVisitProvider);
    final total = visitState.fieldVisitRoutePoints.length;
    if (total == 0) return;
    final idx = ((total - 1) * sliderValue).round().clamp(0, total - 1);
    setState(() {
      _playbackCurrentIndex = idx;
      _playbackProgress = sliderValue;
      _playbackMarkerPosition = visitState.fieldVisitRoutePoints[idx];
      _playbackCurrentTimestamp = visitState.locationTimestamps.length > idx
          ? visitState.locationTimestamps[idx]
          : '';
      _playbackCurrentSpeed = visitState.locationSpeeds.length > idx
          ? visitState.locationSpeeds[idx]
          : 0.0;
      _isPlayingbackPlaying = false;
    });
    if (_playbackMarkerPosition != null) {
      _mapController.move(_playbackMarkerPosition!, _mapController.camera.zoom);
    }
  }

  // ─────────────────────────────────────────────────────────
  // Date picker for Playback tab — re-fetches API on new date
  // ─────────────────────────────────────────────────────────
  Future<void> _showDatePickerForPlayback() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _playbackSelectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _playbackSelectedDate) {
      final y = picked.year;
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      final dateStr = '$y-$m-$d';
      setState(() {
        _playbackSelectedDate = picked;
        // Reset playback state while new data loads
        _isPlayingbackPlaying = false;
        _playbackCurrentIndex = 0;
        _playbackProgress = 0.0;
        _playbackMarkerPosition = null;
        _playbackCurrentTimestamp = '';
        _playbackCurrentSpeed = 0.0;
      });
      _playbackTimer?.cancel();
      _playbackTimer = null;
      // Re-fetch visits for new date, same employee
      await ref
          .read(fieldVisitProvider.notifier)
          .fetchFieldVisits(_getEmployeeId(), dateStr);
    }
  }

  String _formatPlaybackTimestamp(String raw) {
    if (raw.isEmpty) {
      // Generate a placeholder based on current index
      final now = DateTime.now();
      final y = now.year;
      final mo = now.month.toString().padLeft(2, '0');
      final d = now.day.toString().padLeft(2, '0');
      int hour12 = now.hour % 12;
      if (hour12 == 0) hour12 = 12;
      final h = hour12.toString().padLeft(2, '0');
      final mi = now.minute.toString().padLeft(2, '0');
      final period = now.hour >= 12 ? 'PM' : 'AM';
      return '$y-$mo-$d $h:$mi $period';
    }
    try {
      String isoStr = raw;
      if (raw.contains('T') && !raw.endsWith('Z') && !raw.contains('+')) {
        final timePart = raw.split('T').last;
        if (!timePart.contains('+') && !timePart.contains('-')) {
          isoStr = '${raw}Z';
        }
      }
      final dt = DateTime.parse(isoStr).toLocal();
      final y = dt.year;
      final mo = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      int hour12 = dt.hour % 12;
      if (hour12 == 0) hour12 = 12;
      final h = hour12.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$y-$mo-$d $h:$mi $period';
    } catch (_) {
      return raw.length > 16 ? raw.substring(0, 16) : raw;
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _tabController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<FieldVisitState>(fieldVisitProvider, (prev, next) {
      if (prev?.isLoading == true &&
          !next.isLoading &&
          (next.fieldVisitRoutePoints.isNotEmpty ||
              next.rawVisitPoints.isNotEmpty)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitMapBounds();
        });
      }
    });
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
    final visitState = ref.watch(fieldVisitProvider);
    final activeRoutePoints = visitState.fieldVisitRoutePoints;
    final initialCenter = activeRoutePoints.isNotEmpty
        ? activeRoutePoints.first
        : (_currentLocation ?? const LatLng(20.5937, 78.9629));

    return Stack(
      children: [
        if (visitState.isLoading)
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
            if (activeRoutePoints.isNotEmpty)
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
                  : (_currentLocation != null
                        ? [
                            Marker(
                              point: _currentLocation!,
                              width: 48,
                              height: 48,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1976D2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
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
                          ]
                        : []),
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
                    _buildMapControlIconButton(Icons.alt_route, _fitMapBounds),
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
    final visitState = ref.watch(fieldVisitProvider);
    final activeRoutePoints = visitState.fieldVisitRoutePoints;
    final initialCenter = activeRoutePoints.isNotEmpty
        ? activeRoutePoints.first
        : (_currentLocation ?? const LatLng(20.5937, 78.9629));

    return Stack(
      children: [
        // 1. 100% Full-Screen Google Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: initialCenter, initialZoom: 17.8),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              subdomains: const ['mt0', 'mt1', 'mt2', 'mt3'],
              userAgentPackageName: 'com.example.satyasolution',
            ),
            if (activeRoutePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: activeRoutePoints,
                    strokeWidth: 4.5,
                    color: const Color(0xFF0038A8),
                  ),
                ],
              ),
            // Travelled portion (lighter blue overlay)
            if (activeRoutePoints.isNotEmpty &&
                _playbackCurrentIndex > 0 &&
                _playbackCurrentIndex < activeRoutePoints.length)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: activeRoutePoints.sublist(
                      0,
                      _playbackCurrentIndex + 1,
                    ),
                    strokeWidth: 4.5,
                    color: const Color(0xFF42A5F5),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                // Direction Arrow Markers along polyline route
                ..._buildDirectionArrowMarkers(activeRoutePoints),
                // Start marker (green)
                if (activeRoutePoints.isNotEmpty)
                  Marker(
                    point: activeRoutePoints.first,
                    width: 32,
                    height: 32,
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
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                // End marker (red flag)
                if (activeRoutePoints.length > 1)
                  Marker(
                    point: activeRoutePoints.last,
                    width: 32,
                    height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
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
                      child: const Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                // Animated playback marker (person icon)
                if (_playbackMarkerPosition != null)
                  Marker(
                    point: _playbackMarkerPosition!,
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
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  )
                else if (_currentLocation != null)
                  Marker(
                    point: _currentLocation!,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                // Stoppage bindi markers
                ...visitState.stoppageRoutePoints.map(
                  (pt) => Marker(
                    point: pt,
                    width: 14,
                    height: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0038A8),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
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
                    _buildMapControlIconButton(Icons.alt_route, _fitMapBounds),
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
    final visitState = ref.watch(fieldVisitProvider);
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
          // Play / Pause button
          GestureDetector(
            onTap: () {
              if (visitState.fieldVisitRoutePoints.isEmpty) return;
              if (_isPlayingbackPlaying) {
                _pausePlayback();
              } else {
                // If at end, restart from beginning
                if (_playbackCurrentIndex >=
                    visitState.fieldVisitRoutePoints.length - 1) {
                  setState(() {
                    _playbackCurrentIndex = 0;
                    _playbackProgress = 0.0;
                    _playbackMarkerPosition =
                        visitState.fieldVisitRoutePoints.first;
                    _playbackCurrentTimestamp =
                        visitState.locationTimestamps.isNotEmpty
                        ? visitState.locationTimestamps.first
                        : '';
                    _playbackCurrentSpeed = visitState.locationSpeeds.isNotEmpty
                        ? visitState.locationSpeeds.first
                        : 0.0;
                  });
                }
                setState(() {
                  _isPlayingbackPlaying = true;
                });
                _startPlayback();
              }
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                _isPlayingbackPlaying ? Icons.pause : Icons.play_arrow,
                size: 24,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Timeline Slider
          Expanded(
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 3,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
              ),
              child: Slider(
                value: _playbackProgress.clamp(0.0, 1.0),
                activeColor: AppColors.primary,
                inactiveColor: Colors.grey.shade300,
                onChanged: (val) {
                  _seekPlayback(val);
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Speed multiplier button
          GestureDetector(
            onTap: () {
              // Cycle: 1x → 2x → 4x → 8x → 1x
              setState(() {
                _playbackSpeedMultiplier = _playbackSpeedMultiplier == 1
                    ? 2
                    : _playbackSpeedMultiplier == 2
                    ? 4
                    : _playbackSpeedMultiplier == 4
                    ? 8
                    : 1;
              });
              if (_isPlayingbackPlaying) {
                // Restart with new speed
                _startPlayback();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_playbackSpeedMultiplier}x',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Speed & timestamp display
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed, size: 13, color: AppColors.primary),
                  const SizedBox(width: 3),
                  Text(
                    '${_playbackCurrentSpeed.toStringAsFixed(2)} KM/H',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Text(
                _formatPlaybackTimestamp(_playbackCurrentTimestamp),
                style: const TextStyle(fontSize: 9, color: Colors.black54),
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
          // Date picker dropdown (replaces static "Today" field)
          GestureDetector(
            onTap: _showDatePickerForPlayback,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(6),
                color: Colors.white,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        () {
                          final now = DateTime.now();
                          final isToday =
                              _playbackSelectedDate.year == now.year &&
                              _playbackSelectedDate.month == now.month &&
                              _playbackSelectedDate.day == now.day;
                          return isToday
                              ? 'Today'
                              : '${_playbackSelectedDate.day.toString().padLeft(2, '0')}'
                                    '/${_playbackSelectedDate.month.toString().padLeft(2, '0')}'
                                    '/${_playbackSelectedDate.year}';
                        }(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.grey,
                  ),
                ],
              ),
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
              color: isSelected ? AppColors.primary : Colors.grey,
              width: 2,
            ),
          ),
          child: isSelected
              ? Center(
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
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
          Icon(Icons.battery_std, size: 18, color: AppColors.primary),
          SizedBox(width: 8),
          Text(
            'Battery Statistics',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          Spacer(),
          Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
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
        _buildStatTile(Icons.alt_route, 'Km', '50.93', AppColors.primary),
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
        color: AppColors.primary,
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
                color: AppColors.primary,
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
    final visitState = ref.watch(fieldVisitProvider);
    final distanceKm = _calculateDistanceInKm(visitState.rawVisitPoints);
    final distanceStr = '${distanceKm.toStringAsFixed(2)}Km';
    final completedCount = '${visitState.visitsData.length}';

    // Format selected date label
    final now = DateTime.now();
    final isToday =
        _playbackSelectedDate.year == now.year &&
        _playbackSelectedDate.month == now.month &&
        _playbackSelectedDate.day == now.day;
    final dateLabel = isToday
        ? 'Today'
        : '${_playbackSelectedDate.day.toString().padLeft(2, '0')}'
              '/${_playbackSelectedDate.month.toString().padLeft(2, '0')}'
              '/${_playbackSelectedDate.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // Split Date Pill Box: "Today" | [📅] — tappable to change date
          GestureDetector(
            onTap: _showDatePickerForPlayback,
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFD0D5DD)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: const Color(0xFFD0D5DD),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
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
                  color: AppColors.primary,
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
                  color: AppColors.primary,
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
    final visitState = ref.watch(fieldVisitProvider);
    if (visitState.attendanceData == null && visitState.visitsData.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Icon(Icons.event_busy_outlined, size: 44, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No attendance record found for this date',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    List<Widget> items = [];

    final punchInOffice =
        visitState.attendanceData?['punchInOffice'] as Map<String, dynamic>?;
    final punchOutOffice =
        visitState.attendanceData?['punchOutOffice'] as Map<String, dynamic>?;

    String punchInAddress = 'Location not available';
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
    } else if (visitState.attendanceData?['clock_in_address'] != null ||
        visitState.attendanceData?['punch_in_address'] != null) {
      punchInAddress =
          visitState.attendanceData?['clock_in_address']?.toString() ??
          visitState.attendanceData?['punch_in_address']?.toString() ??
          'Location not available';
    }

    String punchOutAddress = 'Location not available';
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
    } else if (visitState.attendanceData?['clock_out_address'] != null ||
        visitState.attendanceData?['punch_out_address'] != null) {
      punchOutAddress =
          visitState.attendanceData?['clock_out_address']?.toString() ??
          visitState.attendanceData?['punch_out_address']?.toString() ??
          'Location not available';
    }

    final clockInRaw = visitState.attendanceData?['clock_in'];
    final clockInTime = clockInRaw != null
        ? _formatTimeOnly(clockInRaw, fallback: '')
        : '';
    final clockOutRaw = visitState.attendanceData?['clock_out'];
    final clockOutTime = clockOutRaw != null
        ? _formatTimeOnly(clockOutRaw, fallback: '')
        : '';

    // Extract locations from visits
    List<Map<String, dynamic>> locationsList = [];
    for (final visit in visitState.visitsData) {
      if (visit is Map && visit['locations'] is List) {
        for (final loc in visit['locations']) {
          if (loc is Map) {
            locationsList.add(Map<String, dynamic>.from(loc));
          }
        }
      }
    }

    final bool hasPunchIn = clockInRaw != null || punchInOffice != null;
    final bool hasPunchOut = clockOutRaw != null || punchOutOffice != null;
    final bool hasLocations = locationsList.isNotEmpty;

    if (!hasPunchIn && !hasPunchOut && !hasLocations) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Icon(Icons.event_busy_outlined, size: 44, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No attendance record found for this date',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 1. Punch In
    if (hasPunchIn) {
      items.add(
        _buildTrackwickPunchInItem(
          title: 'Punch In',
          time: clockInTime,
          address: punchInAddress,
          isFirst: true,
          isLast: !hasLocations && !hasPunchOut,
        ),
      );
    }

    // 2. Locations / Stoppages / Travelled items
    for (int i = 0; i < locationsList.length; i++) {
      final loc = locationsList[i];
      final addedAtStr =
          loc['addedAt']?.toString() ??
          loc['createdAt']?.toString() ??
          loc['timestamp']?.toString();
      final timeFormatted = _formatTimeOnly(addedAtStr, fallback: '');
      final int stoppageMin = int.tryParse(loc['time']?.toString() ?? '0') ?? 0;
      final double? lat = double.tryParse(loc['latitude']?.toString() ?? '');
      final double? lng = double.tryParse(loc['longitude']?.toString() ?? '');

      final locAddrStr = (lat != null && lng != null)
          ? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'
          : 'Location not available';

      final isLastItem = (i == locationsList.length - 1) && !hasPunchOut;

      if (loc['customer'] != null && loc['customer'] is Map) {
        final cust = loc['customer'] as Map<String, dynamic>;
        items.add(
          _buildTrackwickTaskItem(
            taskId: 'TASK-${cust['id'] ?? ''}',
            timeRange: timeFormatted,
            duration: '',
            personName: cust['name']?.toString() ?? 'Customer',
            taskType: 'Field Visit',
            address: locAddrStr,
            isFirst: !hasPunchIn && i == 0,
            isLast: isLastItem,
          ),
        );
      } else if (stoppageMin > 0) {
        final stopMinStr = stoppageMin.toString().padLeft(2, '0');
        items.add(
          _buildTrackwickStoppageItem(
            title: 'Stoppage of 00:$stopMinStr',
            address: locAddrStr,
            isFirst: !hasPunchIn && i == 0,
            isLast: isLastItem,
          ),
        );
      } else {
        items.add(
          _buildTrackwickTravelledItem(
            title: timeFormatted.isNotEmpty
                ? 'Travelled ($timeFormatted)'
                : 'Travelled',
            distance: '',
            timeRange: timeFormatted,
            duration: '',
            isFirst: !hasPunchIn && i == 0,
            isLast: isLastItem,
          ),
        );
      }
    }

    // 3. Punch Out
    if (hasPunchOut) {
      items.add(
        _buildTrackwickPunchOutItem(
          title: 'Punch Out',
          time: clockOutTime,
          duration: '',
          address: punchOutAddress,
          isFirst: !hasPunchIn && !hasLocations,
          isLast: true,
        ),
      );
    }

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
    final visitState = ref.watch(fieldVisitProvider);
    if (visitState.attendanceData?['employee'] is Map) {
      return Map<String, dynamic>.from(visitState.attendanceData!['employee']);
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
