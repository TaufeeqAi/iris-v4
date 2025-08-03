import 'dart:convert';

class AgentConfig {
  final String? id;
  final String name;
  final String modelProvider;
  final String? system;
  final List<String>? bio;
  final List<String>? lore;
  final List<String>? knowledgeAreas;
  final List<dynamic>? messageExamples; // Changed to a single list of messages
  final String? style; // Changed to a String
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
    this.knowledgeAreas,
    this.messageExamples,
    this.style,
    required this.settings,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to create an AgentConfig from a JSON map.
  factory AgentConfig.fromJson(Map<String, dynamic> json) {
    return AgentConfig(
      id: json['id'],
      name: json['name'],
      modelProvider: json['modelProvider'],
      system: json['system'],
      bio: json['bio'] != null ? List<String>.from(json['bio']) : null,
      lore: json['lore'] != null ? List<String>.from(json['lore']) : null,
      knowledgeAreas: json['knowledgeAreas'] != null
          ? List<String>.from(json['knowledgeAreas'])
          : null,
      // Parse messageExamples as a simple list.
      messageExamples: json['messageExamples'] != null
          ? List<dynamic>.from(json['messageExamples'])
          : null,
      // The style is stored as a string, but the API may expect a map
      // so this needs to be handled in the UI.
      style: json['style'] is String
          ? json['style'] as String
          : jsonEncode(json['style']),
      settings: json['settings'] ?? {},
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  /// Converts the AgentConfig instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'modelProvider': modelProvider,
      'system': system,
      'bio': bio,
      'lore': lore,
      'knowledgeAreas': knowledgeAreas,
      'messageExamples': messageExamples,
      'style': style,
      'settings': settings,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Creates a new AgentConfig instance with updated values.
  AgentConfig copyWith({
    String? id,
    String? name,
    String? modelProvider,
    String? system,
    List<String>? bio,
    List<String>? lore,
    List<String>? knowledgeAreas,
    List<dynamic>? messageExamples,
    String? style,
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
      knowledgeAreas: knowledgeAreas ?? this.knowledgeAreas,
      messageExamples: messageExamples ?? this.messageExamples,
      style: style ?? this.style,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
