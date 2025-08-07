import 'package:cyrene_ui/models/agent_config.dart';
import 'package:cyrene_ui/models/chat_message.dart';
import 'package:cyrene_ui/services/api_service.dart';
import 'package:cyrene_ui/services/auth_service.dart';
import 'package:cyrene_ui/services/chat_service.dart';
// import 'package:cyrene_ui/services/websocket_services.dart'; // REMOVED: No longer directly used here
import 'package:cyrene_ui/widgets/chat/chat_input.dart';
import 'package:cyrene_ui/widgets/chat/message_bubble.dart';
import 'package:cyrene_ui/widgets/chat/streaming_message_bubble.dart';
import 'package:cyrene_ui/widgets/common/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Ensure 'provider' is in your pubspec.yaml
import 'dart:async'; // For StreamSubscription
import 'package:flutter/foundation.dart'; // For debugPrint

class ChatScreen extends StatefulWidget {
  final String? agentId;
  final String? agentName;
  final String? sessionId;
  final bool? showAllHistory;

  const ChatScreen({
    super.key,
    this.agentId,
    this.agentName,
    this.sessionId,
    this.showAllHistory,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  // bool _isTyping = false; // REMOVED: Redundant, use _isStreamingResponse
  bool _isStreamingResponse = false;

  List<AgentConfig> _availableAgents = [];
  String? _currentAgentId;
  String? _currentAgentName;
  String? _currentSessionId;
  String? _currentUserId; // To store the authenticated user's ID

  late ChatService _chatService;
  StreamSubscription<ChatMessage>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _currentAgentId = widget.agentId;
    _currentAgentName = widget.agentName;
    _currentSessionId = widget.sessionId;

    // Initialize ChatService and get user ID
    _chatService = Provider.of<ChatService>(context, listen: false);
    _currentUserId = Provider.of<AuthService>(
      context,
      listen: false,
    ).userId; // Get user ID from AuthService

    _loadAvailableAgents();

    // Load chat history if a session is provided
    if (_currentAgentId != null) {
      _loadChatHistory();
    }

    // Always initialize WebSocket connection when the screen is active,
    // it will connect to the appropriate session when _currentSessionId is set.
    // If _currentSessionId is null initially, the connection will be established
    // once a new session is created.
    _initializeWebSocket();
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.agentId != oldWidget.agentId ||
        widget.sessionId != oldWidget.sessionId) {
      _messages.clear();
      _currentAgentId = widget.agentId;
      _currentAgentName = widget.agentName;
      _currentSessionId = widget.sessionId;

      if (_currentAgentId != null) {
        _loadChatHistory();
      }
      // Re-initialize WebSocket connection if session changes
      _initializeWebSocket();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageSubscription?.cancel(); // Cancel the stream subscription
    _chatService.disconnectChatWebSocket(); // Disconnect WebSocket
    super.dispose();
  }

  Future<void> _loadAvailableAgents() async {
    try {
      // Use `mounted` check before accessing context after an async operation
      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService.token!);

      final agents = await apiService.getAgents();
      if (!mounted) return; // Check again before setState
      setState(() {
        _availableAgents = agents;
      });
    } catch (e) {
      debugPrint('Error loading agents: $e');
      // Optionally show a snackbar or error message
    }
  }

