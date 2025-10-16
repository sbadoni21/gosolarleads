import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gosolarleads/models/installation_models.dart';
import 'package:gosolarleads/providers/installation_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';

class InstallationFormScreen extends ConsumerStatefulWidget {
  final String leadId;
  final String leadName;
  final String leadContact;
  final String leadLocation;
  final Installation? existing;

  const InstallationFormScreen({
    super.key,
    required this.leadId,
    required this.leadName,
    required this.leadContact,
    required this.leadLocation,
    this.existing,
  });

  @override
  ConsumerState<InstallationFormScreen> createState() => _InstallationFormScreenState();
}

class _InstallationFormScreenState extends ConsumerState<InstallationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  bool _busy = false;

  // read-only fields
  late final TextEditingController _clientName;
  late final TextEditingController _contact;
  late final TextEditingController _location;
  late final TextEditingController _installerName;

  // display label per image key
  final Map<String, String> _labels = const {
    'structureImage': 'Structure',
    'wiringACImage': 'Wiring (AC)',
    'wiringDCImage': 'Wiring (DC)',
    'inverterImage': 'Inverter',
    'batteryImage': 'Battery',
    'acdbImage': 'ACDB',
    'dcdbImage': 'DCDB',
    'earthingImage': 'Earthing',
    'panelsImage': 'Panels',
    'civilImage': 'Civil Work',
    'civilLegImage': 'Civil – Leg',
    'civilEarthingImage': 'Civil – Earthing',
    'inverterOnImage': 'Inverter ON',
    'appInstallImage': 'App Installed',
    'plantInspectionImage': 'Plant Inspection',
    'dampProofSprinklerImage': 'Damp Proof/Sprinkler',
  };

  // local images picked (take precedence over urls)
  final Map<String, File?> _localFiles = {
    'structureImage': null,
    'wiringACImage': null,
    'wiringDCImage': null,
    'inverterImage': null,
    'batteryImage': null,
    'acdbImage': null,
    'dcdbImage': null,
    'earthingImage': null,
    'panelsImage': null,
    'civilImage': null,
    'civilLegImage': null,
    'civilEarthingImage': null,
    'inverterOnImage': null,
    'appInstallImage': null,
    'plantInspectionImage': null,
    'dampProofSprinklerImage': null,
  };

  // existing urls from backend (shown if no local file picked for that key)
  late Map<String, String?> _urls;

  // tile-level progress (0..1)
  final Map<String, double> _progress = {};

  // status
  String _status = 'draft';

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    _clientName    = TextEditingController(text: widget.leadName);
    _contact       = TextEditingController(text: widget.leadContact);
    _location      = TextEditingController(text: widget.leadLocation);
    _installerName = TextEditingController(text: user?.name ?? user?.email ?? 'Installer');

    _urls = {
      'structureImage': widget.existing?.structureImage,
      'wiringACImage': widget.existing?.wiringACImage,
      'wiringDCImage': widget.existing?.wiringDCImage,
      'inverterImage': widget.existing?.inverterImage,
      'batteryImage': widget.existing?.batteryImage,
      'acdbImage': widget.existing?.acdbImage,
      'dcdbImage': widget.existing?.dcdbImage,
      'earthingImage': widget.existing?.earthingImage,
      'panelsImage': widget.existing?.panelsImage,
      'civilImage': widget.existing?.civilImage,
      'civilLegImage': widget.existing?.civilLegImage,
      'civilEarthingImage': widget.existing?.civilEarthingImage,
      'inverterOnImage': widget.existing?.inverterOnImage,
      'appInstallImage': widget.existing?.appInstallImage,
      'plantInspectionImage': widget.existing?.plantInspectionImage,
      'dampProofSprinklerImage': widget.existing?.dampProofSprinklerImage,
    };

    _status = widget.existing?.status ?? 'draft';
  }

  @override
  void dispose() {
    _clientName.dispose();
    _contact.dispose();
    _location.dispose();
    _installerName.dispose();
    super.dispose();
  }

  Future<void> _pick(String key) async {
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (_) => _PickSourceSheet(),
    );
    if (source == null) return;

    final x = await _picker.pickImage(source: source, imageQuality: 80);
    if (x == null) return;

    setState(() {
      _localFiles[key] = File(x.path);
      _urls[key] = null;               // override existing url
      _progress[key] = 0.0;            // show progress baseline
    });
  }

  void _remove(String key) {
    setState(() {
      _localFiles[key] = null;
      // don’t erase server url automatically; leave as-is unless user explicitly clears
      // if you want a hard remove, uncomment:
      // _urls[key] = null;
      _progress.remove(key);
    });
  }

  int get _attachedCount {
    int count = 0;
    for (final k in _localFiles.keys) {
      if (_localFiles[k] != null || (_urls[k]?.isNotEmpty ?? false)) count++;
    }
    return count;
  }

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;

    // Submit guard: ask to confirm if fewer than 6 images attached (tweak threshold)
    if (status == 'submitted' && _attachedCount < 6) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Submit with missing photos?'),
          content: const Text(
            'Some recommended photos are missing. You can still submit now or save as draft and complete later.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit Anyway')),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _busy = true);
    try {
      final installation = Installation(
        clientName: _clientName.text,
        contact: _contact.text,
        location: _location.text,
        installerName: _installerName.text,
        status: status,
        assignTo: widget.existing?.assignTo,
        structureImage: _urls['structureImage'],
        wiringACImage: _urls['wiringACImage'],
        wiringDCImage: _urls['wiringDCImage'],
        inverterImage: _urls['inverterImage'],
        batteryImage: _urls['batteryImage'],
        acdbImage: _urls['acdbImage'],
        dcdbImage: _urls['dcdbImage'],
        earthingImage: _urls['earthingImage'],
        panelsImage: _urls['panelsImage'],
        civilImage: _urls['civilImage'],
        civilLegImage: _urls['civilLegImage'],
        civilEarthingImage: _urls['civilEarthingImage'],
        inverterOnImage: _urls['inverterOnImage'],
        appInstallImage: _urls['appInstallImage'],
        plantInspectionImage: _urls['plantInspectionImage'],
        dampProofSprinklerImage: _urls['dampProofSprinklerImage'],
      );

      // the service can update URLs after upload; if you want live per-tile progress, you can expose a callback
      await ref.read(installationServiceProvider).saveInstallation(
        leadId: widget.leadId,
        installation: installation,
        files: _localFiles,
        onProgress: (key, percent) {
          setState(() => _progress[key] = percent);
        },
        onFileUploaded: (key, downloadUrl) {
          // reflect new URL immediately in UI
          setState(() {
            _urls[key] = downloadUrl;
            _localFiles[key] = null; // clear temp file after upload if you like
            _progress[key] = 1.0;
          });
        },
      );

      // notify on submitted
      if (status == 'submitted') {
        try {
          final user = ref.read(currentUserProvider).value;
          await FirebaseFunctions.instance
              .httpsCallable('sendInstallationSubmittedNotification')
              .call({
            'leadId': widget.leadId,
            'installerUid': user?.uid ?? '',
            'installerName': _installerName.text,
          });
        } catch (e) {
          debugPrint('sendInstallationSubmittedNotification error: $e');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'submitted' ? 'Installation submitted' : 'Saved as draft'),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _localFiles.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Installation Report'),
        centerTitle: false,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Row(
            children: [
              // progress chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Text('Photos: $_attachedCount / $total',
                    style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: _busy ? null : () => _save('draft'),
                child: const Text('Save Draft'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _busy ? null : () => _save('submitted'),
                child: _busy
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _LeadSummaryCard(
                        clientName: _clientName.text,
                        contact: _contact.text,
                        location: _location.text,
                        installerName: _installerName.text,
                        status: _status,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: 'Photo Checklist',
                      subtitle: 'Upload clear photos for faster approvals.',
                      icon: Icons.photo_library_outlined,
                    ),
                  ),
                  // grid of tiles
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.15,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final key = _localFiles.keys.elementAt(index);
                          return _ImageTile(
                            label: _labels[key] ?? key,
                            file: _localFiles[key],
                            url: _urls[key],
                            progress: _progress[key] ?? -1, // -1 = hidden
                            onPick: () => _pick(key),
                            onRemove: () => _remove(key),
                            onPreview: () {
                              final imageProvider = _localFiles[key] != null
                                  ? Image.file(_localFiles[key]!).image
                                  : (_urls[key]?.isNotEmpty ?? false)
                                      ? Image.network(_urls[key]!).image
                                      : null;
                              if (imageProvider != null) {
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    child: InteractiveViewer(
                                      child: Image(image: imageProvider, fit: BoxFit.contain),
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                        childCount: _localFiles.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }
}

/// ————————————————— UI Pieces —————————————————

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue.withOpacity(0.12),
            child: Icon(icon, color: Colors.blue.shade700, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadSummaryCard extends StatelessWidget {
  final String clientName;
  final String contact;
  final String location;
  final String installerName;
  final String status;

  const _LeadSummaryCard({
    required this.clientName,
    required this.contact,
    required this.location,
    required this.installerName,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = status == 'submitted' ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.home_repair_service, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  clientName.isEmpty ? 'Unnamed Lead' : clientName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.25)),
                ),
                child: Text(
                  status == 'submitted' ? 'Submitted' : 'Draft',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.call, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  contact.isEmpty ? 'No contact' : contact,
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.place, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location.isEmpty ? 'No location' : location,
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person_pin, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  installerName,
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String label;
  final File? file;
  final String? url;
  final double progress; // -1 hides progress
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final VoidCallback onPreview;

  const _ImageTile({
    required this.label,
    required this.file,
    required this.url,
    required this.progress,
    required this.onPick,
    required this.onRemove,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent = file != null || (url != null && url!.isNotEmpty);

    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: hasContent ? onPreview : onPick,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: hasContent ? Colors.green.shade200 : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              // Thumbnail
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: hasContent
                            ? (file != null
                                ? Image.file(file!, fit: BoxFit.cover, width: double.infinity)
                                : Image.network(url!, fit: BoxFit.cover, width: double.infinity))
                            : Center(
                                child: Icon(Icons.add_a_photo_outlined,
                                    color: Colors.grey.shade500, size: 32),
                              ),
                      ),
                    ),
                    // small top-right remove button if has content
                    if (hasContent)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: InkWell(
                          onTap: onRemove,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    // progress ring
                    if (progress >= 0 && progress < 1)
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            height: 36,
                            width: 36,
                            child: CircularProgressIndicator(
                              value: progress <= 0 ? null : progress,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Label & action
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onPick,
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: Text(hasContent ? 'Replace' : 'Upload'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 4, width: 36, margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(16)),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pick from gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Use camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
