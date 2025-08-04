import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService with ChangeNotifier {
  WebSocketChannel? _channel;
  final _messages = <String>[];
  final _notifications = <String>[];

  List<String> get messages => _messages;
  List<String> get notifications => _notifications;

  bool get isConnected => _channel != null;

  void connect(String url, String token) {
    final uri = Uri.parse('$url?token=$token');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (data) {
        final decoded = json.decode(data);
        if (decoded['type'] == 'chat') {
          _messages.add(decoded['content']);
          notifyListeners();
        } else if (decoded['type'] == 'notification') {
          _notifications.add(decoded['content']);
          notifyListeners();
        }
      },
      onError: (e) {
        debugPrint("WebSocket error: $e");
      },
      onDone: () {
        _channel = null;
        notifyListeners();
      },
    );
  }

  void sendMessage(String message, String agentId) {
    if (_channel != null) {
      final payload = json.encode({
        'agent_id': agentId,
        'content': message,
        'type': 'chat',
      });
      _channel!.sink.add(payload);
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}
