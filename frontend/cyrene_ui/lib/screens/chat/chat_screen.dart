import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/chat_message.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input.dart';
import '../../widgets/chat/typing_indicator.dart';
import '../../widgets/common/empty_state.dart';

class ChatScreen extends StatefulWidget {
  final String? agentId;
  final String? agentName;

  const ChatScreen({super.key, this.agentId, this.agentName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    if (widget.agentId != null) {
      _loadChatHistory();
    }
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.agentId != oldWidget.agentId) {
      _messages.clear();
      if (widget.agentId != null) {
        _loadChatHistory();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    if (widget.agentId == null) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService.token!);

      final history = await apiService.getChatHistory(widget.agentId!);
      setState(() {
        _messages.clear();
        _messages.addAll(history);
      });

      _scrollToBottom();
    } catch (e) {
      // Handle error silently for now
      debugPrint('Error loading chat history: $e');
    }
  }

  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty || widget.agentId == null) return;

    final userMessage = ChatMessage.user(message);
    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });

    _scrollToBottom();

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = ApiService(authService.token!);

      final response = await apiService.chatWithAgent(widget.agentId!, message);

      final agentMessage = ChatMessage.agent(response);
      setState(() {
        _messages.add(agentMessage);
      });
    } catch (e) {
      final errorMessage = ChatMessage.error('Error: ${e.toString()}');
      setState(() {
        _messages.add(errorMessage);
      });
    } finally {
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();
    }
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
        content: const Text('Are you sure you want to clear the chat history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _messages.clear();
              });
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
    if (widget.agentId == null) {
      return EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'No Agent Selected',
        subtitle:
            'Please select an agent from the "Agents" tab to start chatting.',
        action: ElevatedButton.icon(
          onPressed: () {
            // TODO: Navigate to agents tab
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
        if (_isTyping) const TypingIndicator(),
        ChatInput(onSendMessage: _sendMessage, enabled: !_isTyping),
      ],
    );
  }

  Widget _buildChatHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.agentName ?? 'Agent',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Online',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.green),
                ),
              ],
            ),
          ),
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

  Widget _buildChatArea() {
    if (_messages.isEmpty) {
      return EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'Start a Conversation',
        subtitle:
            'Send a message to ${widget.agentName ?? 'your agent'} to begin chatting.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isLastMessage = index == _messages.length - 1;
        final showAvatar =
            index == 0 || _messages[index - 1].type != message.type;

        return MessageBubble(
          message: message,
          showAvatar: showAvatar,
          isLastMessage: isLastMessage,
        );
      },
    );
  }
}
