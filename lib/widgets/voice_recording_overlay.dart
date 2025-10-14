import 'package:flutter/material.dart';
import 'dart:async';

class VoiceRecordingOverlay extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const VoiceRecordingOverlay({
    super.key,
    required this.onCancel,
    required this.onSend,
  });

  @override
  State<VoiceRecordingOverlay> createState() => _VoiceRecordingOverlayState();
}

class _VoiceRecordingOverlayState extends State<VoiceRecordingOverlay>
    with SingleTickerProviderStateMixin {
  int _recordingDuration = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration++;
      });
    });

    // Pulse animation for mic icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cancel button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onCancel,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.red,
                  size: 24,
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 16),

          // Recording indicator
          Expanded(
            child: Row(
              children: [
                // Animated mic icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),

                // Animated waveform
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildWaveBar(20, 400),
                        _buildWaveBar(35, 500),
                        _buildWaveBar(15, 600),
                        _buildWaveBar(30, 450),
                        _buildWaveBar(25, 550),
                        _buildWaveBar(20, 650),
                        _buildWaveBar(35, 500),
                        _buildWaveBar(15, 700),
                        _buildWaveBar(30, 450),
                        _buildWaveBar(25, 600),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Duration
                Text(
                  _formatDuration(_recordingDuration),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF075E54),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Send button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onSend,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF075E54),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveBar(double height, int duration) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: duration),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 3,
          height: height * value,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF075E54).withOpacity(0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
      onEnd: () {
        // Restart animation
        if (mounted) {
          setState(() {});
        }
      },
    );
  }
}