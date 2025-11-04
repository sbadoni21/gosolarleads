import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gosolarleads/theme/app_theme.dart';
import 'package:gosolarleads/providers/leadpool_provider.dart';
import 'package:gosolarleads/providers/chat_provider.dart';
import 'package:gosolarleads/providers/auth_provider.dart';
import 'package:gosolarleads/models/leadpool.dart';
import 'package:gosolarleads/models/chat_models.dart';

class CreateLeadInGroupScreen extends ConsumerStatefulWidget {
  final ChatGroup group;

  const CreateLeadInGroupScreen({super.key, required this.group});

  @override
  ConsumerState<CreateLeadInGroupScreen> createState() =>
      _CreateLeadInGroupScreenState();
}

class _CreateLeadInGroupScreenState
    extends ConsumerState<CreateLeadInGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _electricityController = TextEditingController();
  final _powerCutController = TextEditingController();
  final _additionalInfoController = TextEditingController();
  final _incentiveController = TextEditingController();
  final _pitchedAmountController = TextEditingController();

  bool _isLoading = false;
  String _selectedStatus = 'unassigned';
  bool _accountStatus = false;
  bool _surveyStatus = false;
  String _norm(String? s) => (s ?? '').trim().toLowerCase();

  bool _isSalesUser(Map<String, String?> u) {
    // common places you might store role info
    final role = _norm(u['role']);
    final team = _norm(u['team']);
    final dept = _norm(u['department']);
    final title = _norm(u['title']);

    // booleans sometimes used
    final isSalesFlag = _norm(u['isSales']) == 'true';

    // any of these signals "sales"
    return isSalesFlag ||
        role == 'sales' ||
        team == 'sales' ||
        dept == 'sales' ||
        title.contains('sales'); // e.g., "sales officer"
  }

  String? _selectedLocation;
  late final List<String> _allowedLocations;
  Map<String, String?>? _selectedSO;
  List<Map<String, String?>> _availableUsers = [];
  bool _loadingUsers = false;

  final List<String> _statusOptions = [
    'unassigned',
    'assigned',
    'pending',
    'submitted',
    'completed',
    'rejected',
  ];

  @override
  void initState() {
    super.initState();
    _loadGroupMembers();
    _allowedLocations = _deriveAllowedLocations();
    _loadGroupMembers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _electricityController.dispose();
    _powerCutController.dispose();
    _additionalInfoController.dispose();
    _incentiveController.dispose();
    _pitchedAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupMembers() async {
    setState(() => _loadingUsers = true);
    try {
      final chatService = ref.read(chatServiceProvider);
      final users = await chatService.getAllUsers();

      // Filter to show only group members
      final groupMemberIds = widget.group.members.map((m) => m.uid).toSet();
      final filteredUsers =
          users.where((u) => groupMemberIds.contains(u['uid'])).toList();

      setState(() {
        _availableUsers = filteredUsers;
        _loadingUsers = false;
      });
    } catch (e) {
      setState(() => _loadingUsers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load group members: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _createLead() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(currentUserProvider).value;
      final leadService = ref.read(leadServiceProvider);
      final chatService = ref.read(chatServiceProvider);

      final leadId = DateTime.now().millisecondsSinceEpoch.toString();

      final newLead = LeadPool(
        uid: leadId,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        number: _numberController.text.trim(),
        address: _addressController.text.trim(),
        location: _selectedLocation!, // required & restricted
        state: widget.group.state,
        electricityConsumption: _electricityController.text.trim(),
        powercut: _powerCutController.text.trim(),
        additionalInfo: _additionalInfoController.text.trim(),
        status: _selectedSO != null ? 'assigned' : _selectedStatus,
        accountStatus: _accountStatus,
        surveyStatus: _surveyStatus,
        createdBy: currentUser?.email ?? '',
        createdTime: DateTime.now(),
        date: DateTime.now(),
        incentive: int.tryParse(_incentiveController.text.trim()) ?? 0,
        pitchedAmount: int.tryParse(_pitchedAmountController.text.trim()) ?? 0,
        offer: null,
        assignedTo: _selectedSO?['uid'],
        assignedToName: _selectedSO?['name'],
        assignedAt: _selectedSO != null ? DateTime.now() : null,
        groupId: widget.group.id,
      );

      await leadService.addLead(newLead);

      if (_selectedSO != null) {
        await leadService.startRegistrationSla(leadId);
      }

      // Send lead message to group
      await chatService.sendLeadMessage(
        groupId: widget.group.id,
        senderId: currentUser?.uid ?? '',
        senderName: currentUser?.name ?? '',
        senderEmail: currentUser?.email ?? '',
        leadId: leadId,
        leadName: newLead.name,
        message: _selectedSO != null
            ? '🆕 New lead created & assigned to ${_selectedSO!['name']}'
            : '🆕 New lead created in group',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedSO != null
                        ? 'Lead created and assigned to ${_selectedSO!['name']}!'
                        : 'Lead created and shared in group!',
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<String> _deriveAllowedLocations() {
    final List<String> locs = [];

    // Prefer explicit group.districts if present
    final districts = (widget.group.districts ?? []) as List<dynamic>;
    if (districts.isNotEmpty) {
      locs.addAll(districts.map((e) => (e ?? '').toString()));
    }

    // Or a plural workLocations list if your model has it
    final workLocations = (widget.group.districts ?? []) as List<dynamic>;
    if (locs.isEmpty && workLocations.isNotEmpty) {
      locs.addAll(workLocations.map((e) => (e ?? '').toString()));
    }

    // Or a single workLocation fallback
    final wl = (widget.group.workLocation ?? '').toString().trim();
    if (locs.isEmpty && wl.isNotEmpty) {
      locs.add(wl);
    }

    // De-dup + sort
    final set = <String>{};
    for (final l in locs) {
      final v = l.trim();
      if (v.isNotEmpty) set.add(v);
    }
    final out = set.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return out;
  }

  String _safeInitial(Map<String, String?> user) {
    final name = (user['name'] ?? '').trim();
    if (name.isNotEmpty) return name[0].toUpperCase();

    final email = (user['email'] ?? '').trim();
    if (email.isNotEmpty) return email[0].toUpperCase();

    return 'U';
  }

  String _safeDisplayName(Map<String, String?> user) {
    final name = (user['name'] ?? '').trim();
    if (name.isNotEmpty) return name;
    final email = (user['email'] ?? '').trim();
    if (email.isNotEmpty) return email;
    return 'User';
  }

  void _showAssignSODialog() {
    final currentUser = ref.read(currentUserProvider).value;
    final isAdmin =
        currentUser?.isAdmin == true || currentUser?.isSuperAdmin == true;

    if (!isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins can assign leads'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    // NEW: pre-filter to sales members only
    final salesMembers = _availableUsers.where(_isSalesUser).toList();

    if (salesMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Sales members available in this group'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add, color: AppTheme.primaryBlue),
            SizedBox(width: 12),
            Text('Assign Sales Officer'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select a Sales Officer (Sales role only):',
                style: TextStyle(color: AppTheme.mediumGrey, fontSize: 14),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: salesMembers.length, // NEW: filtered list
                  itemBuilder: (context, index) {
                    final user = salesMembers[index]; // NEW
                    final uid = (user['uid'] ?? '').trim();
                    final isSelected = _selectedSO?['uid'] == uid;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppTheme.primaryBlue.withOpacity(0.2)
                            : AppTheme.mediumGrey.withOpacity(0.1),
                        child: Text(
                          _safeInitial(user),
                          style: TextStyle(
                            color: isSelected
                                ? AppTheme.primaryBlue
                                : AppTheme.mediumGrey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(_safeDisplayName(user)),
                      subtitle: Text((user['email'] ?? '').trim()),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: AppTheme.primaryBlue)
                          : null,
                      onTap: () {
                        setState(() => _selectedSO = user);
                        Navigator.pop(dialogCtx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (_selectedSO != null)
            TextButton(
              onPressed: () {
                setState(() => _selectedSO = null);
                Navigator.pop(dialogCtx);
              },
              child: const Text('Clear Selection',
                  style: TextStyle(color: AppTheme.errorRed)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.read(currentUserProvider).value;
    final isAdmin =
        currentUser?.isAdmin == true || currentUser?.isSuperAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Lead in Group'),
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Required Fields Section
            _buildSectionHeader('Lead Details', true),
            const SizedBox(height: 16),

            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name *',
                hintText: 'Enter customer name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter name';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            if (_allowedLocations.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppTheme.warningAmber.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.warningAmber),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No work locations configured for this group. Ask an admin to add districts/locations before creating leads.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: _selectedLocation,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Select Location *',
                  prefixIcon: const Icon(Icons.place_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: _allowedLocations
                    .map((loc) => DropdownMenuItem(
                          value: loc,
                          child: Text(
                            loc,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedLocation = v),
                validator: (v) {
                  if (_allowedLocations.isEmpty)
                    return 'No allowed locations for this group';
                  if (v == null || v.trim().isEmpty)
                    return 'Please select a location';
                  return null;
                },
              ),
            const SizedBox(height: 8),

            // Number Field
            TextFormField(
              controller: _numberController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'Phone Number *',
                hintText: 'Enter 10-digit number',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                counterText: '',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter phone number';
                }
                if (value.length != 10) {
                  return 'Phone number must be 10 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Assignment Section (Only for Admins)
            if (isAdmin) ...[
              _buildSectionHeader('Assignment (Optional)'),
              const SizedBox(height: 12),
              if (_loadingUsers)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                GestureDetector(
                  onTap: _showAssignSODialog,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _selectedSO != null
                            ? AppTheme.primaryBlue
                            : AppTheme.mediumGrey.withOpacity(0.3),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: _selectedSO != null
                          ? AppTheme.primaryBlue.withOpacity(0.05)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (_selectedSO != null
                                    ? AppTheme.primaryBlue
                                    : AppTheme.mediumGrey)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _selectedSO != null
                                ? Icons.person
                                : Icons.person_add_outlined,
                            color: _selectedSO != null
                                ? AppTheme.primaryBlue
                                : AppTheme.mediumGrey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedSO != null
                                    ? 'Assigned to'
                                    : 'Assign Sales Officer',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.mediumGrey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _selectedSO != null
                                    ? _safeDisplayName(_selectedSO!)
                                    : 'Tap to select (optional)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: _selectedSO != null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: _selectedSO != null
                                      ? AppTheme.primaryBlue
                                      : AppTheme.mediumGrey,
                                ),
                              ),
                              if (_selectedSO != null)
                                Text(
                                  _selectedSO!['email'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.mediumGrey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppTheme.mediumGrey,
                        ),
                      ],
                    ),
                  ),
                ),
              if (_selectedSO != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.successGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppTheme.successGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Registration SLA (3 days) will start automatically when assigned',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.darkGrey.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],

            // Contact Information Section
            _buildSectionHeader('Contact Information (Optional)'),
            const SizedBox(height: 12),

            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter email address',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Address Field
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Address',
                hintText: 'Enter full address',
                prefixIcon: const Icon(Icons.home_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Energy Details Section
            _buildSectionHeader('Energy Details (Optional)'),
            const SizedBox(height: 12),

            // Electricity Consumption Field
            TextFormField(
              controller: _electricityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Electricity Consumption (kWh)',
                hintText: 'Monthly consumption',
                prefixIcon: const Icon(Icons.bolt_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Power Cut Hours Field
            TextFormField(
              controller: _powerCutController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Power Cut (hours/day)',
                hintText: 'Average power cut duration',
                prefixIcon: const Icon(Icons.power_off_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Business Details Section
            _buildSectionHeader('Pricing Details'),
            const SizedBox(height: 12),

            // Pitched Amount Field
            TextFormField(
              controller: _pitchedAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Pitched Amount (₹)',
                hintText: 'Enter pitched amount',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status Dropdown (Only show if not assigning)
            if (_selectedSO != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.successGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.successGreen.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.successGreen,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Status will be set to: ',
                      style: TextStyle(fontSize: 14),
                    ),
                    Text(
                      'ASSIGNED',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.successGreen,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Additional Information Section
            _buildSectionHeader('Additional Information'),
            const SizedBox(height: 12),

            // Additional Info Field
            TextFormField(
              controller: _additionalInfoController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Notes',
                hintText: 'Any other details or special notes',
                prefixIcon: const Icon(Icons.notes_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Info Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.warningAmber.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.warningAmber,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedSO != null
                          ? 'Lead will be created, assigned to ${_safeDisplayName(_selectedSO!)}, and shared in the group. Registration SLA will start immediately.'
                          : 'Lead will be shared in the group with status: ${_getStatusLabel(_selectedStatus)}. Admins can assign it to a Sales Officer later.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.darkGrey.withOpacity(0.8),
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
                onPressed: _isLoading ? null : _createLead,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle_outline,
                              color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _selectedSO != null
                                ? 'Create & Assign Lead'
                                : 'Create & Share Lead',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, [bool isRequired = false]) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: AppTheme.errorRed,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'unassigned':
        return 'Unassigned';
      case 'assigned':
        return 'Assigned';
      case 'pending':
        return 'Pending';
      case 'submitted':
        return 'Submitted';
      case 'completed':
        return 'Completed';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }
}
