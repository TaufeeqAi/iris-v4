import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class EnhancedChatInput extends StatefulWidget {
  final Function(String, {List<String>? attachments}) onSendMessage;
  final bool enabled;
  final VoidCallback? onVoicePressed;
  final VoidCallback? onAttachPressed;

  const EnhancedChatInput({
    super.key,
    required this.onSendMessage,
    this.enabled = true,
    this.onVoicePressed,
    this.onAttachPressed,
  });

  @override
  State<EnhancedChatInput> createState() => _EnhancedChatInputState();
}

class _EnhancedChatInputState extends State<EnhancedChatInput> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<PlatformFile> _attachedFiles = [];
  bool _isRecording = false;

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty && _attachedFiles.isEmpty) return;

    final attachmentPaths = _attachedFiles
        .map((file) => file.path ?? '')
        .where((path) => path.isNotEmpty)
        .toList();

    widget.onSendMessage(
      text,
      attachments: attachmentPaths.isNotEmpty ? attachmentPaths : null,
    );

    _textController.clear();
    setState(() {
      _attachedFiles.clear();
    });
  }

  Future<void> _handleAttachment() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null) {
        setState(() {
          _attachedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking files: $e')));
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
  }

  void _handleVoiceInput() {
    setState(() {
      _isRecording = !_isRecording;
    });

    if (_isRecording) {
      // Start recording
      widget.onVoicePressed?.call();
    } else {
      // Stop recording
      widget.onVoicePressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Attached files preview
          if (_attachedFiles.isNotEmpty) _buildAttachmentsPreview(),

          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment button
              IconButton(
                onPressed: widget.enabled ? _handleAttachment : null,
                icon: Icon(
                  Icons.attach_file,
                  color: widget.enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.38),
                ),
                tooltip: 'Attach files',
              ),

              // Text input
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type your message...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: widget.enabled ? (_) => _sendMessage() : null,
                  ),
                ),
              ),

              // Voice button
              IconButton(
                onPressed: widget.enabled ? _handleVoiceInput : null,
                icon: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  color: _isRecording
                      ? Colors.red
                      : widget.enabled
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.38),
                ),
                tooltip: _isRecording ? 'Stop recording' : 'Voice input',
              ),

              // Send button
              IconButton(
                onPressed:
                    widget.enabled &&
                        (_textController.text.trim().isNotEmpty ||
                            _attachedFiles.isNotEmpty)
                    ? _sendMessage
                    : null,
                icon: Icon(
                  Icons.send,
                  color:
                      widget.enabled &&
                          (_textController.text.trim().isNotEmpty ||
                              _attachedFiles.isNotEmpty)
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.38),
                ),
                tooltip: 'Send message',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsPreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _attachedFiles.asMap().entries.map((entry) {
          final index = entry.key;
          final file = entry.value;

          return Chip(
            avatar: Icon(_getFileIcon(file.extension ?? ''), size: 16),
            label: Text(file.name, style: const TextStyle(fontSize: 12)),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => _removeAttachment(index),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }).toList(),
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'txt':
        return Icons.text_snippet;
      case 'doc':
      case 'docx':
        return Icons.description;
      default:
        return Icons.attach_file;
    }
  }
}
