import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/services/voice_recording_service.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/widgets/voice_recording_overlay.dart';

class ChatInputBar extends ConsumerStatefulWidget {
  final String groupId;
  final bool showAttachmentMenu;
  final VoidCallback onToggleAttachments;
  final Function(String) onSendText;
  final Function(String voiceUrl, int duration, int fileSize) onSendVoice;

  const ChatInputBar({
    super.key,
    required this.groupId,
    required this.showAttachmentMenu,
    required this.onToggleAttachments,
    required this.onSendText,
    required this.onSendVoice,
  });

  @override
  ConsumerState<ChatInputBar> createState() =>
      _ChatInputBarState();
}

class _ChatInputBarState
    extends ConsumerState<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final VoiceRecordingService _voiceService = VoiceRecordingService();
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {}); // Rebuild when text changes
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final success = await _voiceService.startRecording();
    if (success) {
      setState(() => _isRecording = true);
    } else {
      _showError(
          'Failed to start recording. Please check microphone permission.');
    }
  }

  Future<void> _cancelRecording() async {
    await _voiceService.cancelRecording();
    setState(() => _isRecording = false);
  }

  Future<void> _sendVoiceMessage() async {
    final filePath = await _voiceService.stopRecording();
    setState(() => _isRecording = false);

    if (filePath == null) {
      _showError('Failed to save recording');
      return;
    }

    // Show loading
    _showLoading();

    // Get current user
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) {
      Navigator.of(context).pop();
      _showError('User not logged in');
      return;
    }

    // Upload voice message
    final result = await _voiceService.uploadVoiceMessage(
      filePath: filePath,
      groupId: widget.groupId,
      senderId: currentUser.uid,
    );

    Navigator.of(context).pop(); // Close loading

    if (result != null) {
      widget.onSendVoice(
        result['url'],
        result['duration'],
        result['fileSize'],
      );
    } else {
      _showError('Failed to upload voice message');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendText(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show recording overlay when recording
        if (_isRecording)
          VoiceRecordingOverlay(
            onCancel: _cancelRecording,
            onSend: _sendVoiceMessage,
          ),

        // Normal input bar
        if (!_isRecording)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Attachment toggle button
                        IconButton(
                          icon: Icon(
                            widget.showAttachmentMenu ? Icons.close : Icons.add,
                            color: const Color(0xFF075E54),
                          ),
                          onPressed: widget.onToggleAttachments,
                        ),
                        
                        // Text input
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              hintText: 'Message',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _sendText(),
                          ),
                        ),
                        
                        // Emoji button (optional)
                        IconButton(
                          icon: const Icon(
                            Icons.emoji_emotions_outlined,
                            color: Color(0xFF075E54),
                          ),
                          onPressed: () {
                            // TODO: Show emoji picker
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Emoji picker - Coming soon!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Send/Mic button
                FloatingActionButton(
                  onPressed: _controller.text.trim().isEmpty
                      ? _startRecording
                      : _sendText,
                  backgroundColor: const Color(0xFF075E54),
                  mini: true,
                  elevation: 2,
                  child: Icon(
                    _controller.text.trim().isEmpty ? Icons.mic : Icons.send,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}