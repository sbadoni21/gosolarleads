import 'dart:io' show Platform;
import 'package:characters/characters.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
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
  ConsumerState<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final VoiceRecordingService _voiceService = VoiceRecordingService();

  bool _isRecording = false;
  bool _showEmoji = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmoji) {
        setState(() => _showEmoji = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _voiceService.dispose();
    super.dispose();
  }

  // --- Voice ---
  Future<void> _startRecording() async {
    final ok = await _voiceService.startRecording();
    if (!ok) return _err('Failed to start recording. Check mic permission.');
    setState(() => _isRecording = true);
  }

  Future<void> _cancelRecording() async {
    await _voiceService.cancelRecording();
    setState(() => _isRecording = false);
  }

  Future<void> _sendVoiceMessage() async {
    final filePath = await _voiceService.stopRecording();
    setState(() => _isRecording = false);
    if (filePath == null) return _err('Failed to save recording');

    _loading();
    final me = ref.read(currentUserProvider).value;
    if (me == null) {
      Navigator.pop(context);
      return _err('User not logged in');
    }
    final res = await _voiceService.uploadVoiceMessage(
      filePath: filePath,
      groupId: widget.groupId,
      senderId: me.uid,
    );
    Navigator.pop(context);
    if (res == null) return _err('Failed to upload voice message');

    widget.onSendVoice(res['url'], res['duration'], res['fileSize']);
  }

  // --- Text ---
  void _sendText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendText(text);
    _controller.clear();
  }

  // --- Emoji ---
  void _toggleEmojiPicker() async {
    if (_showEmoji) {
      setState(() => _showEmoji = false);
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
      await Future.delayed(const Duration(milliseconds: 50));
      setState(() => _showEmoji = true);
    }
  }

  // NOTE: signature must be (Category? category, Emoji emoji)
  void _onEmojiSelected(Category? _, Emoji emoji) {
    final text = _controller.text;
    final sel = _controller.selection;
    final ins = emoji.emoji;
    final start = sel.start == -1 ? text.length : sel.start;
    final end = sel.end == -1 ? text.length : sel.end;

    final newText = text.replaceRange(start, end, ins);
    final caret = start + ins.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  void _onBackspacePressed() {
    final text = _controller.text;
    final sel = _controller.selection;

    if (text.isEmpty) return;

    // delete selection if any
    if (sel.start != sel.end && sel.start >= 0 && sel.end >= 0) {
      final newText = text.replaceRange(sel.start, sel.end, '');
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start),
      );
      return;
    }

    // delete last grapheme
    final caret = sel.start == -1 ? text.length : sel.start;
    if (caret == 0) return;

    final chars = text.characters.toList();
    // index of grapheme before caret
    final idxBefore = text.characters.take(caret).length - 1;
    if (idxBefore < 0) return;
    chars.removeAt(idxBefore);
    final newText = chars.join();
    final newCaret = caret - (text.length - newText.length);

    _controller.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: newCaret.clamp(0, newText.length)),
    );
  }

  // --- UI helpers ---
  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: Colors.red),
      );
  void _loading() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_showEmoji) {
          setState(() => _showEmoji = false);
          return false;
        }
        return true;
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRecording)
            VoiceRecordingOverlay(
                onCancel: _cancelRecording, onSend: _sendVoiceMessage),
          if (!_isRecording)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            border:
                                Border.all(color: Colors.grey[300]!, width: 1),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                    widget.showAttachmentMenu
                                        ? Icons.close
                                        : Icons.add,
                                    color: Theme.of(context).primaryColor),
                                onPressed: widget.onToggleAttachments,
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _focusNode,
                                  decoration: const InputDecoration(
                                    hintText: 'Message',
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 10),
                                  ),
                                  maxLines: null,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  onSubmitted: (_) => _sendText(),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                    _showEmoji
                                        ? Icons.keyboard
                                        : Icons.emoji_emotions_outlined,
                                    color: Theme.of(context).primaryColor),
                                onPressed: _toggleEmojiPicker,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        onPressed: _controller.text.trim().isEmpty
                            ? _startRecording
                            : _sendText,
                        backgroundColor: Theme.of(context).primaryColor,
                        mini: true,
                        elevation: 2,
                        child: Icon(
                            _controller.text.trim().isEmpty
                                ? Icons.mic
                                : Icons.send,
                            color: Colors.white,
                            size: 22),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _showEmoji
                      ? SizedBox(
                          height: 300,
                          child: EmojiPicker(
                            onEmojiSelected:
                                _onEmojiSelected, // (Category? , Emoji)
                            onBackspacePressed: _onBackspacePressed,
                            config: const Config(
                              emojiViewConfig: EmojiViewConfig(
                                emojiSizeMax: 32,
                                recentsLimit: 28,
                              ),
                              categoryViewConfig: CategoryViewConfig(),
                              skinToneConfig: SkinToneConfig(),
                              searchViewConfig: SearchViewConfig(),
                              bottomActionBarConfig: BottomActionBarConfig(
                                showBackspaceButton:
                                    true, // <-- here (not in CategoryViewConfig)
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
