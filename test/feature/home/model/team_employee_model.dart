class TeamEmployee {
  final int id;
  final String name;
  final String? image;
  final List<TeamEmployee> team;

  TeamEmployee({
    required this.id,
    required this.name,
    this.image,
    required this.team,
  });

  factory TeamEmployee.fromJson(Map<String, dynamic> json) {
    return TeamEmployee(
      id: json['id'] is int
          ? json['id']
          : (int.tryParse(json['id']?.toString() ?? '') ?? 0),
      name: json['name'] ?? '',
      image: json['image'],
      team: json['team'] != null
          ? (json['team'] as List).map((e) => TeamEmployee.fromJson(e)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image,
      'team': team.map((e) => e.toJson()).toList(),
    };
  }
}
