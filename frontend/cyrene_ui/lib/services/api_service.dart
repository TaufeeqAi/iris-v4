import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import '../models/agent_config.dart';
import '../models/chat_message.dart';

class ApiService {
  final String token;

  ApiService(this.token);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<List<AgentConfig>> getAgents() async {
    try {
      print('🔍 [ApiService] Fetching agents...');
      print('➡️ Request headers: $_headers');
      print('➡️ URL: ${AppConfig.fastApiBotUrl}/agents/list');
      final response = await http.get(
        Uri.parse('${AppConfig.fastApiBotUrl}/agents/list'),
        headers: _headers,
      );
      print('⬅️ Response status: ${response.statusCode}');
      print('⬅️ Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => AgentConfig.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load agents: ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<AgentConfig> createAgent(Map<String, dynamic> agentData) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.fastApiBotUrl}/agents/create'),
        headers: _headers,
        body: jsonEncode(agentData),
      );

      if (response.statusCode == 201) {
        return AgentConfig.fromJson(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to create agent');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<AgentConfig> updateAgent(
    String agentId,
    Map<String, dynamic> agentData,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.fastApiBotUrl}/agents/$agentId'),
        headers: _headers,
        body: jsonEncode(agentData),
      );

      if (response.statusCode == 200) {
        return AgentConfig.fromJson(jsonDecode(response.body));
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to update agent');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> deleteAgent(String agentId) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.fastApiBotUrl}/agents/$agentId'),
        headers: _headers,
      );

      if (response.statusCode != 204) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Failed to delete agent');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<String> chatWithAgent(String agentId, String message) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.fastApiBotUrl}/agents/$agentId/chat'),
        headers: _headers,
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'No response received';
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Chat failed');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<List<ChatMessage>> getChatHistory(String agentId) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.fastApiBotUrl}/agents/$agentId/history'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) {
          return ChatMessage(
            id: json['id'],
            content: json['content'],
            type: json['type'] == 'user' ? MessageType.user : MessageType.agent,
            timestamp: DateTime.parse(json['timestamp']),
          );
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
