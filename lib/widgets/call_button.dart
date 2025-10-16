import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/models/call_record.dart';
import 'package:gosolarleads/services/local_call_recording_service.dart';
import 'package:intl/intl.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CallRecordingButton extends ConsumerStatefulWidget {
  final String leadId;
  final String leadName;
  final String phoneNumber;

  const CallRecordingButton({
    super.key,
    required this.leadId,
    required this.leadName,
    required this.phoneNumber,
  });

  @override
  ConsumerState<CallRecordingButton> createState() =>
      _CallRecordingButtonState();
}

class _CallRecordingButtonState extends ConsumerState<CallRecordingButton> {
  final _recordingService = LocalCallRecordingService();
  bool _isInitialized = false;
  bool _disposed = false;

  void safeSetState(VoidCallback fn) {
    if (mounted && !_disposed) setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _disposed = true;
    // Cancel any callbacks/streams in your service if available
    // _recordingService.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    final success = await _recordingService.initialize();
    if (!mounted) return;
    safeSetState(() => _isInitialized = success);
  }

  Future<void> _startCall() async {
    if (!_isInitialized) {
      _showSnackbar('Please grant permissions first', isError: true);
      return;
    }

    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      _showSnackbar('User not logged in', isError: true);
      return;
    }

    if (!mounted) return;
    final consent = await _showConsentDialog();
    if (!mounted || consent != true) return;

    try {
      final callId = await _recordingService.startRecording(
        leadId: widget.leadId,
        leadName: widget.leadName,
        phoneNumber: widget.phoneNumber,
        salesOfficerUid: user.uid,
        salesOfficerName: user.name ?? 'Unknown',
      );

      if (!mounted) return;

      if (callId != null) {
        final uri = Uri.parse('tel:${widget.phoneNumber}');
        final canCall = await canLaunchUrl(uri);
        if (!mounted) return;

        if (canCall) {
          await launchUrl(uri);
          if (!mounted) return;
          _showRecordingDialog();
        } else {
          await _recordingService.cancelRecording();
          _showSnackbar('Cannot make phone call', isError: true);
        }
      } else {
        _showSnackbar('Failed to start recording', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackbar('Error: $e', isError: true);
    }
  }

  Future<bool?> _showConsentDialog() {
    if (!mounted) return Future.value(false);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.record_voice_over, color: AppTheme.errorRed),
            SizedBox(width: 12),
            Text('Record Call?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This call will be recorded for:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildConsentPoint('Quality assurance'),
            _buildConsentPoint('Training purposes'),
            _buildConsentPoint('Performance review'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppTheme.warningAmber.withOpacity(0.3)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline,
                      size: 16, color: AppTheme.warningAmber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recording starts when call connects and stops when call ends.',
                      style: TextStyle(fontSize: 11, color: AppTheme.darkGrey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.phone, size: 18),
            label: const Text('Start Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              size: 16, color: AppTheme.successGreen),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  void _showRecordingDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppTheme.errorRed,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fiber_manual_record,
                color: Colors.white, size: 48),
            const SizedBox(height: 16),
            const Text(
              'RECORDING IN PROGRESS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Call will be uploaded when ended',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      await _recordingService.cancelRecording();
                      if (!mounted) return;
                      _showSnackbar('Recording cancelled');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      await _endCall();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.errorRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('End Call'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _endCall() async {
    if (!mounted) return;

    // Uploading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Uploading recording...'),
              ],
            ),
          ),
        ),
      ),
    );

    final success = await _recordingService.stopRecordingAndUpload();

    if (!mounted) return;

    // Close uploading dialog
    Navigator.of(context, rootNavigator: true).pop();

    _showSnackbar(
      success
          ? '✅ Call recording uploaded successfully'
          : '❌ Failed to upload recording',
      isSuccess: success,
      isError: !success,
    );
  }

  void _showSnackbar(String message,
      {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppTheme.errorRed
            : isSuccess
                ? AppTheme.successGreen
                : AppTheme.primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _recordingService.isRecording ? null : _startCall,
      icon: Icon(
        _recordingService.isRecording ? Icons.stop_circle : Icons.phone,
        size: 12,
        color: Colors.white,
      ),
      label: Text(
          _recordingService.isRecording ? 'Recording...' : 'Call & Record'),
      style: ElevatedButton.styleFrom(
        textStyle: const TextStyle(fontSize: 12),
        backgroundColor: _recordingService.isRecording
            ? AppTheme.errorRed
            : AppTheme.successGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
  }
}

// ============================================
// UI Widget: Call History List
// ============================================

class CallHistoryList extends StatelessWidget {
  final String leadId;

  const CallHistoryList({super.key, required this.leadId});

  @override
  Widget build(BuildContext context) {
    final recordingService = LocalCallRecordingService();

    return StreamBuilder<List<CallRecord>>(
      stream: recordingService.getLeadCallRecords(leadId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final calls = snapshot.data ?? [];

        if (calls.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.phone_disabled,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No call history yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: calls.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final call = calls[index];
            return _buildCallItem(context, call);
          },
        );
      },
    );
  }

  Widget _buildCallItem(BuildContext context, CallRecord call) {
    final statusColor = call.status == 'completed'
        ? AppTheme.successGreen
        : call.status == 'recording'
            ? AppTheme.warningAmber
            : AppTheme.errorRed;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: call.recordingUrl != null
            ? () => _showRecordingPlayer(context, call)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.phone, color: statusColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      call.startedAt != null
                          ? DateFormat('dd MMM yyyy, hh:mm a')
                              .format(call.startedAt!)
                          : 'Unknown time',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.timer,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          call.durationFormatted,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.storage,
                            size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          call.fileSizeFormatted,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        call.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (call.recordingUrl != null)
                IconButton(
                  icon: const Icon(Icons.play_circle_fill),
                  color: AppTheme.primaryBlue,
                  iconSize: 32,
                  onPressed: () => _showRecordingPlayer(context, call),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecordingPlayer(BuildContext context, CallRecord call) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.headphones, color: AppTheme.primaryBlue),
            SizedBox(width: 12),
            Text('Play Recording'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.lightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.mic,
                      size: 64, color: AppTheme.primaryBlue.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    call.durationFormatted,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    call.startedAt != null
                        ? DateFormat('dd MMM yyyy').format(call.startedAt!)
                        : '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.mediumGrey,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (call.recordingUrl == null) return;
                launchUrl(Uri.parse(call.recordingUrl!));
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Audio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
