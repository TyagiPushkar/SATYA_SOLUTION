class EmployeeModel {
  final int id;
  final String? name;
  final int? managerId;
  final String? identity;
  final String? image;
  final String? department;
  final String? team;
  final String? gender;
  final String? bloodGroup;
  final String? labelColor;
  final String? email;
  final String? designations;
  final String? mobile;
  final String? workShift;
  final String? status;
  final String? workLocation;
  final dynamic type;
  final String? empType;
  final String? businessUnit;
  final String? license;
  final String? costCenter;
  final dynamic roleId;
  final String? appVersion;
  final String? desktopVersion;
  final String? lastDesktopStartedAt;
  final String? lastSyncDesktopAt;
  final String? lastSyncMobile;
  final String? lastLocation;
  final String? location;
  final String? address;
  final String? dateOfBirth;
  final String? dateOfJoining;
  final dynamic stateId;
  final String? slug;
  final dynamic regionId;
  final dynamic branchId;
  final String? punchIn;
  final String? punchOut;
  final String? entryAlerts;
  final String? exitAlerts;
  final Map<String, dynamic>? createdBy;
  final Map<String, dynamic>? updatedBy;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic>? manager;
  final Map<String, dynamic>? role;

  EmployeeModel({
    required this.id,
    this.name,
    this.managerId,
    this.identity,
    this.image,
    this.department,
    this.team,
    this.gender,
    this.bloodGroup,
    this.labelColor,
    this.email,
    this.designations,
    this.mobile,
    this.workShift,
    this.status,
    this.workLocation,
    this.type,
    this.empType,
    this.businessUnit,
    this.license,
    this.costCenter,
    this.roleId,
    this.appVersion,
    this.desktopVersion,
    this.lastDesktopStartedAt,
    this.lastSyncDesktopAt,
    this.lastSyncMobile,
    this.lastLocation,
    this.location,
    this.address,
    this.dateOfBirth,
    this.dateOfJoining,
    this.stateId,
    this.slug,
    this.regionId,
    this.branchId,
    this.punchIn,
    this.punchOut,
    this.entryAlerts,
    this.exitAlerts,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.manager,
    this.role,
  });

  String get roleName {
    if (role != null && role!['name'] != null) {
      return role!['name'].toString();
    }
    if (roleId is Map && (roleId as Map)['name'] != null) {
      return (roleId as Map)['name'].toString();
    }
    if (type is Map && (type as Map)['name'] != null) {
      return (type as Map)['name'].toString();
    }
    if (type is String && (type as String).isNotEmpty) {
      return type as String;
    }
    return identity ?? 'Admin';
  }

  String get roleSlug {
    if (role != null && role!['slug'] != null) {
      return role!['slug'].toString();
    }
    if (roleId is Map && (roleId as Map)['slug'] != null) {
      return (roleId as Map)['slug'].toString();
    }
    if (type is Map && (type as Map)['slug'] != null) {
      return (type as Map)['slug'].toString();
    }
    if (type is String && (type as String).isNotEmpty) {
      return (type as String).toLowerCase();
    }
    return 'admin';
  }

  static String? _parseString(dynamic val) {
    if (val == null) return null;
    if (val is String) return val;
    if (val is Map) {
      if (val['name'] != null) return val['name'].toString();
      if (val['title'] != null) return val['title'].toString();
      if (val['label'] != null) return val['label'].toString();
      if (val['slug'] != null) return val['slug'].toString();
    }
    return val.toString();
  }

  static Map<String, dynamic>? _parseMap(dynamic val) {
    if (val == null) return null;
    if (val is Map) return Map<String, dynamic>.from(val);
    return null;
  }

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: (json['id'] is int)
          ? json['id']
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      name: _parseString(json['name']),
      managerId: (json['manager_id'] is int)
          ? json['manager_id']
          : int.tryParse(json['manager_id']?.toString() ?? ''),
      identity: _parseString(json['identity']),
      image: _parseString(json['image']),
      department: _parseString(json['department']),
      team: _parseString(json['team']),
      gender: _parseString(json['gender']),
      bloodGroup: _parseString(json['blood_group']),
      labelColor: _parseString(json['label_color']),
      email: _parseString(json['email']),
      designations: _parseString(json['designations']),
      mobile: _parseString(json['mobile']),
      workShift: _parseString(json['work_shift']),
      status: _parseString(json['status']),
      workLocation: _parseString(json['work_location']),
      type: json['type'],
      empType: _parseString(json['emp_type']),
      businessUnit: _parseString(json['business_unit']),
      license: _parseString(json['license']),
      costCenter: _parseString(json['cost_center']),
      roleId: json['role_id'],
      appVersion: _parseString(json['app_version']),
      desktopVersion: _parseString(json['desktop_version']),
      lastDesktopStartedAt: _parseString(json['last_desktop_started_at']),
      lastSyncDesktopAt: _parseString(json['last_Sync_desktop_at']),
      lastSyncMobile: _parseString(json['last_Sync_mobile']),
      lastLocation: _parseString(json['last_location']),
      location: _parseString(json['location']),
      address: _parseString(json['address']),
      dateOfBirth: _parseString(json['date_of_birth']),
      dateOfJoining: _parseString(json['date_of_joining']),
      stateId: json['state_id'],
      slug: _parseString(json['slug']),
      regionId: json['region_id'],
      branchId: json['branch_id'],
      punchIn: _parseString(json['punchIn']),
      punchOut: _parseString(json['punchOut']),
      entryAlerts: _parseString(json['entryAlerts']),
      exitAlerts: _parseString(json['exitAlerts']),
      createdBy: _parseMap(json['createdBy']),
      updatedBy: _parseMap(json['updatedBy']),
      createdAt: _parseString(json['createdAt']),
      updatedAt: _parseString(json['updatedAt']),
      manager: _parseMap(json['manager']),
      role: _parseMap(json['role']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'manager_id': managerId,
      'identity': identity,
      'image': image,
      'department': department,
      'team': team,
      'gender': gender,
      'blood_group': bloodGroup,
      'label_color': labelColor,
      'email': email,
      'designations': designations,
      'mobile': mobile,
      'work_shift': workShift,
      'status': status,
      'work_location': workLocation,
      'type': type,
      'emp_type': empType,
      'business_unit': businessUnit,
      'license': license,
      'cost_center': costCenter,
      'role_id': roleId,
      'app_version': appVersion,
      'desktop_version': desktopVersion,
      'last_desktop_started_at': lastDesktopStartedAt,
      'last_Sync_desktop_at': lastSyncDesktopAt,
      'last_Sync_mobile': lastSyncMobile,
      'last_location': lastLocation,
      'location': location,
      'address': address,
      'date_of_birth': dateOfBirth,
      'date_of_joining': dateOfJoining,
      'state_id': stateId,
      'slug': slug,
      'region_id': regionId,
      'branch_id': branchId,
      'punchIn': punchIn,
      'punchOut': punchOut,
      'entryAlerts': entryAlerts,
      'exitAlerts': exitAlerts,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'manager': manager,
      'role': role,
    };
  }
}