  // Updated WebSocket initialization to use ChatService's stream
  Future<void> _initializeWebSocket() async {
    // Cancel any existing subscription before creating a new one
    _messageSubscription?.cancel();

    // Connect to WebSocket if a session ID is available
    if (_currentSessionId != null) {
      try {
        await _chatService.connectChatWebSocket(_currentSessionId!);
        _messageSubscription = _chatService.messages.listen(
          (message) {
            if (!mounted) return; // Check mounted before setState
            setState(() {
              if (message.isPartial) {
                // If it's a partial message, find the last agent message and append/update
                if (_messages.isNotEmpty &&
                    _messages.last.role == 'agent' &&
                    _messages.last.isPartial) {
                  // Update the content of the existing partial message
                  _messages.last = _messages.last.copyWith(
                    content: _messages.last.content + message.content,
                    isLoading: true, // Keep loading state for partials
                    isPartial: true, // Ensure it remains partial
                  );
                } else {
                  // Add a new partial message (e.g., first chunk)
                  _messages.add(
                    ChatMessage(
                      id: message
                          .id, // Use the ID from the backend for partials
                      sessionId: message.sessionId,
                      role: message.role,
                      content: message.content,
                      type: message.type, // FIX: Pass the 'type' here
                      timestamp: message.timestamp,
                      isPartial: true,
                      isLoading: true,
                    ),
                  );
                }
                _isStreamingResponse = true; // Indicate streaming is active
              } else {
                // This is a complete message (user's echo or agent's final response)
                // If the last message was a partial agent message, update it to be complete
                if (_messages.isNotEmpty &&
                    _messages.last.role == 'agent' &&
                    _messages.last.isPartial) {
                  _messages.last = _messages.last.copyWith(
                    content:
                        _messages.last.content +
                        message.content, // Append final chunk
                    isPartial: false, // Mark as complete
                    isLoading: false,
                  );
                } else {
                  // Add as a new complete message
                  _messages.add(message.copyWith(isLoading: false));
                }
                _isStreamingResponse = false; // Streaming is complete
              }
            });
            _scrollToBottom();
          },
          onError: (error) {
            debugPrint('WebSocket Stream Error: $error');
            _handleStreamingError(error.toString());
          },
          onDone: () {
            debugPrint('WebSocket Stream Done.');
            if (!mounted) return; // Check mounted before setState
            setState(() {
              _isStreamingResponse = false;
            });
          },
        );
      } catch (e) {
        debugPrint(
          'Failed to connect WebSocket for session $_currentSessionId: $e',
        );
        // Handle connection error, e.g., show a snackbar
        if (!mounted) return; // Check mounted before accessing context
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to real-time chat: $e')),
        );
      }
    } else {
      debugPrint(
        'No session ID available to connect WebSocket. Will connect on first message.',
      );
    }
  }

  Future<void> _loadChatHistory() async {
    if (_currentSessionId == null) {
      return;
    }

    try {
      final history = await _chatService.getChatSessionHistory(
        _currentSessionId!,
      );
      if (!mounted) return; // Check mounted before setState
      setState(() {
        _messages.clear();
        _messages.addAll(history);
      });

      _scrollToBottom();
      // After loading history, connect WebSocket to this session
      await _initializeWebSocket(); // Re-initialize WebSocket for the loaded session
    } catch (e) {
      debugPrint('Error loading chat history: $e');
      // Optionally show a snackbar or error message
      if (!mounted) return; // Check mounted before accessing context
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load chat history: $e')),
      );
    }
  }

  Future<void> _switchAgent(String agentId, String agentName) async {
    setState(() {
      _currentAgentId = agentId;
      _currentAgentName = agentName;
      _messages.clear();
      _currentSessionId = null; // Will create new session on first message
      _isStreamingResponse = false; // Reset streaming state
    });
    _chatService
        .disconnectChatWebSocket(); // Disconnect old session's WebSocket
    // _initializeWebSocket() will be called on the first message if _currentSessionId is null
  }

  Future<void> _sendMessage(String message, {List<String>? attachments}) async {
    if (message.trim().isEmpty ||
        _currentAgentId == null ||
        _currentUserId == null) {
      return;
    }

    // Add user message to UI immediately
    final userMessage = ChatMessage.user(message);
    if (!mounted) return; // Check mounted before setState
    setState(() {
      _messages.add(userMessage);
      _isStreamingResponse =
          true; // Indicate that we expect a streaming response
    });
    _scrollToBottom();

    try {
      // Create new session if needed
      if (_currentSessionId == null) {
        _currentSessionId = await _createNewChatSession(message);
        // After creating a new session, connect the WebSocket to it
        await _initializeWebSocket();
      }

      // Send message via REST API (response will come via WebSocket)
      await _chatService.sendChatMessage(
        sessionId: _currentSessionId!,
        content: message,
      );
      debugPrint(
        'User message sent to REST API for session $_currentSessionId',
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
      _handleStreamingError(e.toString());
    }
  }

  Future<String> _createNewChatSession(String firstMessage) async {
    try {
      final title = firstMessage.length > 50
          ? '${firstMessage.substring(0, 50)}...'
          : firstMessage;

      final session = await _chatService.createChatSession(
        userId: _currentUserId!, // Pass the current user ID here
        agentId: _currentAgentId!,
        title: title,
      );
      debugPrint('New chat session created: ${session.id}');
      return session.id;
    } catch (e) {
      debugPrint('Failed to create chat session: $e');
      throw Exception('Failed to create chat session: $e');
    }
  }

  void _handleStreamingError(String error) {
    final errorMessage = ChatMessage.error('Error: $error');
    if (!mounted) return; // Check mounted before setState
    setState(() {
      _messages.add(errorMessage);
      _isStreamingResponse = false;
    });
    _scrollToBottom();
    if (!mounted) return; // Check mounted before accessing context
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Chat error: $error')));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text(
          'Are you sure you want to clear the current chat session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Made async to await deletion
              Navigator.of(context).pop();
              if (_currentSessionId != null) {
                try {
                  await _chatService.deleteChatSession(_currentSessionId!);
                  debugPrint(
                    'Chat session $_currentSessionId deleted from backend.',
                  );
                } catch (e) {
                  debugPrint('Error deleting chat session from backend: $e');
                  if (!mounted)
                    return; // Check mounted before accessing context
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete session: $e')),
                  );
                }
              }
              if (!mounted) return; // Check mounted before setState
              setState(() {
                _messages.clear();
                _currentSessionId = null;
                _isStreamingResponse = false;
              });
              _chatService
                  .disconnectChatWebSocket(); // Disconnect WebSocket after clearing
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentAgentId == null) {
      return EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No Agent Selected',
        subtitle: 'Please select an agent to start chatting.',
        action: ElevatedButton.icon(
          onPressed: () {
            // TODO: Navigate to agents tab
            // For now, let's just print a message
            debugPrint('Navigate to agents tab functionality not implemented.');
          },
          icon: const Icon(Icons.smart_toy),
          label: const Text('View Agents'),
        ),
      );
    }

    return Column(
      children: [
        _buildChatHeader(),
        Expanded(child: _buildChatArea()),
        EnhancedChatInput(
          onSendMessage: _sendMessage,
          enabled: !_isStreamingResponse,
          onVoicePressed: _handleVoiceInput,
          onAttachPressed: _handleAttachment,
        ),
      ],
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(
          (255 * 0.3).round(),
        ), // FIX: Deprecated member use
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(
              (255 * 0.2).round(),
            ), // FIX: Deprecated member use
          ),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.psychology, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildAgentDropdown()),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChatHistory,
            tooltip: 'Refresh chat',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearChat,
            tooltip: 'Clear chat',
          ),
        ],
      ),
    );
  }

  Widget _buildAgentDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _currentAgentId,
        isExpanded: true,
        items: _availableAgents.map((agent) {
          return DropdownMenuItem<String>(
            value: agent.id,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  agent.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Online', // Assuming agents are always online for now
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.green),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (String? newAgentId) {
          if (newAgentId != null) {
            final selectedAgent = _availableAgents.firstWhere(
              (agent) => agent.id == newAgentId,
            );
            _switchAgent(newAgentId, selectedAgent.name);
          }
        },
      ),
    );
  }

  Widget _buildChatArea() {
    // Check if there are no messages AND no streaming response
    if (_messages.isEmpty && !_isStreamingResponse) {
      return EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'Start a Conversation',
        subtitle:
            'Send a message to ${_currentAgentName ?? 'your agent'} to begin chatting.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isLastMessage = index == _messages.length - 1;

        // Determine if avatar should be shown (first message or type change)
        final showAvatar =
            index == 0 || _messages[index - 1].type != message.type;

        // If the last message is partial and we are streaming, display it as a streaming bubble
        // Otherwise, use the regular MessageBubble
        if (isLastMessage && message.isPartial && _isStreamingResponse) {
          return StreamingMessageBubble(content: message.content);
        } else {
          return MessageBubble(
            message: message,
            showAvatar: showAvatar,
            isLastMessage: isLastMessage,
          );
        }
      },
    );
  }

  void _handleVoiceInput() {
    // TODO: Implement voice input
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Voice input coming soon!')));
  }

  void _handleAttachment() {
    // TODO: Implement file attachment
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File attachment coming soon!')),
    );
  }
}
