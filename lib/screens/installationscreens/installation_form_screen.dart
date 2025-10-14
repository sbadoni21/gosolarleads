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
  bool _loading = false;

  // read-only fields
  late final TextEditingController _clientName;
  late final TextEditingController _contact;
  late final TextEditingController _location;
  late final TextEditingController _installerName;

  // local images
  final Map<String, File?> _images = {
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

  // existing urls
  late Map<String, String?> _urls;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider).value;
    _clientName   = TextEditingController(text: widget.leadName);
    _contact      = TextEditingController(text: widget.leadContact);
    _location     = TextEditingController(text: widget.leadLocation);
    _installerName= TextEditingController(text: user?.name ?? user?.email ?? 'Installer');

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
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    setState(() {
      _images[key] = File(x.path);
      _urls[key] = null; // override url if newly picked
    });
  }

  Future<void> _save(String status) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final installation = Installation(
        clientName: _clientName.text,
        contact: _contact.text,
        location: _location.text,
        installerName: _installerName.text,
        status: status,
        assignTo: widget.existing?.assignTo,
        // keep existing urls in the map (service will override with uploads)
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

      await ref.read(installationServiceProvider).saveInstallation(
        leadId: widget.leadId,
        installation: installation,
        files: _images, // keys must match model field names
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
        SnackBar(content: Text(status == 'submitted'
            ? 'Installation submitted'
            : 'Saved as draft')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiles = _urls.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Installation Form')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _ro('Client Name', _clientName),
                  const SizedBox(height: 12),
                  _ro('Contact', _contact),
                  const SizedBox(height: 12),
                  _ro('Location', _location),
                  const SizedBox(height: 12),
                  _ro('Installer Name', _installerName),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Images', style: TextStyle(fontWeight: FontWeight.bold)),

                  ...tiles.map((k) => _imageRow(k)).toList(),

                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : () => _save('draft'),
                          child: const Text('Save Draft'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _loading ? null : () => _save('submitted'),
                          child: const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _ro(String label, TextEditingController c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: c,
          readOnly: true,
          decoration: const InputDecoration(
            filled: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _imageRow(String key) {
    final hasLocal = _images[key] != null;
    final url = _urls[key];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(child: Text(key)),
          if (hasLocal || (url != null && url.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                height: 48, width: 48,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: hasLocal
                      ? Image.file(_images[key]!, fit: BoxFit.cover)
                      : Image.network(url!, fit: BoxFit.cover),
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => _pick(key),
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Upload'),
          ),
        ],
      ),
    );
  }
}
