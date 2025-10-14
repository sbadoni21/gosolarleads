import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoMessageBubble extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final String? caption;
  final bool isSentByMe;

  const VideoMessageBubble({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.caption,
    required this.isSentByMe,
  });

  @override
  State<VideoMessageBubble> createState() => _VideoMessageBubbleState();
}

class _VideoMessageBubbleState extends State<VideoMessageBubble> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isInitializing = false;

  Future<void> _initializeVideo() async {
    if (_videoController != null) return;

    setState(() => _isInitializing = true);

    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    await _videoController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: false,
      looping: false,
      showControls: true,
      aspectRatio: _videoController!.value.aspectRatio,
      placeholder: widget.thumbnailUrl != null
          ? Image.network(widget.thumbnailUrl!, fit: BoxFit.cover)
          : Container(color: Colors.grey[300]),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(
                'Error playing video',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        );
      },
    );

    setState(() => _isInitializing = false);
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_videoController == null) {
          _initializeVideo();
        }
      },
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 280,
          maxHeight: 400,
        ),
        decoration: BoxDecoration(
          color: widget.isSentByMe ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video Player or Thumbnail
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _chewieController != null
                    ? Chewie(controller: _chewieController!)
                    : Stack(
                        children: [
                          // Thumbnail or placeholder
                          if (widget.thumbnailUrl != null)
                            Image.network(
                              widget.thumbnailUrl!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                          else
                            Container(
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(
                                  Icons.videocam,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              ),
                            ),

                          // Play button overlay
                          Positioned.fill(
                            child: Container(
                              color: Colors.black26,
                              child: Center(
                                child: _isInitializing
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              // Caption (if provided)
              if (widget.caption != null && widget.caption!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    widget.caption!,
                    style: TextStyle(
                      fontSize: 14,
                      color: widget.isSentByMe
                          ? const Color(0xFF075E54)
                          : Colors.black87,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}