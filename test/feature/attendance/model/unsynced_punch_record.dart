import 'dart:convert';

class UnsyncedPunchRecord {
  final String id;
  final String type; // 'clockIn', 'clockOut', 'locationUpdate'
  final String timestamp; // ISO 8601 string, e.g. "2026-07-27T10:30:00.000Z"
  final double latitude;
  final double longitude;
  final String remarks;
  final String ipAddress;
  final String deviceInfo;
  final int empId;
  final int? timeInMinutes;
  final String? syncError;

  const UnsyncedPunchRecord({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.remarks = 'Visited client office',
    this.ipAddress = '192.168.1.10',
    this.deviceInfo = 'Android Device',
    required this.empId,
    this.timeInMinutes,
    this.syncError,
  });

  DateTime get dateTime {
    try {
      final str = timestamp;
      String isoStr = str;
      if (str.contains('T') && !str.endsWith('Z') && !str.contains('+')) {
        final timePart = str.split('T').last;
        if (!timePart.contains('+') && !timePart.contains('-')) {
          isoStr = '${str}Z';
        }
      }
      return DateTime.parse(isoStr).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  String get formattedDate {
    final dt = dateTime;
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$day/$month/$year';
  }

  String get formattedTime {
    final dt = dateTime;
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final hourStr = hour.toString().padLeft(2, '0');
    return '$hourStr:$minute $period';
  }

  String get displayType {
    switch (type) {
      case 'clockIn':
        return 'Punch In';
      case 'clockOut':
        return 'Punch Out';
      case 'locationUpdate':
        return 'Location Update';
      default:
        return 'Punch Event';
    }
  }

  UnsyncedPunchRecord copyWith({
    String? id,
    String? type,
    String? timestamp,
    double? latitude,
    double? longitude,
    String? remarks,
    String? ipAddress,
    String? deviceInfo,
    int? empId,
    int? timeInMinutes,
    String? syncError,
  }) {
    return UnsyncedPunchRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      remarks: remarks ?? this.remarks,
      ipAddress: ipAddress ?? this.ipAddress,
      deviceInfo: deviceInfo ?? this.deviceInfo,
      empId: empId ?? this.empId,
      timeInMinutes: timeInMinutes ?? this.timeInMinutes,
      syncError: syncError ?? this.syncError,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'timestamp': timestamp,
      'latitude': latitude,
      'longitude': longitude,
      'remarks': remarks,
      'ipAddress': ipAddress,
      'deviceInfo': deviceInfo,
      'empId': empId,
      'timeInMinutes': timeInMinutes,
      'syncError': syncError,
    };
  }

  factory UnsyncedPunchRecord.fromMap(Map<String, dynamic> map) {
    return UnsyncedPunchRecord(
      id: map['id']?.toString() ?? '',
      type: map['type']?.toString() ?? 'clockIn',
      timestamp: map['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      remarks: map['remarks']?.toString() ?? 'Visited client office',
      ipAddress: map['ipAddress']?.toString() ?? '192.168.1.10',
      deviceInfo: map['deviceInfo']?.toString() ?? 'Android Device',
      empId: (map['empId'] as num?)?.toInt() ?? 7,
      timeInMinutes: (map['timeInMinutes'] as num?)?.toInt(),
      syncError: map['syncError']?.toString(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UnsyncedPunchRecord.fromJson(String source) =>
      UnsyncedPunchRecord.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
