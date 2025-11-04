// lib/screens/chatscreens/create_group_screen.dart
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/providers/chat_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/models/chat_models.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _memberSearchController = TextEditingController();

  Set<String> _selectedDistricts = {};
  String? _selectedState;
  String? _selectedDistrict;

  bool _isLoading = false;
  bool _isLoadingUsers = true;
  List<Map<String, String>> _allUsers = [];
  List<String> _selectedUserIds = [];

  Uint8List? _iconBytes;
  File? _iconFile;
  String? _uploadedIconUrl;
  bool _uploadingIcon = false;

  int _currentStep = 0;

  final List<String> _availableStates = ['Uttarakhand', 'Uttar Pradesh'];

  final Map<String, List<String>> _stateDistricts = {
    'Uttarakhand': [
      'Almora',
      'Bageshwar',
      'Chamoli',
      'Champawat',
      'Dehradun',
      'Haridwar',
      'Nainital',
      'Pauri Garhwal',
      'Pithoragarh',
      'Rudraprayag',
      'Tehri Garhwal',
      'Udham Singh Nagar',
      'Uttarkashi'
    ],
    'Uttar Pradesh': [
      'Agra',
      'Aligarh',
      'Ambedkar Nagar',
      'Amethi',
      'Amroha',
      'Auraiya',
      'Ayodhya',
      'Azamgarh',
      'Baghpat',
      'Bahraich',
      'Ballia',
      'Balrampur',
      'Banda',
      'Barabanki',
      'Bareilly',
      'Basti',
      'Bhadohi',
      'Bijnor',
      'Budaun',
      'Bulandshahr',
      'Chandauli',
      'Chitrakoot',
      'Deoria',
      'Etah',
      'Etawah',
      'Farrukhabad',
      'Fatehpur',
      'Firozabad',
      'Gautam Buddha Nagar',
      'Ghaziabad',
      'Ghazipur',
      'Gonda',
      'Gorakhpur',
      'Hamirpur',
      'Hapur',
      'Hardoi',
      'Hathras',
      'Jalaun',
      'Jaunpur',
      'Jhansi',
      'Kannauj',
      'Kanpur Dehat',
      'Kanpur Nagar',
      'Kasganj',
      'Kaushambi',
      'Kheri',
      'Kushinagar',
      'Lalitpur',
      'Lucknow',
      'Maharajganj',
      'Mahoba',
      'Mainpuri',
      'Mathura',
      'Mau',
      'Meerut',
      'Mirzapur',
      'Moradabad',
      'Muzaffarnagar',
      'Pilibhit',
      'Pratapgarh',
      'Prayagraj',
      'Raebareli',
      'Rampur',
      'Saharanpur',
      'Sambhal',
      'Sant Kabir Nagar',
      'Shahjahanpur',
      'Shamli',
      'Shrawasti',
      'Siddharthnagar',
      'Sitapur',
      'Sonbhadra',
      'Sultanpur',
      'Unnao',
      'Varanasi'
    ]
  };

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  String _normRole(String? r) {
    final v = (r ?? '').trim().toLowerCase();
    if (v == 'administrator') return 'admin';
    if (v == 'sale' || v == 'salesperson' || v == 'sales person')
      return 'sales';
    return v;
  }

  List<Map<String, String>> _selectedUsersIncludingMe() {
    final me = ref.read(currentUserProvider).value;
    final List<Map<String, String>> list = [];

    if (me != null) {
      final meFromList = _allUsers.firstWhere(
        (u) => (u['uid'] ?? '').trim() == me.uid,
        orElse: () => const {'role': ''},
      );
      list.add({
        'uid': me.uid,
        'name': me.name,
        'email': me.email,
        'role': meFromList['role'] ?? (me.role ?? ''),
      });
    }

    for (final id in _selectedUserIds) {
      final u = _allUsers.firstWhere(
        (x) => (x['uid'] ?? '').trim() == id,
        orElse: () => const {},
      );
      if (u.isNotEmpty) list.add(u);
    }

    return list;
  }

  bool _hasRequiredRoles() {
    final sel = _selectedUsersIncludingMe();
    bool hasAdmin = false, hasSales = false;

    for (final u in sel) {
      final r = _normRole(u['role']);
      if (r == 'admin') hasAdmin = true;
      if (r == 'sales') hasSales = true;
      if (hasAdmin && hasSales) return true;
    }
    return false;
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final chatService = ref.read(chatServiceProvider);
      final users = await chatService.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load users: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickGroupIcon() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      withData: kIsWeb,
    );
    if (result == null) return;

    final file = result.files.single;
    setState(() {
      _uploadedIconUrl = null;
      if (kIsWeb) {
        _iconBytes = file.bytes;
        _iconFile = null;
      } else {
        _iconBytes = null;
        _iconFile = file.path != null ? File(file.path!) : null;
      }
    });
  }

  Future<String?> _uploadIconIfNeeded(String createdByUid) async {
    if (_uploadedIconUrl != null) return _uploadedIconUrl;
    if (_iconBytes == null && _iconFile == null) return null;

    setState(() => _uploadingIcon = true);
    try {
      final storage = FirebaseStorage.instance;
      final filename =
          'chat/group_icons/${DateTime.now().millisecondsSinceEpoch}_$createdByUid.jpg';
      final ref = storage.ref().child(filename);

      UploadTask task;
      if (kIsWeb && _iconBytes != null) {
        task = ref.putData(
            _iconBytes!, SettableMetadata(contentType: 'image/jpeg'));
      } else if (_iconFile != null) {
        task = ref.putFile(
            _iconFile!, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        return null;
      }

      await task;
      final url = await ref.getDownloadURL();
      setState(() => _uploadedIconUrl = url);
      return url;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Icon upload failed: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return null;
    } finally {
      if (mounted) setState(() => _uploadingIcon = false);
    }
  }

  bool _canProceedToStep(int step) {
    switch (step) {
      case 1:
        return _nameController.text.trim().isNotEmpty;
      case 2:
        return _selectedState != null && _selectedDistricts.isNotEmpty;
      case 3:
        return true;
      default:
        return true;
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedState == null || _selectedState!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a state')),
      );
      return;
    }

    if (_selectedDistricts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one district')),
      );
      return;
    }

    if (!_hasRequiredRoles()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.shield, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                    'Group must include at least 1 Admin and 1 Sales member'),
              ),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Please select at least one member')),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) throw 'User not found';

      final iconUrl = await _uploadIconIfNeeded(currentUser.uid);
      final chatService = ref.read(chatServiceProvider);

      final members = <ChatMember>[];
      members.add(ChatMember(
        uid: currentUser.uid,
        name: currentUser.name,
        email: currentUser.email,
        joinedAt: DateTime.now(),
      ));

      for (var userId in _selectedUserIds) {
        final user = _allUsers.firstWhere((u) => u['uid'] == userId);
        members.add(ChatMember(
          uid: user['uid']!,
          name: user['name']!,
          email: user['email']!,
          joinedAt: DateTime.now(),
        ));
      }

      await chatService.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        state: _selectedState ?? '',
        districts: _selectedDistricts.toList(),
        createdBy: currentUser.email,
        members: members,
        groupIcon: iconUrl,
        memberIds: [..._selectedUserIds, currentUser.uid],
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Group created successfully!'),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, String>> get _filteredUsers {
    final q = _memberSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allUsers;
    return _allUsers.where((u) {
      final n = (u['name'] ?? '').toLowerCase();
      final e = (u['email'] ?? '').toLowerCase();
      final r = (u['role'] ?? '').toLowerCase();
      return n.contains(q) || e.contains(q) || r.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress Indicator
            _buildProgressIndicator(),

            // Content
            Expanded(
              child: IndexedStack(
                index: _currentStep,
                children: [
                  _buildStep1BasicInfo(),
                  _buildStep2Location(),
                  _buildStep3Members(),
                ],
              ),
            ),

            // Bottom Navigation
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStepIndicator(0, 'Basic', Icons.info_outline),
          _buildStepConnector(0),
          _buildStepIndicator(1, 'Location', Icons.location_on_outlined),
          _buildStepConnector(1),
          _buildStepIndicator(2, 'Members', Icons.group_outlined),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted
                  ? AppTheme.successGreen
                  : isActive
                      ? AppTheme.primaryBlue
                      : Colors.grey.withOpacity(0.2),
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              color:
                  isActive || isCompleted ? Colors.white : AppTheme.mediumGrey,
              size: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive ? AppTheme.primaryBlue : AppTheme.mediumGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector(int beforeStep) {
    final isCompleted = _currentStep > beforeStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 24),
        color:
            isCompleted ? AppTheme.successGreen : Colors.grey.withOpacity(0.3),
      ),
    );
  }

  Widget _buildStep1BasicInfo() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Basic Information',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkGrey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Set up your group with a name and optional icon',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.mediumGrey.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 32),

        // Group Icon
        Center(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                  backgroundImage:
                      _iconBytes != null ? MemoryImage(_iconBytes!) : null,
                  child: (_iconBytes == null &&
                          _iconFile == null &&
                          _uploadedIconUrl == null)
                      ? const Icon(Icons.group,
                          size: 60, color: AppTheme.primaryBlue)
                      : (_uploadedIconUrl != null
                          ? ClipOval(
                              child: Image.network(
                                _uploadedIconUrl!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image),
                              ),
                            )
                          : null),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _uploadingIcon ? null : _pickGroupIcon,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient:
                            _uploadingIcon ? null : AppTheme.primaryGradient,
                        color: _uploadingIcon ? Colors.grey : null,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _uploadingIcon
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt,
                              size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        // Group Name
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Group Name *',
            hintText: 'e.g., Dehradun Solar Team',
            prefixIcon:
                const Icon(Icons.group_outlined, color: AppTheme.primaryBlue),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppTheme.mediumGrey.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppTheme.mediumGrey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.primaryBlue, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.withOpacity(0.05),
          ),
          validator: (value) => (value == null || value.isEmpty)
              ? 'Please enter group name'
              : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),

        // Description
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Description (Optional)',
            hintText: 'What is this group about?',
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 60),
              child:
                  Icon(Icons.description_outlined, color: AppTheme.primaryBlue),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppTheme.mediumGrey.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppTheme.mediumGrey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.primaryBlue, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.withOpacity(0.05),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Location() {
    final List<String> districts = _selectedState == null
        ? const <String>[]
        : (_stateDistricts[_selectedState] ?? const <String>[]);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Work Location',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkGrey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select the state and districts for this group',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.mediumGrey.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 32),

        // State Dropdown
        DropdownButtonFormField<String>(
          value: _selectedState,
          decoration: InputDecoration(
            labelText: 'State *',
            prefixIcon:
                const Icon(Icons.map_outlined, color: AppTheme.primaryBlue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppTheme.mediumGrey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppTheme.primaryBlue, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.withOpacity(0.05),
          ),
          items: _availableStates
              .map((state) => DropdownMenuItem<String>(
                    value: state,
                    child: Text(state),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedState = value;
              _selectedDistrict = null;
              _selectedDistricts.clear();
            });
          },
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Please select state' : null,
        ),
        const SizedBox(height: 24),

        // Districts Section
        if (_selectedState != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Districts *',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.darkGrey,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _selectedDistricts.isEmpty
                      ? AppTheme.errorRed.withOpacity(0.1)
                      : AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedDistricts.isEmpty
                        ? AppTheme.errorRed.withOpacity(0.3)
                        : AppTheme.successGreen.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '${_selectedDistricts.length}/${districts.length} selected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _selectedDistricts.isEmpty
                        ? AppTheme.errorRed
                        : AppTheme.successGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _selectedDistricts = districts.toSet());
                  },
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Select All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryBlue,
                    side: const BorderSide(color: AppTheme.primaryBlue),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _selectedDistricts.clear());
                  },
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.mediumGrey,
                    side:
                        BorderSide(color: AppTheme.mediumGrey.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Districts Grid
          Container(
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.mediumGrey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: districts.map<Widget>((String d) {
                  final selected = _selectedDistricts.contains(d);
                  return FilterChip(
                    label: Text(d),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedDistricts.add(d);
                        } else {
                          _selectedDistricts.remove(d);
                        }
                      });
                    },
                    selectedColor: AppTheme.primaryBlue.withOpacity(0.15),
                    checkmarkColor: AppTheme.primaryBlue,
                    backgroundColor: Colors.grey.withOpacity(0.08),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      color:
                          selected ? AppTheme.primaryBlue : AppTheme.darkGrey,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: selected
                            ? AppTheme.primaryBlue
                            : Colors.transparent,
                        width: selected ? 1.5 : 0,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep3Members() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Members',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select team members for this group',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.mediumGrey.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 20),

              // Role Requirements Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryBlue.withOpacity(0.1),
                      AppTheme.primaryTeal.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasRequiredRoles()
                        ? AppTheme.successGreen.withOpacity(0.3)
                        : AppTheme.primaryBlue.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _hasRequiredRoles()
                              ? Icons.check_circle
                              : Icons.shield_outlined,
                          color: _hasRequiredRoles()
                              ? AppTheme.successGreen
                              : AppTheme.primaryBlue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _hasRequiredRoles()
                                ? 'Role Requirements Met ✓'
                                : 'Required: 1 Admin + 1 Sales',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _hasRequiredRoles()
                                  ? AppTheme.successGreen
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRoleSummaryChips(),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Search Bar
              TextField(
                controller: _memberSearchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, email, or role',
                  prefixIcon:
                      const Icon(Icons.search, color: AppTheme.primaryBlue),
                  suffixIcon: _memberSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _memberSearchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppTheme.mediumGrey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: AppTheme.mediumGrey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppTheme.primaryBlue, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.05),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              // Bulk Actions & Count
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final ids = _filteredUsers
                            .map((u) => (u['uid'] ?? '').trim())
                            .where((id) => id.isNotEmpty)
                            .toList();
                        final me = ref.read(currentUserProvider).value?.uid;
                        setState(() {
                          for (final id in ids) {
                            if (id == me) continue;
                            if (!_selectedUserIds.contains(id)) {
                              _selectedUserIds.add(id);
                            }
                          }
                        });
                      },
                      icon: const Icon(Icons.done_all, size: 20),
                      label: const Text('Select All',
                          style: TextStyle(
                              color: AppTheme.primaryBlue, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryBlue,
                        side: const BorderSide(color: AppTheme.primaryBlue),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final ids = _filteredUsers
                            .map((u) => (u['uid'] ?? '').trim())
                            .where((id) => id.isNotEmpty)
                            .toSet();
                        setState(() {
                          _selectedUserIds
                              .removeWhere((id) => ids.contains(id));
                        });
                      },
                      icon: const Icon(Icons.clear_all, size: 20),
                      label: const Text('Clear',
                          style: TextStyle(
                              color: AppTheme.mediumGrey, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.mediumGrey,
                        side: BorderSide(
                            color: AppTheme.mediumGrey.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedUserIds.isEmpty
                          ? AppTheme.mediumGrey.withOpacity(0.1)
                          : AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _selectedUserIds.isEmpty
                            ? AppTheme.mediumGrey.withOpacity(0.3)
                            : AppTheme.primaryBlue.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '${_selectedUserIds.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _selectedUserIds.isEmpty
                            ? AppTheme.mediumGrey
                            : AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Members List
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.mediumGrey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: _isLoadingUsers
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading users...',
                            style: TextStyle(color: AppTheme.mediumGrey)),
                      ],
                    ),
                  )
                : _allUsers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline,
                                size: 48, color: AppTheme.mediumGrey),
                            SizedBox(height: 12),
                            Text('No users found',
                                style: TextStyle(color: AppTheme.mediumGrey)),
                          ],
                        ),
                      )
                    : _filteredUsers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_off,
                                    size: 48, color: AppTheme.mediumGrey),
                                const SizedBox(height: 12),
                                const Text('No matching users',
                                    style:
                                        TextStyle(color: AppTheme.mediumGrey)),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    _memberSearchController.clear();
                                    setState(() {});
                                  },
                                  child: const Text('Clear search'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _filteredUsers.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              indent: 72,
                              color: AppTheme.mediumGrey.withOpacity(0.2),
                            ),
                            itemBuilder: (context, index) {
                              final raw = _filteredUsers[index];
                              final uid = (raw['uid'] ?? '').trim();
                              final name = (raw['name'] ?? '').trim();
                              final email = (raw['email'] ?? '').trim();
                              final role = (raw['role'] ?? '').trim();

                              if (uid.isEmpty) return const SizedBox.shrink();

                              final me = ref.read(currentUserProvider).value;
                              if (me?.uid == uid)
                                return const SizedBox.shrink();

                              final isSelected = _selectedUserIds.contains(uid);
                              final displayName = name.isNotEmpty
                                  ? name
                                  : (email.isNotEmpty ? email : 'Unknown');
                              final subtitle =
                                  email.isNotEmpty && email != displayName
                                      ? email
                                      : null;

                              String initial;
                              if (name.isNotEmpty) {
                                initial = name.characters.first.toUpperCase();
                              } else if (email.isNotEmpty) {
                                initial = email.characters.first.toUpperCase();
                              } else {
                                initial = '?';
                              }

                              return Material(
                                color: isSelected
                                    ? AppTheme.primaryBlue.withOpacity(0.08)
                                    : Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedUserIds.remove(uid);
                                      } else {
                                        _selectedUserIds.add(uid);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        // Avatar
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                AppTheme.primaryTeal
                                                    .withOpacity(0.8),
                                                AppTheme.primaryBlue
                                                    .withOpacity(0.8),
                                              ],
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              initial,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),

                                        // Name & Email
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (role.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                _rolePill(role),
                                              ],
                                              if (subtitle != null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  subtitle,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: AppTheme.mediumGrey
                                                        .withOpacity(0.8),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        // Checkbox
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isSelected
                                                ? AppTheme.primaryBlue
                                                : Colors.transparent,
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppTheme.primaryBlue
                                                  : AppTheme.mediumGrey,
                                              width: 2,
                                            ),
                                          ),
                                          child: isSelected
                                              ? const Icon(Icons.check,
                                                  size: 16, color: Colors.white)
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRoleSummaryChips() {
    int admins = 0,
        sales = 0,
        survey = 0,
        installation = 0,
        operations = 0,
        accounts = 0;
    for (final u in _selectedUsersIncludingMe()) {
      final r = _normRole(u['role']);
      if (r == 'admin') admins++;
      if (r == 'sales') sales++;
      if (r == 'survey') survey++;
      if (r == 'installation') installation++;
      if (r == 'accounts') accounts++;
      if (r == 'operation') operations++;
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildRoleChip(
            'Admin', admins, Icons.admin_panel_settings, admins >= 1),
        _buildRoleChip('Sales', sales, Icons.storefront, sales >= 1),
        if (survey > 0)
          _buildRoleChip('Survey', survey, Icons.assignment, false),
        if (installation > 0)
          _buildRoleChip('Install', installation, Icons.construction, false),
        if (operations > 0)
          _buildRoleChip('Operations', operations, Icons.settings, false),
        if (accounts > 0)
          _buildRoleChip('Accounts', accounts, Icons.account_balance, false),
      ],
    );
  }

  Widget _buildRoleChip(
      String label, int count, IconData icon, bool isRequired) {
    final hasMembers = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasMembers
            ? (isRequired
                ? AppTheme.successGreen.withOpacity(0.15)
                : AppTheme.primaryBlue.withOpacity(0.15))
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasMembers
              ? (isRequired ? AppTheme.successGreen : AppTheme.primaryBlue)
              : AppTheme.mediumGrey.withOpacity(0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: hasMembers
                ? (isRequired ? AppTheme.successGreen : AppTheme.primaryBlue)
                : AppTheme.mediumGrey,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: hasMembers
                  ? (isRequired ? AppTheme.successGreen : AppTheme.primaryBlue)
                  : AppTheme.mediumGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() => _currentStep--);
                        },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppTheme.primaryBlue),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back),
                      SizedBox(width: 8),
                      Text('Back',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Container(
                decoration: _currentStep == 2
                    ? AppTheme.gradientButtonDecoration
                    : null,
                child: ElevatedButton(
                  onPressed: (_isLoading ||
                          _uploadingIcon ||
                          !_canProceedToStep(_currentStep + 1))
                      ? null
                      : () {
                          if (_currentStep < 2) {
                            setState(() => _currentStep++);
                          } else {
                            _createGroup();
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentStep == 2
                        ? Colors.transparent
                        : AppTheme.primaryBlue,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor:
                        AppTheme.mediumGrey.withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentStep == 2 ? 'Create Group' : 'Continue',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentStep == 2
                                  ? Icons.check
                                  : Icons.arrow_forward,
                              color: Colors.white,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rolePill(String role) {
    if (role.isEmpty) return const SizedBox.shrink();

    Color getRoleColor(String r) {
      final normalized = _normRole(r);
      switch (normalized) {
        case 'admin':
          return Colors.red;
        case 'sales':
          return Colors.blue;
        case 'survey':
          return Colors.orange;
        case 'installation':
          return Colors.green;
        case 'operation':
          return Colors.purple;
        case 'accounts':
          return Colors.teal;
        default:
          return Colors.grey;
      }
    }

    final color = getRoleColor(role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
