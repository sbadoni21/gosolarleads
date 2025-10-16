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

// Normalize role to a simple lowercase token ("admin", "sales", etc.)
  String _normRole(String? r) {
    final v = (r ?? '').trim().toLowerCase();
    // map common variants if needed
    if (v == 'administrator') return 'admin';
    if (v == 'sale' || v == 'salesperson' || v == 'sales person')
      return 'sales';
    return v;
  }

// Returns selected users + current user (so creator counts toward role check)
  List<Map<String, String>> _selectedUsersIncludingMe() {
    final me = ref.read(currentUserProvider).value;
    final List<Map<String, String>> list = [];

    // add current user as map (try to find role from _allUsers if not on currentUser)
    if (me != null) {
      final meFromList = _allUsers.firstWhere(
        (u) => (u['uid'] ?? '').trim() == me.uid,
        orElse: () => const {'role': ''},
      );
      list.add({
        'uid': me.uid,
        'name': me.name,
        'email': me.email,
        'role':
            meFromList['role'] ?? (me.role ?? ''), // use me.role if you have it
      });
    }

    // add selected users
    for (final id in _selectedUserIds) {
      final u = _allUsers.firstWhere(
        (x) => (x['uid'] ?? '').trim() == id,
        orElse: () => const {},
      );
      if (u.isNotEmpty) list.add(u);
    }

    return list;
  }

