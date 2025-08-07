// frontend/cyrene_ui/lib/models/chat_message.dart
import 'package:uuid/uuid.dart'; // Ensure this is imported for generating unique IDs

// Define MessageType enum if it's not already defined in this file
enum MessageType { user, agent, system, error }

class ChatMessage {
  final String id;
  final String sessionId; // NEW: Added sessionId
  final String
  role; // NEW: Added role (from backend, e.g., 'user', 'assistant')
  final String content;
  final MessageType
  type; // Used for UI display logic (user, agent, system, error)
  final DateTime timestamp;
  final bool isLoading;
  final bool isPartial; // NEW: Added isPartial for streaming
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.sessionId, // Make required
    required this.role, // Make required
    required this.content,
    required this.type, // Make required
    required this.timestamp,
    this.isLoading = false,
    this.isPartial = false, // Default to false
    this.metadata,
  });

  // Factory constructor for user messages
  factory ChatMessage.user(String content) {
    return ChatMessage(
      id: const Uuid().v4(), // Generate a unique ID
      sessionId:
          '', // Session ID will be set when sent to backend or received from history
      role: 'user', // Explicit role for user messages
      content: content,
      type: MessageType.user,
      timestamp: DateTime.now(),
      isLoading: false,
      isPartial: false,
    );
  }

  // Factory constructor for agent messages
  factory ChatMessage.agent(String content) {
    return ChatMessage(
      id: const Uuid().v4(), // Generate a unique ID
      sessionId: '', // Session ID will be set when received from history
      role: 'agent', // Explicit role for agent messages
      content: content,
      type: MessageType.agent,
      timestamp: DateTime.now(),
      isLoading: false,
      isPartial: false,
    );
  }

  // Factory constructor for error messages
  factory ChatMessage.error(String content) {
    return ChatMessage(
      id: const Uuid().v4(), // Generate a unique ID
      sessionId:
          '', // Session ID not directly relevant for a standalone error message
      role: 'system', // Error messages can be considered system messages
      content: content,
      type: MessageType.error,
      timestamp: DateTime.now(),
      isLoading: false,
      isPartial: false,
    );
  }

  // Factory constructor for a loading indicator message
  factory ChatMessage.loading() {
    return ChatMessage(
      id: 'loading', // A special, non-unique ID for a temporary loading message
      sessionId: '', // Not tied to a specific session ID for display purposes
      role: 'agent', // Loading is typically for an agent response
      content: '',
      type: MessageType.agent,
      timestamp: DateTime.now(),
      isLoading: true,
      isPartial: true, // A loading message is inherently partial/in-progress
    );
  }

  // Factory constructor to create a ChatMessage from a backend chat history JSON
  factory ChatMessage.fromChatHistory(Map<String, dynamic> json) {
    final String roleString = json['role'] as String;
    MessageType messageType;
    switch (roleString) {
      case 'user':
        messageType = MessageType.user;
        break;
      case 'assistant': // Backend might use 'assistant' role for AI responses
        messageType = MessageType.agent;
        break;
      case 'system':
        messageType = MessageType.system;
        break;
      default:
        messageType = MessageType.system; // Default for any unhandled roles
    }

    return ChatMessage(
      id: json['id'] as String,
      sessionId: json['session_id'] as String, // Parse session_id from backend
      role: roleString, // Keep the original role string from backend
      content: json['content'] as String,
      type: messageType, // Derive MessageType for UI logic
      timestamp: DateTime.parse(json['timestamp'] as String),
      isLoading: false, // Messages from history are generally not loading
      isPartial:
          json['is_partial'] as bool? ??
          false, // Parse is_partial, default to false
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  // Method to create a new ChatMessage instance with updated properties
  ChatMessage copyWith({
    String? id,
    String? sessionId,
    String? role,
    String? content,
    MessageType? type,
    DateTime? timestamp,
    bool? isLoading,
    bool? isPartial,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isLoading: isLoading ?? this.isLoading,
      isPartial: isPartial ?? this.isPartial,
      metadata: metadata ?? this.metadata,
    );
  }
}
