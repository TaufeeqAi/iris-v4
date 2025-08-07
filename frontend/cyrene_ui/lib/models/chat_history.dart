class ChatHistory {
  final String id;
  final String sessionId;
  final String role; // 'user', 'assistant', 'system'
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final List<String>? attachments;
  final String? parentMessageId; // For threading/replies

  ChatHistory({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.metadata,
    this.attachments,
    this.parentMessageId,
  });

  factory ChatHistory.fromJson(Map<String, dynamic> json) {
    return ChatHistory(
      id: json['id'],
      sessionId: json['session_id'],
      role: json['role'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      metadata: json['metadata'],
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'])
          : null,
      parentMessageId: json['parent_message_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
      'attachments': attachments,
      'parent_message_id': parentMessageId,
    };
  }
}