// Validate that we have at least one admin and one sales
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
// NEW: role validation
    if (!_hasRequiredRoles()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.shield, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                    'Each group must include at least 1 Admin and 1 Sales member (creator counts).'),
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
    print(_allUsers);
    return _allUsers.where((u) {
      final n = (u['name'] ?? '').toLowerCase();
      final e = (u['email'] ?? '').toLowerCase();
      final r = (u['role'] ?? '').toLowerCase();

      return n.contains(q) || e.contains(q) || r.contains(q); // ← NEW
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> districts = _selectedState == null
        ? const <String>[]
        : (_stateDistricts[_selectedState] ?? const <String>[]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Group Icon
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                    backgroundImage:
                        _iconBytes != null ? MemoryImage(_iconBytes!) : null,
                    child: (_iconBytes == null &&
                            _iconFile == null &&
                            _uploadedIconUrl == null)
                        ? const Icon(Icons.group,
                            size: 50, color: AppTheme.primaryBlue)
                        : (_uploadedIconUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  _uploadedIconUrl!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image),
                                ),
                              )
                            : null),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _uploadingIcon ? null : _pickGroupIcon,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _uploadingIcon
                              ? Colors.grey
                              : AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _uploadingIcon
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.camera_alt,
                                size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Group Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Group Name *',
                hintText: 'Enter group name',
                prefixIcon: const Icon(Icons.group_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.withOpacity(0.05),
              ),
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Please enter group name'
                  : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Brief description about the group',
                prefixIcon: const Icon(Icons.description_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.withOpacity(0.05),
              ),
            ),
            const SizedBox(height: 24),

            // Work Location Header
            const Text(
              'Work Location',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGrey),
            ),
            const SizedBox(height: 12),

            // State Dropdown
            DropdownButtonFormField<String>(
              value: _selectedState,
              decoration: InputDecoration(
                labelText: 'State *',
                prefixIcon: const Icon(Icons.map_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              validator: (value) => (value == null || value.isEmpty)
                  ? 'Please select state'
                  : null,
            ),
            const SizedBox(height: 16),

            // Districts multi-select
            _districtsMultiSelect(districts),

            const SizedBox(height: 24),

            // Members Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add Members',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkGrey),
                ),
                // Role counters (creator included)
                const SizedBox(height: 8),

                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedUserIds.length} selected',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Builder(
              builder: (_) {
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

                  if (r == 'operations') operations++;
                }
                return Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.admin_panel_settings, size: 12),
                      label: Text(
                        'Admin: $admins',
                        style: TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      avatar: const Icon(Icons.storefront, size: 12),
                      label: Text(
                        'Sales: $sales',
                        style: TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      avatar: const Icon(Icons.storefront, size: 12),
                      label: Text(
                        'Survey: $survey',
                        style: TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      avatar: const Icon(Icons.storefront, size: 12),
                      label: Text(
                        'Installation: $installation',
                        style: TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      avatar: const Icon(Icons.storefront, size: 12),
                      label: Text(
                        'Operations: $operations',
                        style: TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    Chip(
                      avatar: const Icon(Icons.storefront, size: 12),
                      label: Text(
                        'Accounts: $accounts',
                        style: TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),

            // Search box
            TextField(
              controller: _memberSearchController,
              decoration: InputDecoration(
                hintText: 'Search members by name or email',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.withOpacity(0.05),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Bulk select buttons
            Row(
              children: [
                OutlinedButton.icon(
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
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Select all'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    final ids = _filteredUsers
                        .map((u) => (u['uid'] ?? '').trim())
                        .where((id) => id.isNotEmpty)
                        .toSet();
                    setState(() {
                      _selectedUserIds.removeWhere((id) => ids.contains(id));
                    });
                  },
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Members List - FIXED VERSION
            Container(
              constraints: const BoxConstraints(maxHeight: 350),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.mediumGrey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isLoadingUsers
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading users...',
                                style: TextStyle(color: AppTheme.mediumGrey)),
                          ],
                        ),
                      ),
                    )
                  : _allUsers.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline,
                                    size: 48, color: AppTheme.mediumGrey),
                                SizedBox(height: 12),
                                Text('No users found',
                                    style:
                                        TextStyle(color: AppTheme.mediumGrey)),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _filteredUsers.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            indent: 72,
                            color: AppTheme.mediumGrey.withOpacity(0.2),
                          ),
                          itemBuilder: (context, index) {
                            final raw = _filteredUsers[index];

                            print(raw);
                            final uid = (raw['uid'] ?? '').trim();
                            final name = (raw['name'] ?? '').trim();
                            final email = (raw['email'] ?? '').trim();
                            final role = (raw['role'] ?? '').trim(); // ← NEW

                            if (uid.isEmpty) return const SizedBox.shrink();

                            final me = ref.read(currentUserProvider).value;
                            if (me?.uid == uid) return const SizedBox.shrink();

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
                                  ? AppTheme.primaryBlue.withOpacity(0.05)
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
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      // Avatar
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: AppTheme.primaryTeal
                                            .withOpacity(0.1),
                                        child: Text(
                                          initial,
                                          style: const TextStyle(
                                            color: AppTheme.primaryTeal,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
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
                                                fontWeight: FontWeight.w500,
                                                fontSize: 15,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (role.isNotEmpty)
                                              _rolePill(role), // ← NEW

                                            if (subtitle != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                subtitle,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.mediumGrey
                                                      .withOpacity(0.8),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Checkbox
                                      Checkbox(
                                        value: isSelected,
                                        onChanged: (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedUserIds.add(uid);
                                            } else {
                                              _selectedUserIds.remove(uid);
                                            }
                                          });
                                        },
                                        activeColor: AppTheme.primaryBlue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 20),

            // Info Note
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: AppTheme.primaryBlue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You will be automatically added as group creator. Select other members to add.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.darkGrey.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Create Button
            Container(
              height: 56,
              decoration: AppTheme.gradientButtonDecoration,
              child: ElevatedButton(
                onPressed: (_isLoading || _uploadingIcon) ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.group_add, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Create Group',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _districtsMultiSelect(List<String> districts) {
    if (_selectedState == null) return const SizedBox.shrink();

    final allSelected =
        _selectedDistricts.length == districts.length && districts.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Districts *',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.darkGrey,
          ),
        ),
        const SizedBox(height: 8),

        // Control buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _selectedDistricts = districts.toSet());
              },
              icon: const Icon(Icons.done_all, size: 16),
              label: const Text('Select all', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _selectedDistricts.clear());
              },
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear all', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            if (districts.isNotEmpty)
              Chip(
                label: Text(
                  '${_selectedDistricts.length}/${districts.length}',
                  style: const TextStyle(fontSize: 12),
                ),
                avatar: Icon(
                  allSelected ? Icons.check_circle : Icons.check_circle_outline,
                  color: allSelected ? Colors.green : AppTheme.mediumGrey,
                  size: 18,
                ),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Districts chips
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.mediumGrey.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.withOpacity(0.02),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
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
                  selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
                  checkmarkColor: AppTheme.primaryBlue,
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: selected ? AppTheme.primaryBlue : AppTheme.darkGrey,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rolePill(String role) {
    if (role.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.30),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.25)),
      ),
      child: Text(
        role,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
