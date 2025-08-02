class AgentConfig {
  final String? id;
  final String name;
  final String modelProvider;
  final String? system;
  final List<String>? bio;
  final List<String>? lore;
  final List<String>? knowledge;
  final Map<String, dynamic> settings;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AgentConfig({
    this.id,
    required this.name,
    required this.modelProvider,
    this.system,
    this.bio,
    this.lore,
    this.knowledge,
    required this.settings,
    this.createdAt,
    this.updatedAt,
  });

  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    return AgentConfig(
      id: json['id'],
      name: json['name'],
      modelProvider: json['modelProvider'],
      system: json['system'],
      bio: json['bio'] != null ? List<String>.from(json['bio']) : null,
      lore: json['lore'] != null ? List<String>.from(json['lore']) : null,
      knowledge: json['knowledge'] != null
          ? List<String>.from(json['knowledge'])
          : null,
      settings: json['settings'] ?? {},
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'modelProvider': modelProvider,
      'system': system,
      'bio': bio,
      'lore': lore,
      'knowledge': knowledge,
      'settings': settings,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  AgentConfig copyWith({
    String? id,
    String? name,
    String? modelProvider,
    String? system,
    List<String>? bio,
    List<String>? lore,
    List<String>? knowledge,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AgentConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      modelProvider: modelProvider ?? this.modelProvider,
      system: system ?? this.system,
      bio: bio ?? this.bio,
      lore: lore ?? this.lore,
      knowledge: knowledge ?? this.knowledge,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
